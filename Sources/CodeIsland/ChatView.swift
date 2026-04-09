import Lottie
import SwiftUI
import CodeIslandCore

// MARK: - Chat View (replaces ChatPanelView)

struct ChatView: View {
    let session: SessionSnapshot
    let sessionId: String
    var appState: AppState

    @State private var inputText: String = ""
    @State private var chatHistory: [ChatHistoryItem] = []
    @State private var isLoading: Bool = true
    @State private var isACPConnected: Bool = false
    @State private var isACPConnecting: Bool = false
    @State private var acpError: String?
    @State private var pendingAssistantText: String = ""
    @StateObject private var acpClient = ACPClient()
    @FocusState private var isInputFocused: Bool

    private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            if isLoading {
                loadingState
            } else if chatHistory.isEmpty {
                emptyState
            } else {
                messageList
            }
            if session.status == .waitingApproval {
                approvalIndicator
            } else {
                inputBar
            }
        }
        .task {
            await loadChatHistory()
        }
    }

    // MARK: - Header

    @State private var isHeaderHovered = false

    private var chatHeader: some View {
        Button {
            withAnimation(NotchAnimation.open) {
                appState.surface = .sessionList
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(isHeaderHovered ? 1.0 : 0.6))
                    .frame(width: 24, height: 24)
                Text(session.sessionTitle ?? session.projectDisplayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(isHeaderHovered ? 1.0 : 0.85))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 8).fill(isHeaderHovered ? Color.white.opacity(0.08) : Color.clear))
        }
        .buttonStyle(.plain)
        .onHover { isHeaderHovered = $0 }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.2))
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [Color.black.opacity(0.5), Color.black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 24).offset(y: 24).allowsHitTesting(false)
        }
        .zIndex(1)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 8) {
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.4))).scaleEffect(0.8)
            Text("Loading messages...").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkle").font(.system(size: 28, weight: .light))
                .frame(width: 32, height: 32).foregroundColor(claudeOrange.opacity(0.5))
            Text("Claude").font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(claudeOrange.opacity(0.5)).tracking(2)
            Text("Ready to assist").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    Color.clear.frame(height: 1).id("bottom")

                    if session.status == .processing || session.status == .running {
                        ProcessingIndicatorView()
                            .padding(.horizontal, 16)
                            .scaleEffect(x: 1, y: -1)
                    }

                    ForEach(chatHistory.reversed()) { item in
                        MessageItemView(item: item, sessionId: sessionId)
                            .padding(.horizontal, 16)
                            .scaleEffect(x: 1, y: -1)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
                    }
                }
                .padding(.top, 20).padding(.bottom, 20)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: chatHistory.count)
            }
            .scaleEffect(x: 1, y: -1)
            .onChange(of: chatHistory.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    // MARK: - Input Bar

    private var hasTerminalSession: Bool {
        session.ttyPath != nil || session.tmuxPane != nil || session.termApp != nil || session.cliPid != nil
    }

    private var canSend: Bool {
        (isACPConnected || hasTerminalSession) && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            if let error = acpError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 10))
                    Text(error).font(.system(size: 10)).lineLimit(1)
                    Spacer()
                    Button("Retry") { Task { await connectACP() } }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(claudeOrange)
                }
                .foregroundColor(.red.opacity(0.7))
                .padding(.horizontal, 16).padding(.vertical, 6)
            }

            HStack(spacing: 10) {
                if !isACPConnected && !isACPConnecting {
                    Button {
                        Task { await connectACP() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill").font(.system(size: 10))
                            Text("Connect ACP").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(claudeOrange)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 16).fill(claudeOrange.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                } else if isACPConnecting {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6)
                        Text("Connecting...").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                    }
                }

                let canType = isACPConnected || hasTerminalSession
                TextField(canType ? "Message Claude..." : "No active session", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(canType ? .white : .white.opacity(0.35))
                    .focused($isInputFocused)
                    .disabled(!canType)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(isACPConnected ? 0.06 : 0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(
                                        isACPConnected
                                            ? claudeOrange.opacity(isInputFocused ? 0.4 : 0.15)
                                            : Color.white.opacity(0.06),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .onSubmit { sendMessage() }

                Button { sendMessage() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(canSend ? claudeOrange.opacity(0.9) : claudeOrange.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .background(Color.black.opacity(0.2))
        .overlay(alignment: .top) {
            LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .frame(height: 24).offset(y: -24).allowsHitTesting(false)
        }
        .zIndex(1)
    }

    // MARK: - ACP Actions

    private func connectACP() async {
        guard let cwd = session.cwd else { return }
        isACPConnecting = true
        acpError = nil

        do {
            try await acpClient.connect(workingDirectory: cwd) { [self] update in
                handleACPUpdate(update)
            }
            _ = try await acpClient.createSession(workingDirectory: cwd)
            isACPConnected = true
            isACPConnecting = false
            isInputFocused = true
        } catch {
            acpError = error.localizedDescription
            isACPConnecting = false
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        chatHistory.append(ChatHistoryItem(
            id: "user-\(chatHistory.count)",
            type: .user(text),
            timestamp: Date()
        ))

        if isACPConnected {
            Task {
                do {
                    try await acpClient.sendPrompt(text)
                    flushPendingAssistantText()
                } catch {
                    chatHistory.append(ChatHistoryItem(
                        id: "error-\(chatHistory.count)",
                        type: .assistant("Error: \(error.localizedDescription)"),
                        timestamp: Date()
                    ))
                }
            }
        } else {
            Task {
                let success = await TerminalSender.shared.sendMessage(text, to: session, sessionId: sessionId)
                if !success {
                    let debugInfo = "tty:\(session.ttyPath ?? "nil") tmux:\(session.tmuxPane ?? "nil") app:\(session.termApp ?? "nil") pid:\(session.cliPid.map { "\($0)" } ?? "nil")"
                    chatHistory.append(ChatHistoryItem(
                        id: "error-\(chatHistory.count)",
                        type: .assistant("Send failed. Debug: \(debugInfo)"),
                        timestamp: Date()
                    ))
                }
            }
        }
    }

    private func handleACPUpdate(_ update: ACPUpdate) {
        switch update {
        case .messageChunk(let text):
            pendingAssistantText += text

        case .toolCall(let id, let title, _, let status):
            flushPendingAssistantText()
            let toolStatus: ToolStatus = status == "completed" ? .success : .running
            let tool = ToolCallItem(name: title, input: [:], status: toolStatus, result: nil, structuredResult: nil, subagentTools: [])
            chatHistory.append(ChatHistoryItem(id: id, type: .toolCall(tool), timestamp: Date()))

        case .toolCallUpdate(let id, let status, let content):
            if let index = chatHistory.lastIndex(where: { $0.id == id }),
               case .toolCall(var tool) = chatHistory[index].type {
                tool.status = status == "completed" ? .success : (status == "error" ? .error : .running)
                if let content { tool.result = content }
                chatHistory[index] = ChatHistoryItem(id: id, type: .toolCall(tool), timestamp: Date())
            }

        case .plan(let entries):
            let planText = entries.map { "[\($0.status)] \($0.content)" }.joined(separator: "\n")
            chatHistory.append(ChatHistoryItem(id: "plan-\(chatHistory.count)", type: .thinking(planText), timestamp: Date()))
        }
    }

    private func flushPendingAssistantText() {
        guard !pendingAssistantText.isEmpty else { return }
        chatHistory.append(ChatHistoryItem(
            id: "assistant-\(chatHistory.count)",
            type: .assistant(pendingAssistantText),
            timestamp: Date()
        ))
        pendingAssistantText = ""
    }

    // MARK: - Approval Indicator

    private var approvalIndicator: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.currentTool ?? "Tool")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(TerminalColors.amber)
                Text("Waiting for approval")
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Load Chat History

    private func loadChatHistory() async {
        guard let cwd = session.cwd else {
            isLoading = false
            buildFromSnapshot()
            return
        }

        let sessionDir = "\(cwd)/.claude/sessions"
        let jsonlPath = "\(sessionDir)/\(sessionId).jsonl"

        if FileManager.default.fileExists(atPath: jsonlPath) {
            let items = await parseJSONL(path: jsonlPath)
            chatHistory = items
        } else {
            buildFromSnapshot()
        }
        isLoading = false
    }

    private func buildFromSnapshot() {
        var items: [ChatHistoryItem] = []
        if !session.recentMessages.isEmpty {
            for (index, msg) in session.recentMessages.enumerated() {
                items.append(ChatHistoryItem(
                    id: "msg-\(index)",
                    type: msg.isUser ? .user(msg.text) : .assistant(msg.text),
                    timestamp: Date()
                ))
            }
        } else {
            if let prompt = session.lastUserPrompt {
                items.append(ChatHistoryItem(id: "last-user", type: .user(prompt), timestamp: Date()))
            }
            if let reply = session.lastAssistantMessage {
                items.append(ChatHistoryItem(id: "last-ai", type: .assistant(reply), timestamp: Date()))
            }
        }
        chatHistory = items
    }

    // MARK: - JSONL Parser

    private func parseJSONL(path: String) async -> [ChatHistoryItem] {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return [] }

        var items: [ChatHistoryItem] = []
        let lines = content.components(separatedBy: "\n")
        var messageIndex = 0

        for line in lines {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            let role = json["role"] as? String

            if role == "user" {
                if let message = json["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    items.append(ChatHistoryItem(id: "user-\(messageIndex)", type: .user(content), timestamp: Date()))
                    messageIndex += 1
                } else if let contentArray = (json["message"] as? [String: Any])?["content"] as? [[String: Any]] {
                    for block in contentArray {
                        if let type = block["type"] as? String, type == "text",
                           let text = block["text"] as? String {
                            items.append(ChatHistoryItem(id: "user-\(messageIndex)", type: .user(text), timestamp: Date()))
                            messageIndex += 1
                        }
                    }
                }
            } else if role == "assistant" {
                if let message = json["message"] as? [String: Any],
                   let contentArray = message["content"] as? [[String: Any]] {
                    for block in contentArray {
                        guard let type = block["type"] as? String else { continue }

                        if type == "text", let text = block["text"] as? String, !text.isEmpty {
                            items.append(ChatHistoryItem(id: "assistant-\(messageIndex)", type: .assistant(text), timestamp: Date()))
                            messageIndex += 1
                        } else if type == "thinking", let thinking = block["thinking"] as? String, !thinking.isEmpty {
                            items.append(ChatHistoryItem(id: "thinking-\(messageIndex)", type: .thinking(thinking), timestamp: Date()))
                            messageIndex += 1
                        } else if type == "tool_use" {
                            let toolName = block["name"] as? String ?? "Unknown"
                            let toolId = block["id"] as? String ?? "tool-\(messageIndex)"
                            var inputDict: [String: String] = [:]
                            if let input = block["input"] as? [String: Any] {
                                for (k, v) in input {
                                    inputDict[k] = "\(v)"
                                }
                            }
                            let toolItem = ToolCallItem(
                                name: toolName,
                                input: inputDict,
                                status: .success,
                                result: nil,
                                structuredResult: nil,
                                subagentTools: []
                            )
                            items.append(ChatHistoryItem(id: toolId, type: .toolCall(toolItem), timestamp: Date()))
                            messageIndex += 1
                        }
                    }
                }
            }
        }

        return items
    }
}

// MARK: - Message Item View

struct MessageItemView: View {
    let item: ChatHistoryItem
    let sessionId: String

    var body: some View {
        switch item.type {
        case .user(let text): UserMessageView(text: text)
        case .assistant(let text): AssistantMessageView(text: text)
        case .toolCall(let tool): ToolCallView(tool: tool, sessionId: sessionId)
        case .thinking(let text): ThinkingView(text: text)
        case .interrupted: InterruptedMessageView()
        }
    }
}

// MARK: - User Message

struct UserMessageView: View {
    let text: String
    var body: some View {
        HStack {
            Spacer(minLength: 60)
            MarkdownText(text, color: .white, fontSize: 13)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.15)))
        }
    }
}

// MARK: - Assistant Message

struct AssistantMessageView: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle().fill(Color.white.opacity(0.6)).frame(width: 6, height: 6).padding(.top, 5)
            MarkdownText(text, color: .white.opacity(0.9), fontSize: 13)
            Spacer(minLength: 60)
        }
    }
}

// MARK: - Processing Indicator

struct ProcessingIndicatorView: View {
    private let color = Color(red: 0.85, green: 0.47, blue: 0.34)
    @State private var dotCount: Int = 1
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            ProcessingSpinner().frame(width: 6)
            Text("Processing" + String(repeating: ".", count: dotCount))
                .font(.system(size: 13)).foregroundColor(color)
            Spacer()
        }
        .onReceive(timer) { _ in dotCount = (dotCount % 3) + 1 }
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let tool: ToolCallItem
    let sessionId: String
    @State private var pulseOpacity: Double = 0.6
    @State private var isExpanded: Bool = false
    @State private var isHovering: Bool = false

    private var statusColor: Color {
        switch tool.status {
        case .running: return .white
        case .waitingForApproval: return .orange
        case .success: return .green
        case .error, .interrupted: return .red
        }
    }

    private var textColor: Color {
        switch tool.status {
        case .running: return .white.opacity(0.6)
        case .waitingForApproval: return Color.orange.opacity(0.9)
        case .success: return .white.opacity(0.7)
        case .error, .interrupted: return Color.red.opacity(0.8)
        }
    }

    private var hasResult: Bool { tool.result != nil || tool.structuredResult != nil }
    private var canExpand: Bool { tool.name != "Task" && tool.name != "Edit" && hasResult }
    private var showContent: Bool { tool.name == "Edit" || isExpanded }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(statusColor.opacity(tool.status == .running || tool.status == .waitingForApproval ? pulseOpacity : 0.6))
                    .frame(width: 6, height: 6).id(tool.status)
                    .onAppear {
                        if tool.status == .running || tool.status == .waitingForApproval {
                            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulseOpacity = 0.15 }
                        }
                    }
                Text(MCPToolFormatter.formatToolName(tool.name))
                    .font(.system(size: 12, weight: .medium)).foregroundColor(textColor).fixedSize()

                if tool.name == "Task" && !tool.subagentTools.isEmpty {
                    let taskDesc = tool.input["description"] ?? "Running agent..."
                    Text("\(taskDesc) (\(tool.subagentTools.count) tools)")
                        .font(.system(size: 11)).foregroundColor(textColor.opacity(0.7)).lineLimit(1).truncationMode(.tail)
                } else if MCPToolFormatter.isMCPTool(tool.name) && !tool.input.isEmpty {
                    Text(MCPToolFormatter.formatArgs(tool.input))
                        .font(.system(size: 11)).foregroundColor(textColor.opacity(0.7)).lineLimit(1).truncationMode(.tail)
                } else {
                    Text(tool.statusDisplay.text)
                        .font(.system(size: 11)).foregroundColor(textColor.opacity(0.7)).lineLimit(1).truncationMode(.tail)
                }

                Spacer()

                if canExpand && tool.status != .running && tool.status != .waitingForApproval {
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .medium)).foregroundColor(.white.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isExpanded)
                }
            }

            if showContent && tool.status != .running && tool.name != "Task" && (hasResult || tool.name == "Edit") {
                ToolResultContent(tool: tool)
                    .padding(.leading, 12).padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if tool.name == "Edit" && tool.status == .running {
                EditInputDiffView(input: tool.input)
                    .padding(.leading, 12).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(canExpand && isHovering ? Color.white.opacity(0.05) : Color.clear))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            if canExpand {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isExpanded.toggle() }
            }
        }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isExpanded)
    }
}

// MARK: - Thinking View

struct ThinkingView: View {
    let text: String
    @State private var isExpanded = false
    private var canExpand: Bool { text.count > 80 }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle().fill(Color.gray.opacity(0.5)).frame(width: 6, height: 6).padding(.top, 4)
            Text(isExpanded ? text : String(text.prefix(80)) + (canExpand ? "..." : ""))
                .font(.system(size: 11)).foregroundColor(.gray).italic()
                .lineLimit(isExpanded ? nil : 1).multilineTextAlignment(.leading)
            Spacer()
            if canExpand {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .medium)).foregroundColor(.gray.opacity(0.5))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0)).padding(.top, 3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if canExpand {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isExpanded.toggle() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2)
    }
}

// MARK: - Interrupted Message

struct InterruptedMessageView: View {
    var body: some View {
        HStack {
            Text("Interrupted").font(.system(size: 13)).foregroundColor(.red)
            Spacer()
        }
    }
}
