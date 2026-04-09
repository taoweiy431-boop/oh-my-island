import Foundation
import os

// MARK: - ACP Client (Agent Client Protocol over stdio JSON-RPC)

@MainActor
class ACPClient: ObservableObject {
    private let logger = Logger(subsystem: "com.codeisland", category: "ACP")

    @Published var isConnected: Bool = false
    @Published var sessionId: String?

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var requestId: Int = 0
    private var pendingRequests: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private var updateHandler: ((ACPUpdate) -> Void)?
    private var readBuffer = Data()

    // MARK: - Public API

    func connect(workingDirectory: String, onUpdate: @escaping (ACPUpdate) -> Void) async throws {
        updateHandler = onUpdate

        let proc = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        // Try npx first, then global command
        let npxPath = findExecutable("npx")
        let acpPath = findExecutable("claude-code-acp")

        if let acpPath {
            proc.executableURL = URL(fileURLWithPath: acpPath)
            proc.arguments = []
        } else if let npxPath {
            proc.executableURL = URL(fileURLWithPath: npxPath)
            proc.arguments = ["@zed-industries/claude-code-acp"]
        } else {
            throw ACPError.adapterNotFound
        }

        proc.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        // Pass through environment + load Claude Code settings env vars
        var env = ProcessInfo.processInfo.environment
        env["NODE_NO_WARNINGS"] = "1"

        // Load env from Claude Code settings.json (for ccswitch proxy etc.)
        let settingsPath = "\(NSHomeDirectory())/.claude/settings.json"
        if let settingsData = FileManager.default.contents(atPath: settingsPath),
           let settings = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any],
           let settingsEnv = settings["env"] as? [String: String] {
            for (key, value) in settingsEnv {
                if env[key] == nil {
                    env[key] = value
                }
            }
            logger.info("Loaded \(settingsEnv.count) env vars from Claude settings")
        }
        proc.environment = env

        process = proc
        stdinPipe = stdin
        stdoutPipe = stdout

        proc.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.isConnected = false
                self?.sessionId = nil
                self?.logger.warning("ACP process terminated with exit code \(proc.terminationStatus)")
            }
        }

        // Log stderr for debugging
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.logger.warning("ACP stderr: \(text)")
            }
        }

        try proc.run()
        logger.info("ACP adapter started (PID: \(proc.processIdentifier))")

        // Brief delay to let process start
        try await Task.sleep(for: .milliseconds(500))

        guard proc.isRunning else {
            throw ACPError.rpcError("ACP adapter exited immediately. Check ANTHROPIC_API_KEY environment variable.")
        }

        startReadingOutput()

        // Initialize the connection
        let capabilities: [String: Any] = [:]
        let initResult = try await sendRequest("initialize", params: [
            "protocolVersion": 1,
            "clientCapabilities": capabilities,
            "clientInfo": [
                "name": "codeisland",
                "title": "Oh My Island",
                "version": "1.0.0"
            ] as [String: Any]
        ])

        logger.info("ACP initialized: \(String(describing: initResult["agentInfo"]))")
        isConnected = true
    }

    func createSession(workingDirectory: String) async throws -> String {
        let emptyServers: [[String: Any]] = []
        let result = try await sendRequest("session/new", params: [
            "cwd": workingDirectory,
            "mcpServers": emptyServers
        ] as [String: Any])

        guard let sid = result["sessionId"] as? String else {
            throw ACPError.invalidResponse("Missing sessionId")
        }

        sessionId = sid
        logger.info("ACP session created: \(sid)")
        return sid
    }

    func sendPrompt(_ text: String) async throws {
        guard let sid = sessionId else { throw ACPError.noSession }

        _ = try await sendRequest("session/prompt", params: [
            "sessionId": sid,
            "prompt": [
                ["type": "text", "text": text]
            ]
        ])
    }

    func cancelPrompt() async throws {
        guard let sid = sessionId else { return }
        sendNotification("session/cancel", params: ["sessionId": sid])
    }

    func disconnect() {
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        isConnected = false
        sessionId = nil
        pendingRequests.removeAll()
    }

    // MARK: - JSON-RPC Communication

    private func sendRequest(_ method: String, params: [String: Any]) async throws -> [String: Any] {
        requestId += 1
        let id = requestId

        let message: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params
        ]

        try writeMessage(message)
        logger.info("ACP request sent: \(method) (id=\(id))")

        return try await withThrowingTaskGroup(of: [String: Any].self) { group in
            group.addTask { @MainActor [self] in
                try await withCheckedThrowingContinuation { continuation in
                    pendingRequests[id] = continuation
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw ACPError.rpcError("Request timed out: \(method)")
            }

            guard let result = try await group.next() else {
                throw ACPError.rpcError("No result")
            }
            group.cancelAll()
            return result
        }
    }

    private func sendNotification(_ method: String, params: [String: Any]) {
        let message: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "params": params
        ]
        try? writeMessage(message)
    }

    private func writeMessage(_ message: [String: Any]) throws {
        guard let pipe = stdinPipe else { throw ACPError.notConnected }

        let data = try JSONSerialization.data(withJSONObject: message)
        guard var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        guard let lineData = line.data(using: .utf8) else { return }
        pipe.fileHandleForWriting.write(lineData)
    }

    // MARK: - Reading Output

    private func startReadingOutput() {
        guard let stdout = stdoutPipe else { return }

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            Task { @MainActor [weak self] in
                self?.processIncomingData(data)
            }
        }
    }

    private func processIncomingData(_ data: Data) {
        readBuffer.append(data)

        // Newline-delimited JSON (ACP stdio transport)
        while let newlineIndex = readBuffer.firstIndex(of: 0x0A) { // \n
            let lineData = readBuffer[readBuffer.startIndex..<newlineIndex]
            readBuffer = Data(readBuffer[(newlineIndex + 1)...])

            guard !lineData.isEmpty else { continue }

            if let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] {
                handleMessage(json)
            }
        }
    }

    // MARK: - Message Handling

    private func handleMessage(_ json: [String: Any]) {
        if let id = json["id"] as? Int {
            // Response to a request
            if let result = json["result"] as? [String: Any] {
                pendingRequests[id]?.resume(returning: result)
                pendingRequests.removeValue(forKey: id)
            } else if let error = json["error"] as? [String: Any] {
                let message = error["message"] as? String ?? "Unknown error"
                pendingRequests[id]?.resume(throwing: ACPError.rpcError(message))
                pendingRequests.removeValue(forKey: id)
            }
        } else if let method = json["method"] as? String {
            // Notification from agent
            handleNotification(method: method, params: json["params"] as? [String: Any] ?? [:])
        }
    }

    private func handleNotification(method: String, params: [String: Any]) {
        guard method == "session/update",
              let update = params["update"] as? [String: Any],
              let updateType = update["sessionUpdate"] as? String else {
            // Handle bidirectional requests (e.g., session/request_permission)
            if method == "session/request_permission" {
                handlePermissionRequest(params)
            }
            return
        }

        let sessionUpdate: ACPUpdate

        switch updateType {
        case "agent_message_chunk":
            if let content = update["content"] as? [String: Any],
               let text = content["text"] as? String {
                sessionUpdate = .messageChunk(text)
            } else {
                return
            }

        case "tool_call":
            let toolCallId = update["toolCallId"] as? String ?? UUID().uuidString
            let title = update["title"] as? String ?? "Tool"
            let kind = update["kind"] as? String ?? "other"
            let status = update["status"] as? String ?? "pending"
            sessionUpdate = .toolCall(id: toolCallId, title: title, kind: kind, status: status)

        case "tool_call_update":
            let toolCallId = update["toolCallId"] as? String ?? ""
            let status = update["status"] as? String ?? "in_progress"
            var contentText: String?
            if let contentArray = update["content"] as? [[String: Any]] {
                for block in contentArray {
                    if let inner = block["content"] as? [String: Any],
                       let text = inner["text"] as? String {
                        contentText = text
                        break
                    }
                }
            }
            sessionUpdate = .toolCallUpdate(id: toolCallId, status: status, content: contentText)

        case "plan":
            if let entries = update["entries"] as? [[String: Any]] {
                let items = entries.compactMap { entry -> ACPPlanEntry? in
                    guard let content = entry["content"] as? String else { return nil }
                    let status = entry["status"] as? String ?? "pending"
                    return ACPPlanEntry(content: content, status: status)
                }
                sessionUpdate = .plan(items)
            } else {
                return
            }

        default:
            logger.info("Unknown ACP update type: \(updateType)")
            return
        }

        updateHandler?(sessionUpdate)
    }

    private func handlePermissionRequest(_ params: [String: Any]) {
        // Auto-approve for now (user can implement UI approval later)
        if let id = params["id"] as? Int ?? params["_id"] as? Int {
            let response: [String: Any] = [
                "jsonrpc": "2.0",
                "id": id,
                "result": ["outcome": "approved"]
            ]
            try? writeMessage(response)
        }
    }

    // MARK: - Utilities

    private nonisolated func findExecutable(_ name: String) -> String? {
        let home = NSHomeDirectory()

        // Enumerate common Node.js version directories
        var nodePaths: [String] = []
        let nvmBase = "\(home)/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmBase) {
            for v in versions.sorted().reversed() {
                nodePaths.append("\(nvmBase)/\(v)/bin/\(name)")
            }
        }

        let paths = [
            "/usr/local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "\(home)/.volta/bin/\(name)",
            "\(home)/.bun/bin/\(name)",
            "\(home)/.local/bin/\(name)",
        ] + nodePaths

        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallback: /usr/bin/which
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = [name]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }
}

// MARK: - ACP Data Types

enum ACPUpdate {
    case messageChunk(String)
    case toolCall(id: String, title: String, kind: String, status: String)
    case toolCallUpdate(id: String, status: String, content: String?)
    case plan([ACPPlanEntry])
}

struct ACPPlanEntry {
    let content: String
    let status: String
}

enum ACPError: Error, LocalizedError {
    case adapterNotFound
    case notConnected
    case noSession
    case invalidResponse(String)
    case rpcError(String)

    var errorDescription: String? {
        switch self {
        case .adapterNotFound: return "claude-code-acp adapter not found. Install with: npm install -g @zed-industries/claude-code-acp"
        case .notConnected: return "ACP client not connected"
        case .noSession: return "No active ACP session"
        case .invalidResponse(let msg): return "Invalid response: \(msg)"
        case .rpcError(let msg): return "RPC error: \(msg)"
        }
    }
}
