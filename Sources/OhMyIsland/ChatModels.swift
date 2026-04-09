import Foundation

// MARK: - Chat History Item

struct ChatHistoryItem: Identifiable, Equatable, Sendable {
    let id: String
    let type: ChatHistoryItemType
    let timestamp: Date

    static func == (lhs: ChatHistoryItem, rhs: ChatHistoryItem) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type
    }
}

enum ChatHistoryItemType: Equatable, Sendable {
    case user(String)
    case assistant(String)
    case toolCall(ToolCallItem)
    case thinking(String)
    case interrupted
}

// MARK: - Tool Call Item

struct ToolCallItem: Equatable, Sendable {
    let name: String
    let input: [String: String]
    var status: ToolStatus
    var result: String?
    var structuredResult: ToolResultData?
    var subagentTools: [SubagentToolCall]

    var inputPreview: String {
        if let filePath = input["file_path"] ?? input["path"] {
            return URL(fileURLWithPath: filePath).lastPathComponent
        }
        if let command = input["command"] {
            let firstLine = command.components(separatedBy: "\n").first ?? command
            return String(firstLine.prefix(60))
        }
        if let pattern = input["pattern"] { return pattern }
        if let query = input["query"] { return query }
        if let url = input["url"] { return url }
        if let agentId = input["agentId"] {
            let blocking = input["block"] == "true"
            return blocking ? "Waiting..." : "Checking \(agentId.prefix(8))..."
        }
        return input.values.first.map { String($0.prefix(60)) } ?? ""
    }

    var statusDisplay: ToolStatusDisplay {
        if status == .running {
            return ToolStatusDisplay.running(for: name, input: input)
        }
        if status == .waitingForApproval {
            return ToolStatusDisplay(text: "Waiting for approval...", isRunning: true)
        }
        if status == .interrupted {
            return ToolStatusDisplay(text: "Interrupted", isRunning: false)
        }
        return ToolStatusDisplay.completed(for: name, result: structuredResult)
    }

    static func == (lhs: ToolCallItem, rhs: ToolCallItem) -> Bool {
        lhs.name == rhs.name &&
        lhs.input == rhs.input &&
        lhs.status == rhs.status &&
        lhs.result == rhs.result &&
        lhs.structuredResult == rhs.structuredResult &&
        lhs.subagentTools == rhs.subagentTools
    }
}

// MARK: - Tool Status

enum ToolStatus: Sendable, CustomStringConvertible {
    case running
    case waitingForApproval
    case success
    case error
    case interrupted

    nonisolated var description: String {
        switch self {
        case .running: return "running"
        case .waitingForApproval: return "waitingForApproval"
        case .success: return "success"
        case .error: return "error"
        case .interrupted: return "interrupted"
        }
    }
}

extension ToolStatus: Equatable {
    nonisolated static func == (lhs: ToolStatus, rhs: ToolStatus) -> Bool {
        switch (lhs, rhs) {
        case (.running, .running),
             (.waitingForApproval, .waitingForApproval),
             (.success, .success),
             (.error, .error),
             (.interrupted, .interrupted):
            return true
        default:
            return false
        }
    }
}

// MARK: - Subagent Tool Call

struct SubagentToolCall: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let input: [String: String]
    var status: ToolStatus
    let timestamp: Date
}

// MARK: - Tool Result Data

enum ToolResultData: Equatable, Sendable {
    case read(ReadResult)
    case edit(EditResult)
    case write(WriteResult)
    case bash(BashResult)
    case grep(GrepResult)
    case glob(GlobResult)
    case todoWrite(TodoWriteResult)
    case task(TaskResult)
    case webFetch(WebFetchResult)
    case webSearch(WebSearchResult)
    case askUserQuestion(AskUserQuestionResult)
    case bashOutput(BashOutputResult)
    case killShell(KillShellResult)
    case exitPlanMode(ExitPlanModeResult)
    case mcp(MCPResult)
    case generic(GenericResult)
}

struct ReadResult: Equatable, Sendable {
    let filePath: String
    let content: String
    let numLines: Int
    let startLine: Int
    let totalLines: Int
    var filename: String { URL(fileURLWithPath: filePath).lastPathComponent }
}

struct EditResult: Equatable, Sendable {
    let filePath: String
    let oldString: String
    let newString: String
    let replaceAll: Bool
    let userModified: Bool
    let structuredPatch: [PatchHunk]?
    var filename: String { URL(fileURLWithPath: filePath).lastPathComponent }
}

struct PatchHunk: Equatable, Sendable {
    let oldStart: Int
    let oldLines: Int
    let newStart: Int
    let newLines: Int
    let lines: [String]
}

struct WriteResult: Equatable, Sendable {
    enum WriteType: String, Equatable, Sendable { case create, overwrite }
    let type: WriteType
    let filePath: String
    let content: String
    let structuredPatch: [PatchHunk]?
    var filename: String { URL(fileURLWithPath: filePath).lastPathComponent }
}

struct BashResult: Equatable, Sendable {
    let stdout: String
    let stderr: String
    let interrupted: Bool
    let isImage: Bool
    let returnCodeInterpretation: String?
    let backgroundTaskId: String?
    var hasOutput: Bool { !stdout.isEmpty || !stderr.isEmpty }
}

struct GrepResult: Equatable, Sendable {
    enum Mode: String, Equatable, Sendable {
        case filesWithMatches = "files_with_matches"
        case content
        case count
    }
    let mode: Mode
    let filenames: [String]
    let numFiles: Int
    let content: String?
    let numLines: Int?
    let appliedLimit: Int?
}

struct GlobResult: Equatable, Sendable {
    let filenames: [String]
    let durationMs: Int
    let numFiles: Int
    let truncated: Bool
}

struct TodoWriteResult: Equatable, Sendable {
    let oldTodos: [TodoItem]
    let newTodos: [TodoItem]
}

struct TodoItem: Equatable, Sendable {
    let content: String
    let status: String
    let activeForm: String?
}

struct TaskResult: Equatable, Sendable {
    let agentId: String
    let status: String
    let content: String
    let prompt: String?
    let totalDurationMs: Int?
    let totalTokens: Int?
    let totalToolUseCount: Int?
}

struct WebFetchResult: Equatable, Sendable {
    let url: String
    let code: Int
    let codeText: String
    let bytes: Int
    let durationMs: Int
    let result: String
}

struct WebSearchResult: Equatable, Sendable {
    let query: String
    let durationSeconds: Double
    let results: [SearchResultItem]
}

struct SearchResultItem: Equatable, Sendable {
    let title: String
    let url: String
    let snippet: String
}

struct AskUserQuestionResult: Equatable, Sendable {
    let questions: [QuestionResultItem]
    let answers: [String: String]
}

struct QuestionResultItem: Equatable, Sendable {
    let question: String
    let header: String?
    let options: [QuestionOption]
}

struct QuestionOption: Equatable, Sendable {
    let label: String
    let description: String?
}

struct BashOutputResult: Equatable, Sendable {
    let shellId: String
    let status: String
    let stdout: String
    let stderr: String
    let stdoutLines: Int
    let stderrLines: Int
    let exitCode: Int?
    let command: String?
    let timestamp: String?
}

struct KillShellResult: Equatable, Sendable {
    let shellId: String
    let message: String
}

struct ExitPlanModeResult: Equatable, Sendable {
    let filePath: String?
    let plan: String?
    let isAgent: Bool
}

struct MCPResult: Equatable, @unchecked Sendable {
    let serverName: String
    let toolName: String
    let rawResult: [String: Any]

    static func == (lhs: MCPResult, rhs: MCPResult) -> Bool {
        lhs.serverName == rhs.serverName &&
        lhs.toolName == rhs.toolName &&
        NSDictionary(dictionary: lhs.rawResult).isEqual(to: rhs.rawResult)
    }
}

struct GenericResult: Equatable, @unchecked Sendable {
    let rawContent: String?
    let rawData: [String: Any]?

    static func == (lhs: GenericResult, rhs: GenericResult) -> Bool {
        lhs.rawContent == rhs.rawContent
    }
}

// MARK: - Tool Status Display

struct ToolStatusDisplay {
    let text: String
    let isRunning: Bool

    static func running(for toolName: String, input: [String: String]) -> ToolStatusDisplay {
        switch toolName {
        case "Read": return ToolStatusDisplay(text: "Reading...", isRunning: true)
        case "Edit": return ToolStatusDisplay(text: "Editing...", isRunning: true)
        case "Write": return ToolStatusDisplay(text: "Writing...", isRunning: true)
        case "Bash":
            if let desc = input["description"], !desc.isEmpty {
                return ToolStatusDisplay(text: desc, isRunning: true)
            }
            return ToolStatusDisplay(text: "Running...", isRunning: true)
        case "Grep", "Glob":
            if let pattern = input["pattern"] {
                return ToolStatusDisplay(text: "Searching: \(pattern)", isRunning: true)
            }
            return ToolStatusDisplay(text: "Searching...", isRunning: true)
        case "WebSearch":
            if let query = input["query"] {
                return ToolStatusDisplay(text: "Searching: \(query)", isRunning: true)
            }
            return ToolStatusDisplay(text: "Searching...", isRunning: true)
        case "WebFetch": return ToolStatusDisplay(text: "Fetching...", isRunning: true)
        case "Task":
            if let desc = input["description"], !desc.isEmpty {
                return ToolStatusDisplay(text: desc, isRunning: true)
            }
            return ToolStatusDisplay(text: "Running agent...", isRunning: true)
        case "TodoWrite": return ToolStatusDisplay(text: "Updating todos...", isRunning: true)
        default: return ToolStatusDisplay(text: "Running...", isRunning: true)
        }
    }

    static func completed(for toolName: String, result: ToolResultData?) -> ToolStatusDisplay {
        guard let result else { return ToolStatusDisplay(text: "Completed", isRunning: false) }
        switch result {
        case .read(let r):
            let lineText = r.totalLines > r.numLines ? "\(r.numLines)+ lines" : "\(r.numLines) lines"
            return ToolStatusDisplay(text: "Read \(r.filename) (\(lineText))", isRunning: false)
        case .edit(let r): return ToolStatusDisplay(text: "Edited \(r.filename)", isRunning: false)
        case .write(let r):
            return ToolStatusDisplay(text: "\(r.type == .create ? "Created" : "Wrote") \(r.filename)", isRunning: false)
        case .bash(let r):
            if let bgId = r.backgroundTaskId { return ToolStatusDisplay(text: "Running in background (\(bgId))", isRunning: false) }
            if let interp = r.returnCodeInterpretation { return ToolStatusDisplay(text: interp, isRunning: false) }
            return ToolStatusDisplay(text: "Completed", isRunning: false)
        case .grep(let r):
            return ToolStatusDisplay(text: "Found \(r.numFiles) \(r.numFiles == 1 ? "file" : "files")", isRunning: false)
        case .glob(let r):
            if r.numFiles == 0 { return ToolStatusDisplay(text: "No files found", isRunning: false) }
            return ToolStatusDisplay(text: "Found \(r.numFiles) \(r.numFiles == 1 ? "file" : "files")", isRunning: false)
        case .todoWrite: return ToolStatusDisplay(text: "Updated todos", isRunning: false)
        case .task(let r): return ToolStatusDisplay(text: r.status.capitalized, isRunning: false)
        case .webFetch(let r): return ToolStatusDisplay(text: "\(r.code) \(r.codeText)", isRunning: false)
        case .webSearch: return ToolStatusDisplay(text: "Completed", isRunning: false)
        case .askUserQuestion: return ToolStatusDisplay(text: "Answered", isRunning: false)
        case .bashOutput(let r): return ToolStatusDisplay(text: "Status: \(r.status)", isRunning: false)
        case .killShell: return ToolStatusDisplay(text: "Terminated", isRunning: false)
        case .exitPlanMode: return ToolStatusDisplay(text: "Plan ready", isRunning: false)
        case .mcp, .generic: return ToolStatusDisplay(text: "Completed", isRunning: false)
        }
    }
}

// MARK: - MCP Tool Formatter

struct MCPToolFormatter {
    private static let toolAliases: [String: String] = [
        "AgentOutputTool": "Await Agent",
        "AskUserQuestion": "Question",
        "TodoWrite": "Todo",
        "TodoRead": "Todo",
        "WebFetch": "Fetch",
        "WebSearch": "Search",
        "NotebookEdit": "Notebook",
        "BashOutput": "Bash",
        "KillShell": "Shell",
        "EnterPlanMode": "Plan",
        "ExitPlanMode": "Plan",
        "SlashCommand": "Command",
    ]

    static func isMCPTool(_ name: String) -> Bool {
        name.hasPrefix("mcp__")
    }

    static func toTitleCase(_ snakeCase: String) -> String {
        snakeCase.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    static func formatToolName(_ toolId: String) -> String {
        if let alias = toolAliases[toolId] { return alias }
        guard isMCPTool(toolId) else { return toolId }
        let withoutPrefix = String(toolId.dropFirst(5))
        let parts = withoutPrefix.split(separator: "_", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count >= 1 else { return toolId }
        let serverName = toTitleCase(String(parts[0]))
        if parts.count >= 2 {
            let toolNameRaw = String(parts[1]).hasPrefix("_") ? String(String(parts[1]).dropFirst()) : String(parts[1])
            return "\(serverName) - \(toTitleCase(toolNameRaw))"
        }
        return serverName
    }

    static func formatArgs(_ input: [String: String], maxValueLength: Int = 30, maxArgs: Int = 3) -> String {
        guard !input.isEmpty else { return "" }
        let sortedKeys = input.keys.sorted()
        var parts: [String] = []
        for key in sortedKeys.prefix(maxArgs) {
            guard let value = input[key] else { continue }
            let truncated = value.count > maxValueLength ? String(value.prefix(maxValueLength)) + "..." : value
            parts.append("\(key): \"\(truncated)\"")
        }
        var result = parts.joined(separator: ", ")
        if sortedKeys.count > maxArgs { result += ", ..." }
        return result
    }
}
