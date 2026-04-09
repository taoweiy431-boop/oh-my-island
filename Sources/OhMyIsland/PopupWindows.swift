import AppKit
import OhMyIslandCore
import SwiftUI

// MARK: - Permission Popup Window

class PermissionPopupController {
    static let shared = PermissionPopupController()
    private var window: NSWindow?

    func show(tool: String, toolInput: [String: Any]?, onAllow: @escaping () -> Void, onDeny: @escaping () -> Void) {
        let view = PermissionPopupView(
            tool: tool,
            toolInput: toolInput,
            onAllow: { [weak self] in onAllow(); self?.dismiss() },
            onDeny: { [weak self] in onDeny(); self?.dismiss() }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 420, height: 300)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true
        panel.center()

        window = panel
        panel.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        window?.close()
        window = nil
    }
}

// MARK: - Permission Popup View

private struct PermissionPopupView: View {
    let tool: String
    let toolInput: [String: Any]?
    let onAllow: () -> Void
    let onDeny: () -> Void

    @State private var showContent = false

    private var fileName: String? {
        (toolInput?["file_path"] as? String).map { ($0 as NSString).lastPathComponent }
    }

    private var filePath: String? {
        toolInput?["file_path"] as? String
    }

    private let orange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Circle().fill(orange).frame(width: 8, height: 8)
                Text("Permission Request")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.white.opacity(0.06))

            // Tool info
            HStack(spacing: 6) {
                Image(systemName: toolIcon).font(.system(size: 12)).foregroundColor(orange.opacity(0.8))
                Text("\(tool)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                if let path = filePath {
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))

            // Diff preview for Edit/Write
            if tool == "Edit" {
                let oldStr = toolInput?["old_string"] as? String ?? ""
                let newStr = toolInput?["new_string"] as? String ?? ""
                if !oldStr.isEmpty || !newStr.isEmpty {
                    SimpleDiffView(oldString: oldStr, newString: newStr, filename: fileName)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }
            } else if tool == "Write", let content = toolInput?["content"] as? String {
                CodePreview(content: content, maxLines: 8)
                    .padding(.horizontal, 12).padding(.vertical, 8)
            } else if tool == "Bash", let cmd = toolInput?["command"] as? String {
                Text(cmd)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.white.opacity(0.03))
            }

            Spacer(minLength: 0)

            // Buttons
            HStack(spacing: 12) {
                Spacer()
                Button { onDeny() } label: {
                    Text("Deny")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 24).padding(.vertical, 9)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: [])

                Button { onAllow() } label: {
                    Text("Allow")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24).padding(.vertical, 9)
                        .background(Color.white.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("y", modifiers: [])
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .frame(width: 420)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.12))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(orange.opacity(0.25), lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 20)
        .scaleEffect(showContent ? 1 : 0.95)
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showContent = true }
        }
    }

    private var toolIcon: String {
        switch tool {
        case "Edit": return "pencil.line"
        case "Write": return "doc.badge.plus"
        case "Bash": return "terminal"
        case "Read": return "doc.text"
        case "Grep": return "magnifyingglass"
        default: return "wrench"
        }
    }
}

// MARK: - Question Popup Window

class QuestionPopupController {
    static let shared = QuestionPopupController()
    private var window: NSWindow?

    func show(question: String, options: [String]?, descriptions: [String]?, onAnswer: @escaping (String) -> Void, onSkip: @escaping () -> Void) {
        let view = QuestionPopupView(
            question: question,
            options: options,
            descriptions: descriptions,
            onAnswer: { [weak self] answer in onAnswer(answer); self?.dismiss() },
            onSkip: { [weak self] in onSkip(); self?.dismiss() }
        )

        let height: CGFloat = options != nil ? CGFloat(160 + (options!.count * 44)) : 200
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 380, height: height)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: height),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true
        panel.center()

        window = panel
        panel.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        window?.close()
        window = nil
    }
}

// MARK: - Question Popup View

private struct QuestionPopupView: View {
    let question: String
    let options: [String]?
    let descriptions: [String]?
    let onAnswer: (String) -> Void
    let onSkip: () -> Void

    @State private var textInput = ""
    @State private var showContent = false
    @FocusState private var isFocused: Bool

    private let cyan = Color(red: 0.3, green: 0.75, blue: 0.85)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.fill").font(.system(size: 12)).foregroundColor(cyan)
                Text("Claude asks")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(cyan)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            // Question text
            Text(question)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 16).padding(.bottom, 12)

            // Options or text input
            if let options, !options.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                        let desc = descriptions?.indices.contains(idx) == true ? descriptions?[idx] : nil
                        Button { onAnswer(option) } label: {
                            HStack(spacing: 8) {
                                Text("⌘\(idx + 1)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(cyan.opacity(0.7))
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.85))
                                    if let desc, !desc.isEmpty {
                                        Text(desc)
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.45))
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(cyan.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(cyan.opacity(0.15), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")), modifiers: .command)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
            } else {
                HStack(spacing: 8) {
                    TextField("Type your answer...", text: $textInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .focused($isFocused)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(cyan.opacity(0.2), lineWidth: 1))
                        .onSubmit { if !textInput.isEmpty { onAnswer(textInput) } }

                    Button { if !textInput.isEmpty { onAnswer(textInput) } } label: {
                        Text("Send")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(cyan.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
                .onAppear { isFocused = true }
            }
        }
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.1, blue: 0.12))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(cyan.opacity(0.2), lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 20)
        .scaleEffect(showContent ? 1 : 0.95)
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showContent = true }
        }
    }
}
