import AppKit
import OhMyIslandCore

/// Detects whether a session's terminal tab/pane is currently the active (visible) one.
/// Used by smart-suppress to avoid notifying when the user is already looking at the session.
///
/// Two detection levels:
/// - **App-level** (`isTerminalFrontmostForSession`): fast, main-thread safe, checks if the
///   terminal app is the frontmost application. No AppleScript or subprocess calls.
/// - **Tab-level** (`isSessionTabVisible`): precise, checks the specific tab/session/pane.
///   Uses AppleScript or CLI calls that may block 50-200ms. Call from background thread only.
///
/// Supported tab-level detection:
/// - iTerm2: session ID match
/// - Ghostty: CWD match via System Events window title
/// - Terminal.app: TTY match on selected tab
/// - WezTerm: CLI pane query by TTY/CWD
/// - kitty: CLI window query by ID/CWD
/// - tmux: active pane match
/// - Others: falls back to app-level only
struct TerminalVisibilityDetector {

    // MARK: - App-level check (main-thread safe, no blocking)

    /// Fast check: is the session's terminal app the frontmost application?
    /// Safe to call from the main thread — no AppleScript or subprocess calls.
    static func isTerminalFrontmostForSession(_ session: SessionSnapshot) -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }

        if let termBundleId = session.termBundleId?.lowercased(),
           !termBundleId.isEmpty,
           frontApp.bundleIdentifier?.lowercased() == termBundleId {
            return true
        }

        guard let termApp = session.termApp else { return false }

        let frontName = frontApp.localizedName?.lowercased() ?? ""
        let bundleId = frontApp.bundleIdentifier?.lowercased() ?? ""
        let term = termApp.lowercased()
            .replacingOccurrences(of: ".app", with: "")
            .replacingOccurrences(of: "apple_", with: "")
        let normalizedFront = frontName.replacingOccurrences(of: ".app", with: "")

        return normalizedFront.contains(term)
            || term.contains(normalizedFront)
            || bundleId.contains(term)
    }

    // MARK: - Tab-level check (background thread only)

    /// Full check: is the session's specific tab/pane currently visible?
    /// **Call from a background thread only** — AppleScript/CLI calls may block 50-200ms.
    static func isSessionTabVisible(_ session: SessionSnapshot) -> Bool {
        // Fast path: terminal not even frontmost
        guard isTerminalFrontmostForSession(session) else { return false }

        // Native app bundles (Cursor APP, Codex APP): app IS the session, suppress when frontmost
        if session.isNativeAppMode {
            return true
        }

        // IDE integrated terminals: can't query tab state, assume NOT visible
        // (show notification — safer than suppressing when user may be editing code)
        if session.isIDETerminal {
            return false
        }

        guard let termApp = session.termApp else { return false }
        let term = termApp.lowercased()
            .replacingOccurrences(of: ".app", with: "")
            .replacingOccurrences(of: "apple_", with: "")

        // tmux takes priority: if session runs in a tmux pane, check that pane
        // regardless of which terminal app wraps tmux (iTerm2, Ghostty, etc.)
        if let pane = session.tmuxPane, !pane.isEmpty {
            return isTmuxPaneActive(pane)
        }

        let lower = term

        if lower.contains("iterm") {
            return isITermSessionActive(session)
        }
        if lower.contains("ghostty") {
            return isGhosttyTabActive(session)
        }
        if lower.contains("terminal") {
            return isTerminalAppTabActive(session)
        }
        if lower.contains("wezterm") || lower.contains("wez") {
            return isWezTermTabActive(session)
        }
        if lower.contains("kitty") {
            return isKittyWindowActive(session)
        }

        // Unknown terminal — app-level is the best we can do
        return true
    }

    // MARK: - iTerm2

    /// Check if the session's iTerm2 session ID matches the currently selected session.
    private static func isITermSessionActive(_ session: SessionSnapshot) -> Bool {
        // If we have a session ID, check precisely
        if let sessionId = session.itermSessionId, !sessionId.isEmpty {
            let escaped = escapeAppleScript(sessionId)
            let script = """
            tell application "iTerm2"
                try
                    set s to current session of current tab of current window
                    if unique ID of s is "\(escaped)" then return "true"
                end try
                return "false"
            end tell
            """
            return runAppleScriptSync(script)?.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        }
        // Fallback: match by CWD in the current session name/title
        if let cwd = session.cwd, !cwd.isEmpty {
            let dirName = escapeAppleScript((cwd as NSString).lastPathComponent)
            let script = """
            tell application "iTerm2"
                try
                    set s to current session of current tab of current window
                    if name of s contains "\(dirName)" then return "true"
                end try
                return "false"
            end tell
            """
            return runAppleScriptSync(script)?.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        }
        return true // no data to check — assume visible
    }

    // MARK: - Ghostty

    /// Check if Ghostty's front window matches this session's CWD.
    /// Uses System Events to read the front window title (Ghostty's native scripting
    /// doesn't expose a "focused terminal" property).
    private static func isGhosttyTabActive(_ session: SessionSnapshot) -> Bool {
        guard let cwd = session.cwd, !cwd.isEmpty else { return true }
        let dirName = escapeAppleScript((cwd as NSString).lastPathComponent)
        let script = """
        tell application "System Events"
            tell process "Ghostty"
                try
                    set winTitle to name of front window
                    if winTitle contains "\(dirName)" then return "true"
                end try
            end tell
        end tell
        return "false"
        """
        return runAppleScriptSync(script)?.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    // MARK: - Terminal.app

    /// Check if Terminal.app's selected tab has the matching TTY.
    private static func isTerminalAppTabActive(_ session: SessionSnapshot) -> Bool {
        if let tty = session.ttyPath, !tty.isEmpty {
            let escaped = escapeAppleScript(tty)
            let script = """
            tell application "Terminal"
                try
                    if tty of selected tab of front window is "\(escaped)" then return "true"
                end try
                return "false"
            end tell
            """
            return runAppleScriptSync(script)?.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        }
        // Fallback: match by CWD in title/history
        if let cwd = session.cwd, !cwd.isEmpty {
            let dirName = escapeAppleScript((cwd as NSString).lastPathComponent)
            let script = """
            tell application "Terminal"
                try
                    set t to selected tab of front window
                    set tabTitle to custom title of t
                    if tabTitle contains "\(dirName)" then return "true"
                    set tabHistory to history of t
                    if tabHistory contains "\(dirName)" then return "true"
                end try
                return "false"
            end tell
            """
            return runAppleScriptSync(script)?.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        }
        return true
    }

    // MARK: - WezTerm

    /// Check if WezTerm's active pane matches by TTY or CWD.
    private static func isWezTermTabActive(_ session: SessionSnapshot) -> Bool {
        guard let bin = findBinary("wezterm") else { return true }
        guard let json = runProcess(bin, args: ["cli", "list", "--format", "json"]),
              let panes = try? JSONSerialization.jsonObject(with: json) as? [[String: Any]] else { return true }

        // Find which pane is active
        guard let activePane = panes.first(where: { ($0["is_active"] as? Bool) == true }) else { return true }

        // Match by TTY
        if let tty = session.ttyPath,
           let paneTty = activePane["tty_name"] as? String,
           paneTty == tty { return true }

        // Match by CWD
        if let cwd = session.cwd,
           let paneCwd = activePane["cwd"] as? String {
            if paneCwd == cwd || paneCwd == "file://" + cwd { return true }
        }

        return false
    }

    // MARK: - kitty

    /// Check if kitty's focused window matches by window ID or CWD.
    private static func isKittyWindowActive(_ session: SessionSnapshot) -> Bool {
        guard let bin = findBinary("kitten") else { return true }
        guard let json = runProcess(bin, args: ["@", "ls"]),
              let osTabs = try? JSONSerialization.jsonObject(with: json) as? [[String: Any]] else { return true }

        // Find the focused window across all OS windows
        for osWindow in osTabs {
            let isFocused = (osWindow["is_focused"] as? Bool) == true
            guard isFocused, let tabs = osWindow["tabs"] as? [[String: Any]] else { continue }
            for tab in tabs {
                let isActive = (tab["is_focused"] as? Bool) == true
                guard isActive, let windows = tab["windows"] as? [[String: Any]] else { continue }
                for window in windows {
                    let winFocused = (window["is_focused"] as? Bool) == true
                    guard winFocused else { continue }

                    // Match by window ID
                    if let wid = session.kittyWindowId,
                       let winId = window["id"] as? Int,
                       "\(winId)" == wid { return true }

                    // Match by CWD
                    if let cwd = session.cwd,
                       let winCwd = window["cwd"] as? String,
                       winCwd == cwd { return true }

                    return false
                }
            }
        }
        return true
    }

    // MARK: - tmux

    /// Check if the tmux pane is the currently active one.
    private static func isTmuxPaneActive(_ pane: String) -> Bool {
        guard let bin = findBinary("tmux") else { return true }

        // Get the currently active pane
        guard let data = runProcess(bin, args: ["display-message", "-p", "#{session_name}:#{window_index}.#{pane_index}"]),
              let activePaneId = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !activePaneId.isEmpty else { return true }

        // The stored pane might be %N format; convert via list-panes
        guard let listData = runProcess(bin, args: ["list-panes", "-a", "-F", "#{pane_id} #{session_name}:#{window_index}.#{pane_index}"]),
              let listStr = String(data: listData, encoding: .utf8) else { return pane == activePaneId }

        for line in listStr.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            if parts.count == 2, String(parts[0]) == pane {
                return String(parts[1]) == activePaneId
            }
        }

        return pane == activePaneId
    }

    // MARK: - Helpers

    private static func escapeAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Run AppleScript synchronously and return the string result.
    private static func runAppleScriptSync(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        return result.stringValue
    }

    private static func findBinary(_ name: String) -> String? {
        let paths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
        ]
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    @discardableResult
    private static func runProcess(_ path: String, args: [String]) -> Data? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return proc.terminationStatus == 0 ? data : nil
        } catch {
            return nil
        }
    }
}
