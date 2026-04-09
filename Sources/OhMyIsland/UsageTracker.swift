import Foundation
import SQLite3
import SwiftUI
import UserNotifications
import os.log

private let log = Logger(subsystem: "com.codeisland", category: "UsageTracker")

// MARK: - Service Types

enum AIService: String, CaseIterable, Identifiable {
    case claude = "Claude Code"
    case codex = "OpenAI Codex"
    case gemini = "Google Gemini"
    case copilot = "GitHub Copilot"
    case cursor = "Cursor"
    case zai = "Z.ai"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .claude:  return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex:   return Color(red: 0.45, green: 0.45, blue: 0.45)
        case .gemini:  return Color(red: 0.26, green: 0.52, blue: 0.96)
        case .copilot: return Color(red: 0.35, green: 0.78, blue: 0.35)
        case .cursor:  return Color(red: 0.55, green: 0.40, blue: 0.95)
        case .zai:     return Color(red: 0.40, green: 0.30, blue: 0.85)
        }
    }

    var primaryLabel: String {
        switch self {
        case .claude:  return "5h"
        case .codex:   return "5h"
        case .gemini:  return "1d"
        case .copilot: return "Mo"
        case .cursor:  return "Mo"
        case .zai:     return "5h"
        }
    }

    var secondaryLabel: String? {
        switch self {
        case .claude:  return "7d"
        case .codex:   return "7d"
        case .gemini:  return nil
        case .copilot: return nil
        case .cursor:  return "Req"
        case .zai:     return "MCP"
        }
    }
}

enum UsageUnit {
    case percent
    case tokens
    case requests
}

struct UsageMetric: Equatable {
    let used: Double
    let total: Double
    let unit: UsageUnit
    let resetTime: Date?

    var percentage: Double {
        total > 0 ? min(used / total, 1.0) : 0
    }

    var percentInt: Int { Int(percentage * 100) }

    var displayValue: String {
        switch unit {
        case .percent:
            return "\(percentInt)%"
        case .tokens:
            return "\(formatNumber(used)) / \(formatNumber(total))"
        case .requests:
            return "\(Int(used)) / \(Int(total))"
        }
    }

    static func == (lhs: UsageMetric, rhs: UsageMetric) -> Bool {
        lhs.used == rhs.used && lhs.total == rhs.total && lhs.resetTime == rhs.resetTime
    }

    private func formatNumber(_ n: Double) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", n / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", n / 1_000) }
        return "\(Int(n))"
    }
}

struct ServiceUsageData: Equatable, Identifiable {
    let service: AIService
    let primaryUsage: UsageMetric?
    let secondaryUsage: UsageMetric?
    let planName: String?
    let isAvailable: Bool
    var isStale: Bool = false
    var cacheHitRate: Double? = nil

    var id: String { service.id }

    var maxPercent: Int {
        max(primaryUsage?.percentInt ?? 0, secondaryUsage?.percentInt ?? 0)
    }

    var color: Color {
        if isStale { return .gray }
        let pct = maxPercent
        if pct >= 90 { return Color(red: 0.94, green: 0.27, blue: 0.27) }
        if pct >= 70 { return Color(red: 1.0, green: 0.6, blue: 0.2) }
        return service.color
    }

    var cacheHitColor: Color? {
        guard let rate = cacheHitRate else { return nil }
        if rate < 60 { return Color(red: 0.94, green: 0.27, blue: 0.27) }
        if rate < 80 { return Color(red: 1.0, green: 0.6, blue: 0.2) }
        return Color(red: 0.29, green: 0.87, blue: 0.5)
    }

    var cacheHitWarning: String? {
        guard let rate = cacheHitRate else { return nil }
        if rate < 60 { return "缓存命中极低，可能使用了不支持 Prompt Caching 的 API" }
        if rate < 80 { return "缓存命中率偏低，建议避免频繁切换项目" }
        return nil
    }

    static func == (lhs: ServiceUsageData, rhs: ServiceUsageData) -> Bool {
        lhs.service == rhs.service &&
        lhs.primaryUsage == rhs.primaryUsage &&
        lhs.secondaryUsage == rhs.secondaryUsage &&
        lhs.planName == rhs.planName &&
        lhs.isAvailable == rhs.isAvailable &&
        lhs.isStale == rhs.isStale &&
        lhs.cacheHitRate == rhs.cacheHitRate
    }
}

// Keep backward compat for the notch mini bar
struct UsageDisplayInfo: Equatable {
    let fiveHourPercent: Int?
    let sevenDayPercent: Int?
    let fiveHourResetAt: Date?
    let sevenDayResetAt: Date?

    var maxPercent: Int { max(fiveHourPercent ?? 0, sevenDayPercent ?? 0) }

    var color: Color {
        let pct = maxPercent
        if pct >= 90 { return Color(red: 0.94, green: 0.27, blue: 0.27) }
        if pct >= 70 { return Color(red: 1.0, green: 0.6, blue: 0.2) }
        return Color(red: 0.29, green: 0.87, blue: 0.5)
    }

    var compactText: String {
        guard let pct = fiveHourPercent else { return "--" }
        return "\(pct)%"
    }

    var tooltip: String {
        var lines: [String] = []
        if let pct = fiveHourPercent {
            let reset = formatRemaining(fiveHourResetAt)
            lines.append("5h: \(pct)%\(reset.isEmpty ? "" : " (\(reset)后重置)")")
        }
        if let pct = sevenDayPercent {
            let reset = formatRemaining(sevenDayResetAt)
            lines.append("7d: \(pct)%\(reset.isEmpty ? "" : " (\(reset)后重置)")")
        }
        return lines.isEmpty ? "Claude 用量" : lines.joined(separator: "\n")
    }

    func formatRemaining(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "" }
        if remaining < 3600 {
            return "\(Int(remaining / 60))分钟"
        } else if remaining < 86400 {
            let h = Int(remaining / 3600)
            let m = Int(remaining.truncatingRemainder(dividingBy: 3600) / 60)
            return m > 0 ? "\(h)小时\(m)分钟" : "\(h)小时"
        }
        return "\(Int(remaining / 86400))天"
    }

    func formatRemainingShort(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "" }
        if remaining < 3600 {
            return "\(Int(remaining / 60))m"
        } else if remaining < 86400 {
            let h = Int(remaining / 3600)
            let m = Int(remaining.truncatingRemainder(dividingBy: 3600) / 60)
            return m > 0 ? "\(h)h\(m)m" : "\(h)h"
        }
        return "\(Int(remaining / 86400))d"
    }
}

// MARK: - Usage Provider Protocol

protocol UsageProvider {
    var service: AIService { get }
    func isConfigured() -> Bool
    func fetchUsage() async -> ServiceUsageData?
}

// MARK: - UsageTracker

@MainActor
@Observable
final class UsageTracker {
    static let shared = UsageTracker()

    var info: UsageDisplayInfo?
    var services: [ServiceUsageData] = []
    var isLoading = false

    private var refreshTimer: Timer?
    private var hasNotified5h = false
    private var hasNotified7d = false
    private var providers: [UsageProvider] = []
    private var cachedResults: [AIService: ServiceUsageData] = [:]

    private init() {
        providers = [
            ClaudeUsageProvider(),
            CodexUsageProvider(),
            GeminiUsageProvider(),
            CopilotUsageProvider(),
            CursorUsageProvider(),
            ZaiUsageProvider(),
        ]
    }

    func start() {
        Task { await refresh() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let configuredProviders = providers.filter { $0.isConfigured() }
        let configuredServices = Set(configuredProviders.map(\.service))

        var freshResults: [AIService: ServiceUsageData] = [:]
        await withTaskGroup(of: (AIService, ServiceUsageData?).self) { group in
            for provider in configuredProviders {
                group.addTask { (provider.service, await provider.fetchUsage()) }
            }
            for await (service, result) in group {
                freshResults[service] = result
            }
        }

        var results: [ServiceUsageData] = []
        for service in configuredServices {
            if let fresh = freshResults[service] {
                cachedResults[service] = fresh
                results.append(fresh)
            } else if var cached = cachedResults[service] {
                cached.isStale = true
                results.append(cached)
            }
        }

        for key in cachedResults.keys where !configuredServices.contains(key) {
            cachedResults.removeValue(forKey: key)
        }

        services = results.sorted { $0.maxPercent > $1.maxPercent }

        if let claude = results.first(where: { $0.service == .claude }) {
            info = UsageDisplayInfo(
                fiveHourPercent: claude.primaryUsage?.percentInt,
                sevenDayPercent: claude.secondaryUsage?.percentInt,
                fiveHourResetAt: claude.primaryUsage?.resetTime,
                sevenDayResetAt: claude.secondaryUsage?.resetTime
            )
            checkAlerts(info!)
        } else {
            let highest = results.max(by: { $0.maxPercent < $1.maxPercent })
            if let h = highest {
                info = UsageDisplayInfo(
                    fiveHourPercent: h.primaryUsage?.percentInt,
                    sevenDayPercent: h.secondaryUsage?.percentInt,
                    fiveHourResetAt: h.primaryUsage?.resetTime,
                    sevenDayResetAt: h.secondaryUsage?.resetTime
                )
            }
        }
    }

    // MARK: - Alerts

    private func checkAlerts(_ info: UsageDisplayInfo) {
        let threshold = UserDefaults.standard.integer(forKey: SettingsKey.usageWarningThreshold)
        guard threshold > 0 else {
            hasNotified5h = false
            hasNotified7d = false
            return
        }

        if let pct = info.fiveHourPercent {
            if pct >= threshold && !hasNotified5h {
                let reset = info.formatRemainingShort(info.fiveHourResetAt)
                sendNotification(window: "5h", percent: pct, reset: reset)
                hasNotified5h = true
            } else if pct < threshold {
                hasNotified5h = false
            }
        }

        if let pct = info.sevenDayPercent {
            if pct >= threshold && !hasNotified7d {
                let reset = info.formatRemainingShort(info.sevenDayResetAt)
                sendNotification(window: "7d", percent: pct, reset: reset)
                hasNotified7d = true
            } else if pct < threshold {
                hasNotified7d = false
            }
        }
    }

    private func sendNotification(window: String, percent: Int, reset: String) {
        let content = UNMutableNotificationContent()
        content.title = "Claude Code 用量警告"
        content.body = reset.isEmpty
            ? "\(window) 窗口用量已达 \(percent)%"
            : "\(window) 窗口用量已达 \(percent)%，\(reset)后重置"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "codeisland.usage.\(window)",
            content: content,
            trigger: nil
        )
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func readClaudeOAuthToken() -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let json = try? JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any],
                  let oauth = json["claudeAiOauth"] as? [String: Any],
                  let token = oauth["accessToken"] as? String else { return nil }
            return token
        } catch {
            return nil
        }
    }

    static func readGHToken() -> String? {
        let ghPaths = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        guard let ghPath = ghPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return nil }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["auth", "token"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !token.isEmpty else { return nil }
            return token
        } catch {
            return nil
        }
    }

    /// Read Codex OAuth credentials from Keychain or auth.json
    static func readCodexOAuthToken() -> (token: String, accountId: String?)? {
        if let result = readCodexFromKeychain() { return result }
        return readCodexFromFile()
    }

    private static func readCodexFromKeychain() -> (token: String, accountId: String?)? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Codex Auth", "-w"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        guard let _ = try? process.run() else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else { return nil }
        return parseCodexAuthJson(output)
    }

    private static func readCodexFromFile() -> (token: String, accountId: String?)? {
        let authPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json").path
        guard let content = try? String(contentsOfFile: authPath, encoding: .utf8) else { return nil }
        return parseCodexAuthJson(content)
    }

    private static func parseCodexAuthJson(_ content: String) -> (token: String, accountId: String?)? {
        guard let json = try? JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any],
              let authMode = json["auth_mode"] as? String, authMode == "chatgpt",
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String, !accessToken.isEmpty else { return nil }
        let accountId = tokens["account_id"] as? String
        return (accessToken, accountId)
    }

    /// Read Gemini OAuth credentials from Keychain or oauth_creds.json
    static func readGeminiOAuthToken() -> (token: String, refreshToken: String?)? {
        if let result = readGeminiFromKeychain() { return result }
        return readGeminiFromFile()
    }

    private static func readGeminiFromKeychain() -> (token: String, refreshToken: String?)? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "gemini-cli-oauth", "-a", "main-account", "-w"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        guard let _ = try? process.run() else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any] else { return nil }

        if let tokenObj = json["token"] as? [String: Any],
           let at = tokenObj["accessToken"] as? String, !at.isEmpty {
            let rt = tokenObj["refreshToken"] as? String
            return (at, rt)
        }
        return parseGeminiCredsFile(json)
    }

    private static func readGeminiFromFile() -> (token: String, refreshToken: String?)? {
        let credsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/oauth_creds.json").path
        guard let content = try? String(contentsOfFile: credsPath, encoding: .utf8),
              let json = try? JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any] else { return nil }
        return parseGeminiCredsFile(json)
    }

    private static func parseGeminiCredsFile(_ json: [String: Any]) -> (token: String, refreshToken: String?)? {
        guard let at = json["access_token"] as? String, !at.isEmpty else { return nil }
        let rt = json["refresh_token"] as? String
        return (at, rt)
    }

    private static func geminiOAuthCredentials() -> (clientId: String, clientSecret: String)? {
        let credsPaths = [
            NSHomeDirectory() + "/.gemini/oauth_creds.json",
            NSHomeDirectory() + "/.config/gemini/oauth_creds.json",
        ]
        for path in credsPaths {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let clientId = json["client_id"] as? String,
                  let clientSecret = json["client_secret"] as? String else { continue }
            return (clientId, clientSecret)
        }
        return nil
    }

    static func refreshGeminiToken(_ refreshToken: String) async -> String? {
        guard let creds = geminiOAuthCredentials() else { return nil }
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=\(creds.clientId)&client_secret=\(creds.clientSecret)&refresh_token=\(refreshToken)&grant_type=refresh_token"
        request.httpBody = body.data(using: .utf8)
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["access_token"] as? String else { return nil }
        return newToken
    }
}

// MARK: - Claude Code Provider

struct ClaudeUsageProvider: UsageProvider {
    let service = AIService.claude
    private let claudeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")

    func isConfigured() -> Bool {
        KeychainHelper.readClaudeOAuthToken() != nil || hasJSONLFiles()
    }

    func fetchUsage() async -> ServiceUsageData? {
        if let token = KeychainHelper.readClaudeOAuthToken(),
           let result = await fetchFromOAuthAPI(token: token) {
            return result
        }
        return fetchFromJSONL()
    }

    // MARK: OAuth API (Pro users)

    private func fetchFromOAuthAPI(token: String) async -> ServiceUsageData? {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let fiveHour = mergedWindow(json: json, prefix: "five_hour")
            let sevenDay = mergedWindow(json: json, prefix: "seven_day")

            let fhPct = fiveHour?["utilization"] as? Double
            let sdPct = sevenDay?["utilization"] as? Double
            let fhReset = (fiveHour?["resets_at"] as? String).flatMap { formatter.date(from: $0) }
            let sdReset = (sevenDay?["resets_at"] as? String).flatMap { formatter.date(from: $0) }

            log.debug("Claude OAuth: 5h=\(fhPct ?? -1)% 7d=\(sdPct ?? -1)%")

            let primary = fhPct.map { UsageMetric(used: $0, total: 100, unit: .percent, resetTime: fhReset) }
            let secondary = sdPct.map { UsageMetric(used: $0, total: 100, unit: .percent, resetTime: sdReset) }

            return ServiceUsageData(
                service: .claude, primaryUsage: primary, secondaryUsage: secondary,
                planName: "Pro", isAvailable: true
            )
        } catch {
            log.warning("Claude OAuth fetch: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: JSONL Fallback (API key users)

    private func hasJSONLFiles() -> Bool {
        let projectsDir = claudeDir.appendingPathComponent("projects")
        return FileManager.default.fileExists(atPath: projectsDir.path)
    }

    private func fetchFromJSONL() -> ServiceUsageData? {
        let projectsDir = claudeDir.appendingPathComponent("projects")
        let fm = FileManager.default
        guard fm.fileExists(atPath: projectsDir.path) else { return nil }

        let fiveHoursAgo = Date().addingTimeInterval(-5 * 3600)
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 86400)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var tokens5h: Double = 0
        var tokens7d: Double = 0
        var messageCount5h = 0
        var messageCount7d = 0
        var totalInputTokens: Double = 0
        var totalCacheRead: Double = 0

        guard let projectEnum = fm.enumerator(at: projectsDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }

        while let fileURL = projectEnum.nextObject() as? URL {
            guard fileURL.pathExtension == "jsonl" else { continue }
            guard let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  modDate > sevenDaysAgo else { continue }

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            for line in content.components(separatedBy: .newlines) where !line.isEmpty {
                guard let lineData = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }
                guard obj["type"] as? String == "assistant",
                      let message = obj["message"] as? [String: Any],
                      let usage = message["usage"] as? [String: Any] else { continue }

                let inputTokens = usage["input_tokens"] as? Double ?? 0
                let outputTokens = usage["output_tokens"] as? Double ?? 0
                let cacheCreation = usage["cache_creation_input_tokens"] as? Double ?? 0
                let cacheRead = usage["cache_read_input_tokens"] as? Double ?? 0
                let total = inputTokens + outputTokens + cacheCreation
                guard total > 0 else { continue }

                guard let ts = obj["timestamp"] as? String, let date = isoFormatter.date(from: ts) else { continue }

                if date > fiveHoursAgo {
                    tokens5h += total
                    messageCount5h += 1
                    totalInputTokens += inputTokens
                    totalCacheRead += cacheRead
                }
                if date > sevenDaysAgo {
                    tokens7d += total
                    messageCount7d += 1
                }
            }
        }

        guard tokens5h > 0 || tokens7d > 0 else { return nil }

        let defaults = UserDefaults.standard
        let fiveHourLimit = Double(defaults.integer(forKey: SettingsKey.claudeApiKeyFiveHourLimit))
        let weeklyLimit = Double(defaults.integer(forKey: SettingsKey.claudeApiKeyWeeklyLimit))
        let effectiveFhLimit = fiveHourLimit > 0 ? fiveHourLimit : 5_000_000
        let effectiveWkLimit = weeklyLimit > 0 ? weeklyLimit : 50_000_000

        var cacheHitRate: Double? = nil
        let totalInput = totalInputTokens + totalCacheRead
        if totalInput > 0 && messageCount5h >= 3 {
            cacheHitRate = totalCacheRead / totalInput * 100
        }

        log.debug("Claude JSONL: 5h=\(Int(tokens5h)) tokens (\(messageCount5h) msgs), cache hit=\(cacheHitRate.map { String(format: "%.1f%%", $0) } ?? "N/A")")

        let primary = UsageMetric(used: tokens5h, total: effectiveFhLimit, unit: .tokens, resetTime: nil)
        let secondary = UsageMetric(used: tokens7d, total: effectiveWkLimit, unit: .tokens, resetTime: nil)

        return ServiceUsageData(
            service: .claude, primaryUsage: primary, secondaryUsage: secondary,
            planName: "API Key", isAvailable: true,
            cacheHitRate: cacheHitRate
        )
    }

    private func mergedWindow(json: [String: Any], prefix: String) -> [String: Any]? {
        if let exact = json[prefix] as? [String: Any] { return exact }
        let matching = json.filter { $0.key.hasPrefix(prefix + "_") }
            .compactMap { $0.value as? [String: Any] }
        guard !matching.isEmpty else { return nil }
        var maxUtil: Double = 0
        var earliestReset: String?
        for w in matching {
            if let u = w["utilization"] as? Double, u > maxUtil { maxUtil = u }
            if let r = w["resets_at"] as? String {
                if earliestReset == nil || r < earliestReset! { earliestReset = r }
            }
        }
        var result: [String: Any] = ["utilization": maxUtil]
        if let r = earliestReset { result["resets_at"] = r }
        return result
    }
}

// MARK: - OpenAI Codex Provider

struct CodexUsageProvider: UsageProvider {
    let service = AIService.codex
    private let sessionsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")

    func isConfigured() -> Bool {
        KeychainHelper.readCodexOAuthToken() != nil || FileManager.default.fileExists(atPath: sessionsDir.path)
    }

    func fetchUsage() async -> ServiceUsageData? {
        if let creds = KeychainHelper.readCodexOAuthToken(),
           let result = await fetchFromOAuthAPI(token: creds.token, accountId: creds.accountId) {
            return result
        }
        return fetchFromJSONL()
    }

    private func fetchFromOAuthAPI(token: String, accountId: String?) async -> ServiceUsageData? {
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountId = accountId {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rateLimit = json["rate_limit"] as? [String: Any] else { return nil }

            var primaryMetric: UsageMetric?
            var secondaryMetric: UsageMetric?

            if let primary = rateLimit["primary_window"] as? [String: Any] {
                let usedPct = primary["used_percent"] as? Double ?? 0
                let windowSecs = primary["limit_window_seconds"] as? Int ?? 18000
                let resetAt = (primary["reset_at"] as? Int).map { Date(timeIntervalSince1970: Double($0)) }
                let limit: Double = windowSecs == 18000 ? 10_000_000 : 100_000_000
                primaryMetric = UsageMetric(used: limit * usedPct / 100, total: limit, unit: .tokens, resetTime: resetAt)
            }
            if let secondary = rateLimit["secondary_window"] as? [String: Any] {
                let usedPct = secondary["used_percent"] as? Double ?? 0
                let resetAt = (secondary["reset_at"] as? Int).map { Date(timeIntervalSince1970: Double($0)) }
                let limit: Double = 100_000_000
                secondaryMetric = UsageMetric(used: limit * usedPct / 100, total: limit, unit: .tokens, resetTime: resetAt)
            }

            guard primaryMetric != nil else { return nil }
            return ServiceUsageData(service: .codex, primaryUsage: primaryMetric, secondaryUsage: secondaryMetric,
                                    planName: "Pro", isAvailable: true)
        } catch {
            log.warning("Codex OAuth fetch: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchFromJSONL() -> ServiceUsageData? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: sessionsDir.path) else { return nil }

        let sevenDaysAgo = Date().addingTimeInterval(-7 * 86400)
        guard let enumerator = fm.enumerator(at: sessionsDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }

        var latestRateLimits: [String: (primary: CodexRateWindow?, secondary: CodexRateWindow?)] = [:]
        var tokenSum5h: Double = 0
        var tokenSum7d: Double = 0
        let fiveHoursAgo = Date().addingTimeInterval(-5 * 3600)

        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "jsonl" else { continue }
            guard let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  modDate > sevenDaysAgo else { continue }

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            for line in content.components(separatedBy: .newlines) where !line.isEmpty {
                guard let lineData = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

                guard let type = obj["type"] as? String, type == "event_msg",
                      let payload = obj["payload"] as? [String: Any],
                      let payloadType = payload["type"] as? String, payloadType == "token_count" else { continue }

                if let rateLimits = payload["rate_limits"] as? [String: Any] {
                    let limitId = rateLimits["limit_id"] as? String ?? ""
                    let primary = (rateLimits["primary"] as? [String: Any]).flatMap { parseRateWindow($0) }
                    let secondary = (rateLimits["secondary"] as? [String: Any]).flatMap { parseRateWindow($0) }
                    latestRateLimits[limitId] = (primary, secondary)
                }

                if let info = payload["info"] as? [String: Any],
                   let lastUsage = info["last_token_usage"] as? [String: Any],
                   let timestamp = obj["timestamp"] as? String {
                    let total = tokenTotal(lastUsage)
                    let isoFormatter = ISO8601DateFormatter()
                    if let date = isoFormatter.date(from: timestamp) {
                        if date > fiveHoursAgo { tokenSum5h += total }
                        if date > sevenDaysAgo { tokenSum7d += total }
                    }
                }
            }
        }

        let fiveHourLimit: Double = 10_000_000
        let weeklyLimit: Double = 100_000_000

        var primaryMetric: UsageMetric?
        var secondaryMetric: UsageMetric?

        if !latestRateLimits.isEmpty {
            var primaryUsed: Double = 0, primaryReset: Date?
            var secondaryUsed: Double = 0, secondaryReset: Date?

            for (_, limits) in latestRateLimits {
                if let p = limits.primary {
                    let used = fiveHourLimit * (p.usedPercent ?? 0) / 100
                    primaryUsed += used
                    if let r = p.resetDate, (primaryReset == nil || r < primaryReset!) { primaryReset = r }
                }
                if let s = limits.secondary {
                    let used = weeklyLimit * (s.usedPercent ?? 0) / 100
                    secondaryUsed += used
                    if let r = s.resetDate, (secondaryReset == nil || r < secondaryReset!) { secondaryReset = r }
                }
            }
            primaryMetric = UsageMetric(used: primaryUsed, total: fiveHourLimit, unit: .tokens, resetTime: primaryReset)
            secondaryMetric = UsageMetric(used: secondaryUsed, total: weeklyLimit, unit: .tokens, resetTime: secondaryReset)
        } else if tokenSum5h > 0 || tokenSum7d > 0 {
            primaryMetric = UsageMetric(used: tokenSum5h, total: fiveHourLimit, unit: .tokens, resetTime: nil)
            secondaryMetric = UsageMetric(used: tokenSum7d, total: weeklyLimit, unit: .tokens, resetTime: nil)
        }

        guard primaryMetric != nil else { return nil }

        let hasOAuth = KeychainHelper.readCodexOAuthToken() != nil
        return ServiceUsageData(
            service: .codex, primaryUsage: primaryMetric, secondaryUsage: secondaryMetric,
            planName: hasOAuth ? "Pro" : "API Key", isAvailable: true
        )
    }

    private func tokenTotal(_ usage: [String: Any]) -> Double {
        let input = usage["input"] as? Double ?? 0
        let cachedInput = usage["cached_input"] as? Double ?? 0
        let output = usage["output"] as? Double ?? 0
        let reasoning = usage["reasoning"] as? Double ?? 0
        return input + cachedInput + output + reasoning
    }

    private func parseRateWindow(_ dict: [String: Any]) -> CodexRateWindow {
        let usedPercent = dict["used_percent"] as? Double
        let windowMinutes = dict["window_minutes"] as? Int
        let resetsAtUnix = dict["resets_at"] as? Int
        let resetDate = resetsAtUnix.map { Date(timeIntervalSince1970: Double($0)) }
        return CodexRateWindow(usedPercent: usedPercent, windowMinutes: windowMinutes, resetDate: resetDate)
    }
}

private struct CodexRateWindow {
    let usedPercent: Double?
    let windowMinutes: Int?
    let resetDate: Date?
}

// MARK: - Google Gemini Provider

struct GeminiUsageProvider: UsageProvider {
    let service = AIService.gemini
    private let logsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gemini/tmp")

    func isConfigured() -> Bool {
        KeychainHelper.readGeminiOAuthToken() != nil || FileManager.default.fileExists(atPath: logsDir.path)
    }

    func fetchUsage() async -> ServiceUsageData? {
        if let creds = KeychainHelper.readGeminiOAuthToken() {
            var token = creds.token
            if let result = await fetchFromOAuthAPI(token: token) { return result }
            if let rt = creds.refreshToken, let newToken = await KeychainHelper.refreshGeminiToken(rt) {
                token = newToken
                if let result = await fetchFromOAuthAPI(token: token) { return result }
            }
        }
        return fetchFromLocalLogs()
    }

    private func fetchFromOAuthAPI(token: String) async -> ServiceUsageData? {
        guard let loadUrl = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist") else { return nil }
        var loadReq = URLRequest(url: loadUrl)
        loadReq.httpMethod = "POST"
        loadReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        loadReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        loadReq.httpBody = try? JSONSerialization.data(withJSONObject: [
            "metadata": ["ideType": "GEMINI_CLI", "pluginType": "GEMINI"]
        ])
        loadReq.timeoutInterval = 10

        do {
            let (loadData, loadResp) = try await URLSession.shared.data(for: loadReq)
            guard let loadHttp = loadResp as? HTTPURLResponse, loadHttp.statusCode == 200,
                  let loadJson = try? JSONSerialization.jsonObject(with: loadData) as? [String: Any] else { return nil }

            let projectId: String?
            if let proj = loadJson["cloudaicompanionProject"] {
                if let s = proj as? String { projectId = s }
                else if let d = proj as? [String: Any] { projectId = d["id"] as? String ?? d["projectId"] as? String }
                else { projectId = nil }
            } else { projectId = nil }

            guard let quotaUrl = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota") else { return nil }
            var quotaReq = URLRequest(url: quotaUrl)
            quotaReq.httpMethod = "POST"
            quotaReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            quotaReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var quotaBody: [String: Any] = [:]
            if let pid = projectId { quotaBody["project"] = pid }
            quotaReq.httpBody = try? JSONSerialization.data(withJSONObject: quotaBody)
            quotaReq.timeoutInterval = 10

            let (quotaData, quotaResp) = try await URLSession.shared.data(for: quotaReq)
            guard let quotaHttp = quotaResp as? HTTPURLResponse, quotaHttp.statusCode == 200,
                  let quotaJson = try? JSONSerialization.jsonObject(with: quotaData) as? [String: Any],
                  let buckets = quotaJson["buckets"] as? [[String: Any]] else { return nil }

            var categoryBest: [String: (remaining: Double, resetTime: String?)] = [:]
            for bucket in buckets {
                let modelId = bucket["modelId"] as? String ?? "unknown"
                let category: String
                if modelId.contains("flash-lite") { category = "Flash Lite" }
                else if modelId.contains("flash") { category = "Flash" }
                else if modelId.contains("pro") { category = "Pro" }
                else { category = modelId }

                let remaining = min(1.0, max(0.0, bucket["remainingFraction"] as? Double ?? 1.0))
                let resetTime = bucket["resetTime"] as? String

                if let existing = categoryBest[category] {
                    if remaining < existing.remaining {
                        categoryBest[category] = (remaining, resetTime ?? existing.resetTime)
                    }
                } else {
                    categoryBest[category] = (remaining, resetTime)
                }
            }

            guard !categoryBest.isEmpty else { return nil }

            let sortOrder = ["Pro": 0, "Flash": 1, "Flash Lite": 2]
            let sorted = categoryBest.sorted { (sortOrder[$0.key] ?? 3) < (sortOrder[$1.key] ?? 3) }

            let isoFormatter = ISO8601DateFormatter()
            let first = sorted[0]
            let utilization = (1.0 - first.value.remaining) * 100
            let resetDate = first.value.resetTime.flatMap { isoFormatter.date(from: $0) }
            let primary = UsageMetric(used: utilization, total: 100, unit: .percent, resetTime: resetDate)

            var secondary: UsageMetric? = nil
            if sorted.count > 1 {
                let second = sorted[1]
                let util2 = (1.0 - second.value.remaining) * 100
                let reset2 = second.value.resetTime.flatMap { isoFormatter.date(from: $0) }
                secondary = UsageMetric(used: util2, total: 100, unit: .percent, resetTime: reset2)
            }

            return ServiceUsageData(service: .gemini, primaryUsage: primary, secondaryUsage: secondary,
                                    planName: "OAuth", isAvailable: true)
        } catch {
            log.warning("Gemini OAuth fetch: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchFromLocalLogs() -> ServiceUsageData? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: logsDir.path) else { return nil }

        let cutoff = Date().addingTimeInterval(-48 * 3600)
        guard let enumerator = fm.enumerator(at: logsDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let todayStart = calendar.startOfDay(for: Date())
        var todayCount: Double = 0

        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.lastPathComponent == "logs.json" else { continue }
            guard let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  modDate > cutoff else { continue }

            guard let data = try? Data(contentsOf: fileURL),
                  let records = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { continue }

            let isoFormatter = ISO8601DateFormatter()
            for record in records {
                guard let type = record["type"] as? String, type == "user",
                      let message = record["message"] as? String else { continue }
                let trimmed = message.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("/") { continue }
                let lower = trimmed.lowercased()
                if lower == "exit" || lower == "quit" { continue }

                if let ts = record["timestamp"] as? String, let date = isoFormatter.date(from: ts) {
                    if date >= todayStart { todayCount += 1 }
                }
            }
        }

        guard todayCount > 0 else { return nil }

        let dailyLimit: Double = 1000
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!

        let primary = UsageMetric(used: todayCount, total: dailyLimit, unit: .requests, resetTime: tomorrowStart)

        return ServiceUsageData(
            service: .gemini, primaryUsage: primary, secondaryUsage: nil,
            planName: nil, isAvailable: true
        )
    }
}

// MARK: - GitHub Copilot Provider

struct CopilotUsageProvider: UsageProvider {
    let service = AIService.copilot

    func isConfigured() -> Bool {
        KeychainHelper.readGHToken() != nil
    }

    func fetchUsage() async -> ServiceUsageData? {
        guard let token = KeychainHelper.readGHToken() else { return nil }
        guard let url = URL(string: "https://api.github.com/copilot_internal/user") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OhMyIsland", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            let plan = json["copilot_plan"] as? String
            guard let snapshots = json["quota_snapshots"] as? [[String: Any]] else { return nil }

            let premiumSnapshot = snapshots.first { ($0["quota_id"] as? String) == "premium_requests" }
            guard let snapshot = premiumSnapshot else { return nil }

            let unlimited = snapshot["unlimited"] as? Bool ?? false
            let used: Double
            let total: Double

            if unlimited {
                used = 0; total = 0
            } else {
                let entitlement = Double(snapshot["entitlement"] as? Int ?? 0)
                let remaining = Double(snapshot["remaining"] as? Int ?? 0)
                used = max(0, min(entitlement, entitlement - remaining))
                total = entitlement
            }

            let resetTime = firstOfNextMonthUTC()
            let primary = UsageMetric(used: used, total: total, unit: .requests, resetTime: resetTime)

            return ServiceUsageData(
                service: .copilot, primaryUsage: primary, secondaryUsage: nil,
                planName: plan, isAvailable: true
            )
        } catch {
            log.warning("Copilot fetch: \(error.localizedDescription)")
            return nil
        }
    }

    private func firstOfNextMonthUTC() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date()
        var components = calendar.dateComponents([.year, .month], from: now)
        if let month = components.month {
            if month == 12 {
                components.year = (components.year ?? 2026) + 1
                components.month = 1
            } else {
                components.month = month + 1
            }
        }
        components.day = 1
        components.hour = 0; components.minute = 0; components.second = 0
        return calendar.date(from: components) ?? now.addingTimeInterval(30 * 86400)
    }
}

// MARK: - Cursor Provider

struct CursorUsageProvider: UsageProvider {
    let service = AIService.cursor

    private var dbPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb").path
    }

    func isConfigured() -> Bool {
        FileManager.default.fileExists(atPath: dbPath)
    }

    func fetchUsage() async -> ServiceUsageData? {
        guard let jwt = readValueFromSQLite(key: "cursorAuth/accessToken") else { return nil }
        let userId = readValueFromSQLite(key: "cursorAuth/userId") ?? extractSub(from: jwt) ?? ""
        guard !userId.isEmpty else { return nil }
        let membershipType = readValueFromSQLite(key: "cursorAuth/stripeMembershipType")

        guard let url = URL(string: "https://cursor.com/api/usage-summary") else { return nil }

        let encodedUid = userId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? userId
        let encodedJwt = jwt.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? jwt
        let cookieValue = "\(encodedUid)%3A%3A\(encodedJwt)"

        var request = URLRequest(url: url)
        request.setValue("WorkosCursorSessionToken=\(cookieValue)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            let billingEnd = json["billingCycleEnd"] as? String
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let resetTime = billingEnd.flatMap { isoFormatter.date(from: $0) }
            let planName = json["membershipType"] as? String ?? membershipType

            guard let individual = json["individualUsage"] as? [String: Any],
                  let plan = individual["plan"] as? [String: Any],
                  plan["enabled"] as? Bool == true else { return nil }

            let used = plan["used"] as? Double ?? 0
            let limit = plan["limit"] as? Double ?? 500
            let autoPercent = plan["autoPercentUsed"] as? Double ?? 0
            let apiPercent = plan["apiPercentUsed"] as? Double ?? 0
            let totalPercent = plan["totalPercentUsed"] as? Double ?? 0

            let primary = UsageMetric(used: totalPercent, total: 100, unit: .percent, resetTime: resetTime)
            let secondary = UsageMetric(used: used, total: limit, unit: .requests, resetTime: resetTime)

            return ServiceUsageData(
                service: .cursor, primaryUsage: primary, secondaryUsage: secondary,
                planName: planName?.capitalized, isAvailable: true
            )
        } catch {
            log.warning("Cursor fetch: \(error.localizedDescription)")
            return nil
        }
    }

    private func readValueFromSQLite(key: String) -> String? {
        guard FileManager.default.fileExists(atPath: dbPath) else { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            log.warning("Cursor SQLite: cannot open \(dbPath)")
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let query = "SELECT value FROM ItemTable WHERE key = ?1 LIMIT 1;"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            log.warning("Cursor SQLite: prepare failed")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        guard let cStr = sqlite3_column_text(stmt, 0) else { return nil }
        let value = String(cString: cStr).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func extractSub(from jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        return sub
    }
}

// MARK: - Z.ai Provider

struct ZaiUsageProvider: UsageProvider {
    let service = AIService.zai

    func isConfigured() -> Bool {
        readApiKey() != nil
    }

    func fetchUsage() async -> ServiceUsageData? {
        guard let apiKey = readApiKey() else { return nil }
        guard let url = URL(string: "https://api.z.ai/api/monitor/usage/quota/limit") else { return nil }

        for bearerPrefix in ["Bearer ", ""] {
            var request = URLRequest(url: url)
            request.setValue("\(bearerPrefix)\(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
            request.timeoutInterval = 10

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { continue }
                if httpResponse.statusCode == 401 && bearerPrefix == "Bearer " { continue }
                guard httpResponse.statusCode == 200 else { return nil }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let quotaData = json["data"] as? [String: Any],
                      let limits = quotaData["limits"] as? [[String: Any]] else { return nil }

                let planName = quotaData["level"] as? String

                var primaryMetric: UsageMetric?
                var secondaryMetric: UsageMetric?

                for limit in limits {
                    guard let type = limit["type"] as? String else { continue }
                    let nextResetMs = limit["nextResetTime"] as? Double
                    let resetDate = nextResetMs.map { Date(timeIntervalSince1970: $0 / 1000) }

                    if type == "TOKENS_LIMIT" {
                        let pct = limit["percentage"] as? Double ?? 0
                        primaryMetric = UsageMetric(used: pct, total: 100, unit: .percent, resetTime: resetDate)
                    } else if type == "TIME_LIMIT" {
                        let currentValue = limit["currentValue"] as? Double ?? 0
                        let total = limit["usage"] as? Double ?? 0
                        secondaryMetric = UsageMetric(used: currentValue, total: total, unit: .requests, resetTime: resetDate)
                    }
                }

                return ServiceUsageData(
                    service: .zai, primaryUsage: primaryMetric, secondaryUsage: secondaryMetric,
                    planName: planName, isAvailable: true
                )
            } catch {
                log.warning("Z.ai fetch: \(error.localizedDescription)")
            }
        }
        return nil
    }

    private func readApiKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.codeisland.apikeys",
            kSecAttrAccount as String: "zai",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else { return nil }
        return key
    }
}
