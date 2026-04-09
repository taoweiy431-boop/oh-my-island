import OhMyIslandCore
import Foundation
import os

@MainActor
class TerminalSender {
    static let shared = TerminalSender()
    private let logger = Logger(subsystem: "com.codeisland", category: "TerminalSender")
    private let queue = DispatchQueue(label: "com.codeisland.terminal-sender", qos: .userInitiated)

    func sendMessage(_ text: String, to session: SessionSnapshot, sessionId: String) async -> Bool {
        let ttyPath = session.ttyPath
        let tmuxPane = session.tmuxPane
        let cliPid = session.cliPid
        let termApp = session.termApp
        let itermSessionId = session.itermSessionId
        let cwd = session.cwd

        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                let result = self.sendSync(
                    text: text, sessionId: sessionId,
                    ttyPath: ttyPath, tmuxPane: tmuxPane, cliPid: cliPid,
                    termApp: termApp, itermSessionId: itermSessionId, cwd: cwd
                )
                continuation.resume(returning: result)
            }
        }
    }

    private nonisolated func sendSync(
        text: String, sessionId: String,
        ttyPath: String?, tmuxPane: String?, cliPid: pid_t?,
        termApp: String?, itermSessionId: String?, cwd: String?
    ) -> Bool {
        let message = text + "\n"

        // Strategy 1: Direct TTY write via known ttyPath
        if let tty = ttyPath {
            let ttyDev = tty.hasPrefix("/dev/") ? tty : "/dev/\(tty)"
            if writeToTTYSync(message, ttyPath: ttyDev) { return true }
        }

        // Strategy 2: tmux send-keys
        if let pane = tmuxPane {
            if sendViaTmuxSync(text, pane: pane) { return true }
        }

        // Strategy 3: Find TTY via PID
        if let pid = cliPid, let tty = findTTYSync(for: pid) {
            if writeToTTYSync(message, ttyPath: tty) { return true }
        }

        // Strategy 4: Find Claude process by session ID or fallback
        if let tty = findClaudeProcessTTYSync(sessionId: sessionId, cwd: cwd) {
            if writeToTTYSync(message, ttyPath: tty) { return true }
        }

        // Strategy 5: AppleScript
        if let app = termApp {
            if sendViaAppleScriptSync(text, termApp: app, itermSessionId: itermSessionId) { return true }
        }

        return false
    }

    // MARK: - TTY Direct Write

    private nonisolated func writeToTTYSync(_ text: String, ttyPath: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        let fd = open(ttyPath, O_WRONLY | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        let result = data.withUnsafeBytes { bytes in
            Darwin.write(fd, bytes.baseAddress!, bytes.count)
        }
        return result > 0
    }

    // MARK: - tmux send-keys

    private nonisolated func sendViaTmuxSync(_ text: String, pane: String) -> Bool {
        guard let tmuxPath = findExecutable("tmux") else { return false }
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: ";", with: "\\;")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: tmuxPath)
        proc.arguments = ["send-keys", "-t", pane, escaped, "Enter"]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        do { try proc.run(); proc.waitUntilExit(); return proc.terminationStatus == 0 }
        catch { return false }
    }

    // MARK: - AppleScript

    private nonisolated func escapeAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private nonisolated func sendViaAppleScriptSync(_ text: String, termApp: String, itermSessionId: String?) -> Bool {
        let escaped = escapeAppleScript(text)

        let script: String
        if termApp.contains("iTerm") {
            if let sessionId = itermSessionId {
                let escapedSessionId = escapeAppleScript(sessionId)
                script = """
                tell application "iTerm2"
                    repeat with w in windows
                        repeat with t in tabs of w
                            repeat with s in sessions of t
                                if unique ID of s is "\(escapedSessionId)" then
                                    tell s to write text "\(escaped)"
                                    return
                                end if
                            end repeat
                        end repeat
                    end repeat
                end tell
                """
            } else {
                script = """
                tell application "iTerm2"
                    tell current session of current tab of current window
                        write text "\(escaped)"
                    end tell
                end tell
                """
            }
        } else {
            script = """
            tell application "Terminal"
                do script "\(escaped)" in front window
            end tell
            """
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()

        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Utilities

    /// Find Claude process TTY by matching session ID in command line args, or fall back to cwd match
    private nonisolated func findClaudeProcessTTYSync(sessionId: String? = nil, cwd: String?) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-eo", "pid,tty,command"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            var fallbackTTY: String?

            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.contains("claude") || trimmed.contains(".local/bin/claude") else { continue }
                guard !trimmed.contains("CodeIsland") && !trimmed.contains("claude-code-acp") else { continue }

                let parts = trimmed.split(separator: " ", maxSplits: 2)
                guard parts.count >= 2 else { continue }

                let ttyPart = String(parts[1])
                guard ttyPart != "??" && !ttyPart.isEmpty else { continue }

                let ttyPath = ttyPart.hasPrefix("/dev/") ? ttyPart : "/dev/\(ttyPart)"

                // Exact match by session ID in command args
                if let sid = sessionId, parts.count >= 3 {
                    let cmd = String(parts[2])
                    if cmd.contains(sid) {
                        return ttyPath
                    }
                }

                // Keep first match as fallback
                if fallbackTTY == nil {
                    fallbackTTY = ttyPath
                }
            }

            return fallbackTTY
        } catch {}

        return nil
    }

    private nonisolated func findTTYSync(for pid: pid_t) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-p", "\(pid)", "-o", "tty="]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let tty = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !tty.isEmpty, tty != "??" {
                return "/dev/\(tty)"
            }
        } catch {}
        return nil
    }

    private nonisolated func findExecutable(_ name: String) -> String? {
        let paths = ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"]
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }
}
