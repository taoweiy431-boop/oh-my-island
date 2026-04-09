import Foundation
import CoreServices
import os.log
import CodeIslandCore

/// Watches ~/.codex/sessions/ for new and updated rollout JSONL files and
/// synthesises HookEvent objects from the Codex session transcript.
///
/// This replaces hook-based Codex integration so that Codex TUI does not show
/// "Running hook" messages. The watcher maps transcript entries to
/// SessionStart / UserPromptSubmit / Stop events that are fed into AppState,
/// keeping the downstream pipeline identical to the hook path.
@MainActor
final class CodexSessionWatcher {
    private static let log = Logger(subsystem: "com.codeisland", category: "CodexSessionWatcher")

    private let appState: AppState
    private var stream: FSEventStreamRef?
    private var fileOffsets: [String: UInt64] = [:]
    private var sessionIdByFile: [String: String] = [:]
    private var announcedSessions: Set<String> = []

    private var sessionsRoot: String {
        NSHomeDirectory() + "/.codex/sessions"
    }

    init(appState: AppState) {
        self.appState = appState
    }

    func start() {
        let root = sessionsRoot
        try? FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)

        // Baseline existing files so we only react to NEW content going forward.
        seedInitialOffsets(at: root)

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let paths = [root] as CFArray
        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents
            | kFSEventStreamCreateFlagNoDefer
            | kFSEventStreamCreateFlagUseCFTypes
        )

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (_, info, numEvents, eventPaths, _, _) in
                guard let info else { return }
                let watcher = Unmanaged<CodexSessionWatcher>.fromOpaque(info).takeUnretainedValue()
                let cfArray = unsafeBitCast(eventPaths, to: CFArray.self)
                let count = CFArrayGetCount(cfArray)
                var paths: [String] = []
                paths.reserveCapacity(count)
                for i in 0..<count {
                    let ptr = CFArrayGetValueAtIndex(cfArray, i)
                    let cfString = unsafeBitCast(ptr, to: CFString.self)
                    paths.append(cfString as String)
                }
                Task { @MainActor in
                    watcher.handleFSEvents(paths: paths)
                }
                _ = numEvents
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            flags
        )

        guard let stream else {
            Self.log.error("Failed to create FSEventStream for \(root)")
            return
        }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        Self.log.info("CodexSessionWatcher started at \(root)")
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
    }

    // MARK: - FSEvents

    private func seedInitialOffsets(at root: String) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: root) else { return }
        for case let relative as String in enumerator {
            guard relative.hasSuffix(".jsonl") else { continue }
            let full = root + "/" + relative
            if let attrs = try? fm.attributesOfItem(atPath: full),
               let size = (attrs[.size] as? NSNumber)?.uint64Value {
                fileOffsets[full] = size
            }
        }
    }

    private func handleFSEvents(paths: [String]) {
        for path in paths where path.hasSuffix(".jsonl") {
            processFile(at: path)
        }
    }

    private func processFile(at path: String) {
        guard let handle = try? FileHandle(forReadingAtPath: path) else { return }
        defer { try? handle.close() }

        let startOffset = fileOffsets[path] ?? 0
        do {
            try handle.seek(toOffset: startOffset)
        } catch {
            return
        }

        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty else { return }

        // Only advance the offset at complete newline boundaries so partial
        // writes do not get mis-parsed. Back up to the last newline.
        var consumable = data
        if let lastNewline = consumable.lastIndex(of: 0x0A) {
            let consumeLen = lastNewline + 1
            consumable = data.prefix(consumeLen)
            fileOffsets[path] = startOffset + UInt64(consumeLen)
        } else {
            // No newline yet — wait for more
            return
        }

        guard let text = String(data: consumable, encoding: .utf8) else { return }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines {
            processLine(String(line), filePath: path)
        }
    }

    private func processLine(_ line: String, filePath: String) {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let type = obj["type"] as? String ?? ""
        let payload = obj["payload"] as? [String: Any] ?? [:]

        switch type {
        case "session_meta":
            handleSessionMeta(payload: payload, filePath: filePath)
        case "event_msg":
            handleEventMsg(payload: payload, filePath: filePath)
        default:
            break
        }
    }

    private func handleSessionMeta(payload: [String: Any], filePath: String) {
        guard let sessionId = payload["id"] as? String, !sessionId.isEmpty else { return }
        sessionIdByFile[filePath] = sessionId

        if announcedSessions.contains(sessionId) { return }
        announcedSessions.insert(sessionId)

        var raw: [String: Any] = [
            "hook_event_name": "SessionStart",
            "session_id": sessionId,
            "_source": "codex",
            "source": "startup",
        ]
        if let cwd = payload["cwd"] as? String { raw["cwd"] = cwd }
        if let model = payload["model"] as? String { raw["model"] = model }
        if let originator = payload["originator"] as? String { raw["originator"] = originator }
        raw["transcript_path"] = filePath

        emit(raw)
    }

    private func handleEventMsg(payload: [String: Any], filePath: String) {
        let evtType = payload["type"] as? String ?? ""
        guard let sessionId = sessionIdByFile[filePath] ?? sessionIdFromFilename(filePath) else {
            return
        }

        switch evtType {
        case "user_message":
            var raw: [String: Any] = [
                "hook_event_name": "UserPromptSubmit",
                "session_id": sessionId,
                "_source": "codex",
                "transcript_path": filePath,
            ]
            if let message = payload["message"] as? String { raw["prompt"] = message }
            emit(raw)

        case "task_complete":
            var raw: [String: Any] = [
                "hook_event_name": "Stop",
                "session_id": sessionId,
                "_source": "codex",
                "transcript_path": filePath,
            ]
            if let last = payload["last_assistant_message"] as? String {
                raw["last_assistant_message"] = last
            }
            emit(raw)

        default:
            break
        }
    }

    private func sessionIdFromFilename(_ path: String) -> String? {
        let name = (path as NSString).lastPathComponent
        // rollout-2026-04-09T01-30-36-019d7081-a026-7220-b8d4-74eb36fbfb89.jsonl
        let pattern = #"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(name.startIndex..., in: name)
        guard let match = regex.firstMatch(in: name, range: range),
              let r = Range(match.range(at: 1), in: name) else { return nil }
        return String(name[r])
    }

    private func emit(_ raw: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: raw),
              let event = HookEvent(from: data) else {
            return
        }
        appState.handleEvent(event)
    }
}
