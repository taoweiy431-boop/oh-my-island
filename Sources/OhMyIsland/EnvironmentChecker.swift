import Foundation
import os.log

private let log = Logger(subsystem: "com.codeisland", category: "EnvironmentChecker")

// MARK: - Models

enum RiskLevel: String, Comparable, CaseIterable {
    case safe = "安全"
    case info = "信息"
    case low = "低"
    case medium = "中"
    case high = "高"
    case critical = "极高"

    var color: String {
        switch self {
        case .safe: return "green"
        case .info: return "blue"
        case .low: return "gray"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .info: return "info.circle.fill"
        case .low: return "exclamationmark.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .safe: return 0
        case .info: return 1
        case .low: return 2
        case .medium: return 3
        case .high: return 4
        case .critical: return 5
        }
    }

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

struct CheckResult: Identifiable {
    let id = UUID()
    let category: String
    let name: String
    let risk: RiskLevel
    let detail: String
    let suggestion: String?
}

struct EnvironmentReport {
    let results: [CheckResult]
    let timestamp: Date

    var overallRisk: RiskLevel {
        results.map(\.risk).max() ?? .safe
    }

    var highRiskCount: Int {
        results.filter { $0.risk >= .high }.count
    }

    var safeCount: Int {
        results.filter { $0.risk <= .info }.count
    }

    var grouped: [(String, [CheckResult])] {
        let categories = ["身份", "网络", "环境", "遥测", "凭据", "客户端"]
        return categories.compactMap { cat in
            let items = results.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }
}

// MARK: - Checker

@MainActor
final class EnvironmentChecker: ObservableObject {
    static let shared = EnvironmentChecker()
    @Published var report: EnvironmentReport?
    @Published var isChecking = false

    func runAllChecks() async {
        isChecking = true
        var results: [CheckResult] = []

        let localChecks = runLocalChecks()
        results.append(contentsOf: localChecks)

        let networkChecks = await runNetworkChecks()
        results.append(contentsOf: networkChecks)

        report = EnvironmentReport(results: results, timestamp: Date())
        isChecking = false
    }

    // MARK: - Local Checks (synchronous)

    private func runLocalChecks() -> [CheckResult] {
        var results: [CheckResult] = []
        results.append(contentsOf: checkIdentity())
        results.append(contentsOf: checkEnvironment())
        results.append(contentsOf: checkTelemetry())
        results.append(contentsOf: checkCredentials())
        results.append(contentsOf: checkClient())
        return results
    }

    // MARK: - Identity

    private func checkIdentity() -> [CheckResult] {
        var results: [CheckResult] = []
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let configPath = "\(home)/.claude/config.json"
        let settingsPath = "\(home)/.claude/settings.json"

        // Read config.json
        var configJson: [String: Any] = [:]
        if let data = fm.contents(atPath: configPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            configJson = json
        }

        // Read settings.json for proxy/env info
        var settingsJson: [String: Any] = [:]
        if let data = fm.contents(atPath: settingsPath),
           let str = String(data: data, encoding: .utf8) {
            let stripped = ConfigInstaller.stripJSONComments(str)
            if let strippedData = stripped.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: strippedData) as? [String: Any] {
                settingsJson = json
            }
        }

        // Proxy detection
        let envSettings = settingsJson["env"] as? [String: String] ?? [:]
        let envBaseUrl = envSettings["ANTHROPIC_BASE_URL"] ?? ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"]
        let isProxy = envBaseUrl != nil && envBaseUrl != "https://api.anthropic.com"

        if isProxy {
            results.append(CheckResult(
                category: "身份", name: "API 代理",
                risk: .info,
                detail: "使用代理: \(envBaseUrl ?? "unknown")",
                suggestion: "通过代理访问 API 时，DeviceID 等官方身份标识可能不会生成。代理本身可能会记录你的使用数据。"
            ))
        }

        // DeviceID — try multiple possible field names
        let deviceIdKeys = ["userID", "deviceId", "device_id", "userId"]
        var foundDeviceId: String?
        for key in deviceIdKeys {
            if let val = configJson[key] as? String, !val.isEmpty {
                foundDeviceId = val
                break
            }
        }

        if let deviceId = foundDeviceId {
            results.append(CheckResult(
                category: "身份", name: "DeviceID",
                risk: .medium,
                detail: "已生成: \(deviceId.prefix(8))…\(deviceId.suffix(4))",
                suggestion: "256位永久设备标识符，Anthropic 用它关联你所有活动。删除 ~/.claude/config.json 中的对应字段可重置。"
            ))
        } else if isProxy {
            results.append(CheckResult(
                category: "身份", name: "DeviceID",
                risk: .safe,
                detail: "未生成 (使用代理模式)",
                suggestion: "代理模式下通常不会生成官方 DeviceID，降低了设备追踪风险。"
            ))
        } else {
            results.append(CheckResult(
                category: "身份", name: "DeviceID",
                risk: .safe,
                detail: "未检测到 DeviceID",
                suggestion: nil
            ))
        }

        // AccountUUID
        let accountKeys = ["accountUuid", "account_uuid", "accountId"]
        for key in accountKeys {
            if let val = configJson[key] as? String, !val.isEmpty {
                results.append(CheckResult(
                    category: "身份", name: "账号绑定",
                    risk: .info,
                    detail: "AccountUUID: \(val.prefix(8))…",
                    suggestion: "账号 UUID 关联你的订阅。同一 DeviceID 频繁切换账号会触发共享检测。"
                ))
                break
            }
        }

        // Organization
        if let orgUuid = configJson["organizationUuid"] as? String, !orgUuid.isEmpty {
            results.append(CheckResult(
                category: "身份", name: "组织绑定",
                risk: .info,
                detail: "OrganizationUUID: \(orgUuid.prefix(8))…",
                suggestion: "组织级策略可远程控制你的客户端行为。"
            ))
        }

        // API Key type
        if let apiKey = configJson["primaryApiKey"] as? String, !apiKey.isEmpty {
            let keyType = apiKey.hasPrefix("sk-ant-") ? "Anthropic API Key" : "自定义/代理 Key"
            results.append(CheckResult(
                category: "身份", name: "API Key",
                risk: apiKey.hasPrefix("sk-ant-") ? .info : .safe,
                detail: "\(keyType): \(apiKey.prefix(6))…",
                suggestion: apiKey.hasPrefix("sk-ant-") ? "使用官方 API Key 时用量会被直接关联到你的账号。" : nil
            ))
        }

        // Git user.email exposure
        if let email = runShellCommand("git config --global user.email"), !email.isEmpty {
            results.append(CheckResult(
                category: "身份", name: "Git Email",
                risk: .info,
                detail: email,
                suggestion: "Claude Code 可通过 git config user.email 获取你的邮箱地址。"
            ))
        }

        return results
    }

    // MARK: - Environment

    private func checkEnvironment() -> [CheckResult] {
        var results: [CheckResult] = []
        let env = ProcessInfo.processInfo.environment

        // CI/CD detection
        let ciVars: [(String, String)] = [
            ("GITHUB_ACTIONS", "GitHub Actions"),
            ("GITLAB_CI", "GitLab CI"),
            ("CIRCLECI", "CircleCI"),
            ("BUILDKITE", "Buildkite"),
            ("JENKINS_URL", "Jenkins"),
            ("CI", "Generic CI"),
            ("CONTINUOUS_INTEGRATION", "Generic CI"),
        ]
        var detectedCI: [String] = []
        for (key, name) in ciVars {
            if env[key] != nil { detectedCI.append(name) }
        }
        if !detectedCI.isEmpty {
            results.append(CheckResult(
                category: "环境", name: "CI/CD 环境",
                risk: .high,
                detail: "检测到: \(detectedCI.joined(separator: ", "))",
                suggestion: "在 CI 环境中使用 Claude Code 会被标记。建议使用 API Key 而非 OAuth。"
            ))
        } else {
            results.append(CheckResult(
                category: "环境", name: "CI/CD 环境",
                risk: .safe,
                detail: "未检测到 CI/CD 环境",
                suggestion: nil
            ))
        }

        // Cloud dev environments
        let cloudVars: [(String, String)] = [
            ("CODESPACES", "GitHub Codespaces"),
            ("GITPOD_WORKSPACE_ID", "Gitpod"),
            ("REPL_ID", "Replit"),
            ("VERCEL", "Vercel"),
            ("RAILWAY_ENVIRONMENT", "Railway"),
        ]
        var detectedCloud: [String] = []
        for (key, name) in cloudVars {
            if env[key] != nil { detectedCloud.append(name) }
        }
        if !detectedCloud.isEmpty {
            results.append(CheckResult(
                category: "环境", name: "云开发环境",
                risk: .medium,
                detail: "检测到: \(detectedCloud.joined(separator: ", "))",
                suggestion: "云开发环境的 IP 可能被识别为数据中心地址。"
            ))
        }

        // Docker / Container
        let isDocker = FileManager.default.fileExists(atPath: "/.dockerenv")
        let isK8s = env["KUBERNETES_SERVICE_HOST"] != nil
        if isDocker || isK8s {
            results.append(CheckResult(
                category: "环境", name: "容器环境",
                risk: .medium,
                detail: isDocker ? "运行在 Docker 中" : "运行在 Kubernetes 中",
                suggestion: "容器环境会被上报到遥测数据中。"
            ))
        } else {
            results.append(CheckResult(
                category: "环境", name: "容器环境",
                risk: .safe,
                detail: "非容器环境",
                suggestion: nil
            ))
        }

        // SSH
        let isSSH = env["SSH_CONNECTION"] != nil || env["SSH_TTY"] != nil
        if isSSH {
            results.append(CheckResult(
                category: "环境", name: "SSH 远程",
                risk: .low,
                detail: "通过 SSH 连接",
                suggestion: "SSH 远程使用会被环境指纹采集。"
            ))
        }

        // WSL
        if env["WSL_DISTRO_NAME"] != nil {
            results.append(CheckResult(
                category: "环境", name: "WSL 环境",
                risk: .low,
                detail: "WSL: \(env["WSL_DISTRO_NAME"] ?? "unknown")",
                suggestion: "WSL 环境信息会被上报。"
            ))
        }

        // Terminal / IDE detection
        var detectedIDE: [String] = []
        if env["CURSOR_TRACE_ID"] != nil { detectedIDE.append("Cursor") }
        if env.keys.contains(where: { $0.hasPrefix("VSCODE_") }) { detectedIDE.append("VS Code") }
        if env["TERMINAL_EMULATOR"] == "JetBrains-JediTerm" { detectedIDE.append("JetBrains") }
        if env["TMUX"] != nil { detectedIDE.append("tmux") }
        if !detectedIDE.isEmpty {
            results.append(CheckResult(
                category: "环境", name: "终端/IDE",
                risk: .info,
                detail: detectedIDE.joined(separator: ", "),
                suggestion: "终端和 IDE 信息会被环境指纹采集。"
            ))
        }

        // AWS / GCP / Azure
        let cloudPlatformVars: [(String, String)] = [
            ("AWS_LAMBDA_FUNCTION_NAME", "AWS Lambda"),
            ("AWS_EXECUTION_ENV", "AWS"),
            ("ECS_CONTAINER_METADATA_URI", "AWS ECS"),
            ("K_SERVICE", "GCP Cloud Run"),
            ("AZURE_FUNCTIONS_ENVIRONMENT", "Azure Functions"),
            ("WEBSITE_SITE_NAME", "Azure App Service"),
        ]
        var detectedPlatforms: [String] = []
        for (key, name) in cloudPlatformVars {
            if env[key] != nil { detectedPlatforms.append(name) }
        }
        if !detectedPlatforms.isEmpty {
            results.append(CheckResult(
                category: "环境", name: "云平台",
                risk: .high,
                detail: "检测到: \(detectedPlatforms.joined(separator: ", "))",
                suggestion: "在云平台上运行 Claude Code 会被视为自动化使用。"
            ))
        }

        // OS info
        let platform = ProcessInfo.processInfo.operatingSystemVersionString
        results.append(CheckResult(
            category: "环境", name: "操作系统",
            risk: .info,
            detail: "macOS \(platform)",
            suggestion: "系统信息会作为环境指纹上报。"
        ))

        // CPU architecture fingerprint
        var sysInfo = utsname()
        uname(&sysInfo)
        let arch = withUnsafePointer(to: &sysInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
        results.append(CheckResult(
            category: "环境", name: "CPU 架构",
            risk: .info,
            detail: arch,
            suggestion: "架构信息是 cc-gateway 归一化的 40+ 维度之一。不同架构在 Anthropic 端可区分设备。"
        ))

        // Physical RAM fingerprint (constrainedMemory)
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        let ramGB = Double(totalRAM) / (1024 * 1024 * 1024)
        results.append(CheckResult(
            category: "环境", name: "物理内存",
            risk: .info,
            detail: String(format: "%.0f GB", ramGB),
            suggestion: "物理内存 (constrainedMemory) 会被上报。cc-gateway 将其归一化以防止硬件差异泄露。"
        ))

        // Hostname fingerprint
        let hostname = ProcessInfo.processInfo.hostName
        results.append(CheckResult(
            category: "环境", name: "主机名",
            risk: hostname.lowercased().contains("mac") || hostname.contains(".local") ? .info : .low,
            detail: hostname,
            suggestion: "主机名可能通过 working directory 或 system prompt 的 <env> block 间接泄露。含有个人信息的主机名增加识别风险。"
        ))

        // Installed runtimes / package managers — software fingerprint
        var runtimes: [(String, String)] = []
        if let nodeV = runShellCommand("node --version 2>/dev/null") { runtimes.append(("Node.js", nodeV)) }
        if let bunV  = runShellCommand("bun  --version 2>/dev/null") { runtimes.append(("Bun", bunV)) }
        if let pyV   = runShellCommand("python3 --version 2>/dev/null") { runtimes.append(("Python", pyV)) }
        if let goV   = runShellCommand("go version 2>/dev/null") { runtimes.append(("Go", goV)) }
        if let rustV = runShellCommand("rustc --version 2>/dev/null") { runtimes.append(("Rust", rustV)) }
        if !runtimes.isEmpty {
            let detail = runtimes.map { "\($0.0) \($0.1)" }.joined(separator: ", ")
            results.append(CheckResult(
                category: "环境", name: "运行时/包管理器",
                risk: .info,
                detail: detail,
                suggestion: "已安装的运行时和版本是 40+ 环境维度的一部分。这些版本的精确组合可作为软指纹唯一识别设备。"
            ))
        }

        return results
    }

    // MARK: - Telemetry

    private func checkTelemetry() -> [CheckResult] {
        var results: [CheckResult] = []
        let env = ProcessInfo.processInfo.environment
        let fm = FileManager.default
        let home = NSHomeDirectory()

        // Telemetry disabled?
        let disableTelemetry = env["DISABLE_TELEMETRY"] == "1"
        let disableNonessential = env["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] == "1"

        // Also check settings.json for these env vars
        var settingsDisableTelemetry = false
        var settingsDisableNonessential = false
        let settingsPath = "\(home)/.claude/settings.json"
        if let data = fm.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let envSettings = json["env"] as? [String: String] {
            settingsDisableTelemetry = envSettings["DISABLE_TELEMETRY"] == "1"
            settingsDisableNonessential = envSettings["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] == "1"
        }

        let effectiveDisable = disableTelemetry || settingsDisableTelemetry
        let effectiveNonessential = disableNonessential || settingsDisableNonessential

        if effectiveDisable && effectiveNonessential {
            results.append(CheckResult(
                category: "遥测", name: "遥测状态",
                risk: .safe,
                detail: "遥测已禁用 + 非必要流量已禁用",
                suggestion: "Datadog、1P 事件、GrowthBook 等均已禁用。仅保留核心 API 通信。"
            ))
        } else if effectiveDisable {
            results.append(CheckResult(
                category: "遥测", name: "遥测状态",
                risk: .info,
                detail: "DISABLE_TELEMETRY=1 (Datadog + 1P 事件已禁用)",
                suggestion: "建议同时设置 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 禁用 GrowthBook 和更新检查。"
            ))
        } else if effectiveNonessential {
            results.append(CheckResult(
                category: "遥测", name: "遥测状态",
                risk: .info,
                detail: "非必要流量已禁用",
                suggestion: "建议同时设置 DISABLE_TELEMETRY=1 禁用 Datadog 事件上报。"
            ))
        } else {
            results.append(CheckResult(
                category: "遥测", name: "遥测状态",
                risk: .medium,
                detail: "遥测完全开启 (640+ 事件类型上报中)",
                suggestion: "建议在 settings.json 的 env 中设置 DISABLE_TELEMETRY=1 和 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1。"
            ))
        }

        // Bedrock/Vertex protection
        let useBedrock = env["CLAUDE_CODE_USE_BEDROCK"] == "1"
        let useVertex = env["CLAUDE_CODE_USE_VERTEX"] == "1"
        if useBedrock || useVertex {
            let provider = useBedrock ? "AWS Bedrock" : "GCP Vertex"
            results.append(CheckResult(
                category: "遥测", name: "第三方提供商",
                risk: .safe,
                detail: "使用 \(provider) — 所有分析自动禁用",
                suggestion: "这是最安全的使用方式。"
            ))
        }

        // Telemetry cache backlog
        let telemetryDir = "\(home)/.claude/telemetry"
        if fm.fileExists(atPath: telemetryDir) {
            var totalSize: UInt64 = 0
            var fileCount = 0
            if let files = try? fm.contentsOfDirectory(atPath: telemetryDir) {
                fileCount = files.count
                for file in files {
                    if let attrs = try? fm.attributesOfItem(atPath: "\(telemetryDir)/\(file)"),
                       let size = attrs[.size] as? UInt64 {
                        totalSize += size
                    }
                }
            }
            if fileCount > 0 {
                let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
                results.append(CheckResult(
                    category: "遥测", name: "遥测缓存积压",
                    risk: totalSize > 1_000_000 ? .medium : .low,
                    detail: "\(fileCount) 个文件, \(sizeStr)",
                    suggestion: "失败的遥测事件缓存在此目录，下次启动时会自动重试发送（最多8次）。建议定期清理。"
                ))
            }
        }

        // GrowthBook tracking
        if !effectiveNonessential && !useBedrock && !useVertex {
            results.append(CheckResult(
                category: "遥测", name: "GrowthBook 功能控制",
                risk: .medium,
                detail: "DeviceID、订阅类型、邮箱等发送给 GrowthBook (每 20 分钟)",
                suggestion: "Anthropic 可据此针对特定用户禁用功能或调整限制。设置 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 禁用。"
            ))
        }

        // Datadog reporting
        if !effectiveDisable && !useBedrock && !useVertex {
            results.append(CheckResult(
                category: "遥测", name: "Datadog 事件上报",
                risk: .medium,
                detail: "64 种事件每 15 秒上报到 datadoghq.com",
                suggestion: "包含 userBucket、subscriptionType、model、toolName 等标签。设置 DISABLE_TELEMETRY=1 禁用。"
            ))
        }

        // Billing header / attribution header
        let attrHeaderOff = env["CLAUDE_CODE_ATTRIBUTION_HEADER"] == "false"
        var settingsAttrOff = false
        if let data = fm.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let envS = json["env"] as? [String: String] {
            settingsAttrOff = envS["CLAUDE_CODE_ATTRIBUTION_HEADER"] == "false"
        }
        let effectiveAttrOff = attrHeaderOff || settingsAttrOff
        if effectiveAttrOff {
            results.append(CheckResult(
                category: "遥测", name: "Billing Header",
                risk: .safe,
                detail: "x-anthropic-billing-header 已禁用",
                suggestion: "消除了会话指纹哈希泄露，同时启用跨会话 prompt cache 共享（~85% 系统 prompt 成本节省）。"
            ))
        } else if !useBedrock && !useVertex {
            results.append(CheckResult(
                category: "遥测", name: "Billing Header",
                risk: .medium,
                detail: "x-anthropic-billing-header 活跃 — 每个请求携带会话指纹哈希",
                suggestion: "此 header 包含设备/会话特征的哈希值，可关联不同请求。设置 CLAUDE_CODE_ATTRIBUTION_HEADER=false 禁用，还能启用跨会话 prompt cache 共享。"
            ))
        }

        // baseUrl leak in telemetry
        var settingsBase: String?
        if let data = fm.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let envS = json["env"] as? [String: String] {
            settingsBase = envS["ANTHROPIC_BASE_URL"]
        }
        let effectiveBase = env["ANTHROPIC_BASE_URL"] ?? settingsBase
        let isUsingProxy = effectiveBase != nil && effectiveBase != "https://api.anthropic.com"

        if isUsingProxy && !effectiveDisable {
            results.append(CheckResult(
                category: "遥测", name: "代理地址泄露",
                risk: .high,
                detail: "ANTHROPIC_BASE_URL=\(effectiveBase ?? "?") 可能在遥测中暴露",
                suggestion: "遥测事件中的 baseUrl 字段会暴露你使用代理的事实。cc-gateway 会剥离此字段。务必确保 DISABLE_TELEMETRY=1 已设置。"
            ))
        } else if isUsingProxy && effectiveDisable {
            results.append(CheckResult(
                category: "遥测", name: "代理地址泄露",
                risk: .safe,
                detail: "使用代理但遥测已禁用 — baseUrl 不会泄露",
                suggestion: nil
            ))
        }

        // System prompt <env> block exposure
        results.append(CheckResult(
            category: "遥测", name: "System Prompt <env> 暴露",
            risk: .info,
            detail: "每个 prompt 注入 Platform/Shell/OS/CWD",
            suggestion: "Claude Code 在每个系统 prompt 中注入 <env> block，包含平台、Shell 类型、OS 版本和工作目录。cc-gateway 会将这些重写为规范值。即使禁用遥测，这些信息仍会发送到 API。"
        ))

        // Process heap/RSS fingerprint
        results.append(CheckResult(
            category: "遥测", name: "进程内存指纹",
            risk: .info,
            detail: "heapTotal/heapUsed/rss 随每个 API 请求上报",
            suggestion: "进程内存数据可用于区分不同硬件。cc-gateway 将其随机化到合理范围内。"
        ))

        return results
    }

    // MARK: - Credentials

    private func checkCredentials() -> [CheckResult] {
        var results: [CheckResult] = []
        let fm = FileManager.default
        let home = NSHomeDirectory()

        // .credentials.json (Keychain fallback)
        let credPath = "\(home)/.claude/.credentials.json"
        if fm.fileExists(atPath: credPath) {
            results.append(CheckResult(
                category: "凭据", name: "明文凭据",
                risk: .medium,
                detail: "检测到 ~/.claude/.credentials.json",
                suggestion: "Keychain 不可用时会降级为明文文件存储凭据。确保 Keychain 可用以提升安全性。"
            ))
        } else {
            results.append(CheckResult(
                category: "凭据", name: "凭据存储",
                risk: .safe,
                detail: "使用 Keychain 存储凭据",
                suggestion: nil
            ))
        }

        // Conversation history exposure
        let projectsDir = "\(home)/.claude/projects"
        if fm.fileExists(atPath: projectsDir) {
            var sessionCount = 0
            if let dirs = try? fm.contentsOfDirectory(atPath: projectsDir) {
                for dir in dirs {
                    let dirPath = "\(projectsDir)/\(dir)"
                    if let files = try? fm.contentsOfDirectory(atPath: dirPath) {
                        sessionCount += files.filter { $0.hasSuffix(".jsonl") }.count
                    }
                }
            }
            if sessionCount > 100 {
                results.append(CheckResult(
                    category: "凭据", name: "对话历史",
                    risk: .low,
                    detail: "\(sessionCount) 个会话记录",
                    suggestion: "完整对话历史存储在 ~/.claude/projects/。建议定期清理敏感会话。"
                ))
            }
        }

        return results
    }

    // MARK: - Client

    private func checkClient() -> [CheckResult] {
        var results: [CheckResult] = []

        // Claude Code version
        if let version = runShellCommand("claude --version 2>/dev/null") {
            let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
            results.append(CheckResult(
                category: "客户端", name: "Claude Code 版本",
                risk: .info,
                detail: trimmed,
                suggestion: "版本信息会通过 x-anthropic-billing-header 上报。长期不升级可能触发版本强制升级。"
            ))
        }

        // Codex version
        if let version = runShellCommand("codex --version 2>/dev/null") {
            let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
            results.append(CheckResult(
                category: "客户端", name: "Codex 版本",
                risk: .info,
                detail: trimmed,
                suggestion: nil
            ))
        }

        // Interactive mode
        let isTTY = isatty(STDIN_FILENO) != 0
        if !isTTY {
            results.append(CheckResult(
                category: "客户端", name: "交互模式",
                risk: .medium,
                detail: "非交互模式 (is_interactive: false)",
                suggestion: "非交互式调用 + SDK 入口 + 高频调用 = 自动化滥用嫌疑。"
            ))
        }

        return results
    }

    // MARK: - Network Checks (async)

    private func runNetworkChecks() async -> [CheckResult] {
        async let ipResults = fetchIPInfo()
        async let banResults = checkBanStatus()
        async let flagResults = checkDeviceIDFlagging()

        var results: [CheckResult] = []
        results.append(contentsOf: await ipResults)
        results.append(contentsOf: await banResults)
        results.append(contentsOf: await flagResults)
        return results
    }

    /// Probe whether the local DeviceID has been flagged by Anthropic.
    /// Sends a minimal Messages API request carrying the device fingerprint
    /// and OAuth token; interprets the HTTP status / error body.
    private func checkDeviceIDFlagging() async -> [CheckResult] {
        await withCheckedContinuation { continuation in
            var results: [CheckResult] = []
            let home = NSHomeDirectory()
            let configPath = "\(home)/.claude/config.json"

            // 1. Read deviceID
            var deviceId: String?
            if let data = FileManager.default.contents(atPath: configPath),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for key in ["userID", "deviceId", "device_id", "userId"] {
                    if let val = json[key] as? String, !val.isEmpty {
                        deviceId = val
                        break
                    }
                }
            }

            guard let deviceId = deviceId else {
                results.append(CheckResult(
                    category: "身份", name: "DeviceID 标记检测",
                    risk: .info,
                    detail: "未找到 DeviceID，跳过检测",
                    suggestion: "没有 DeviceID 意味着设备追踪风险较低。"
                ))
                continuation.resume(returning: results)
                return
            }

            // 2. Get OAuth token
            guard let token = KeychainHelper.readClaudeOAuthToken() else {
                results.append(CheckResult(
                    category: "身份", name: "DeviceID 标记检测",
                    risk: .info,
                    detail: "无 OAuth token，无法验证设备状态",
                    suggestion: "需要 Claude Pro 的 OAuth 凭据才能检测 DeviceID 是否被标记。API Key 用户不受 DeviceID 限制。"
                ))
                continuation.resume(returning: results)
                return
            }

            // 3. Minimal Messages API probe — 1-token request with device fingerprint
            guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
                continuation.resume(returning: results)
                return
            }

            var request = URLRequest(url: url, timeoutInterval: 15)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("claude-code/1.0.0", forHTTPHeaderField: "User-Agent")
            request.setValue(deviceId, forHTTPHeaderField: "x-machine-id")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

            let body: [String: Any] = [
                "model": "claude-sonnet-4-20250514",
                "max_tokens": 1,
                "messages": [["role": "user", "content": "ping"]]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 15
            let session = URLSession(configuration: config)

            session.dataTask(with: request) { data, response, error in
                if let error = error {
                    results.append(CheckResult(
                        category: "身份", name: "DeviceID 标记检测",
                        risk: .info,
                        detail: "网络错误: \(error.localizedDescription)",
                        suggestion: nil
                    ))
                    continuation.resume(returning: results)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(returning: results)
                    return
                }

                let bodyString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                let bodyJson = data.flatMap {
                    try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
                } ?? [:]
                let errorType = (bodyJson["error"] as? [String: Any])?["type"] as? String ?? ""
                let errorMessage = (bodyJson["error"] as? [String: Any])?["message"] as? String ?? bodyString

                switch httpResponse.statusCode {
                case 200:
                    results.append(CheckResult(
                        category: "身份", name: "DeviceID 标记检测",
                        risk: .safe,
                        detail: "API 正常响应 — DeviceID 未被标记",
                        suggestion: "当前设备指纹与账号状态正常，未检测到限制。"
                    ))

                case 401:
                    results.append(CheckResult(
                        category: "身份", name: "DeviceID 标记检测",
                        risk: .high,
                        detail: "OAuth token 已失效 (401)",
                        suggestion: "Token 可能已被吊销。如果你最近没有登出，这可能是封号的前兆。尝试重新登录 Claude Code。"
                    ))

                case 403:
                    let isSuspended = errorMessage.lowercased().contains("suspend")
                        || errorMessage.lowercased().contains("disabled")
                        || errorMessage.lowercased().contains("banned")
                        || errorMessage.lowercased().contains("violation")
                    if isSuspended {
                        results.append(CheckResult(
                            category: "身份", name: "DeviceID 标记检测",
                            risk: .critical,
                            detail: "账号/设备已被封禁 (403: \(errorType))",
                            suggestion: "你的 DeviceID 或账号已被 Anthropic 标记。删除 ~/.claude/config.json 中的 userID 字段可重置设备指纹，但账号级封禁无法绕过。"
                        ))
                    } else {
                        results.append(CheckResult(
                            category: "身份", name: "DeviceID 标记检测",
                            risk: .high,
                            detail: "访问被拒 (403: \(errorType))",
                            suggestion: "当前 DeviceID 可能已被标记。错误: \(errorMessage.prefix(100))"
                        ))
                    }

                case 429:
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "retry-after")
                    let retrySeconds = retryAfter.flatMap { Int($0) } ?? 0
                    let isHardThrottle = retrySeconds > 300

                    results.append(CheckResult(
                        category: "身份", name: "DeviceID 标记检测",
                        risk: isHardThrottle ? .high : .medium,
                        detail: "被限速 (429, retry-after: \(retryAfter ?? "未知")s)",
                        suggestion: isHardThrottle
                            ? "异常长的限速时间 (\(retrySeconds)s) 可能表示 DeviceID 被特别标记。正常限速一般在 60s 以内。"
                            : "普通限速，属于正常使用范围。"
                    ))

                case 400:
                    if errorType == "invalid_request_error" {
                        results.append(CheckResult(
                            category: "身份", name: "DeviceID 标记检测",
                            risk: .safe,
                            detail: "API 可达，认证通过 (400: 请求格式问题)",
                            suggestion: "设备身份验证通过，DeviceID 未被标记。400 错误仅因探测请求格式简化导致。"
                        ))
                    } else {
                        results.append(CheckResult(
                            category: "身份", name: "DeviceID 标记检测",
                            risk: .info,
                            detail: "API 返回 400: \(errorType)",
                            suggestion: "\(errorMessage.prefix(100))"
                        ))
                    }

                default:
                    results.append(CheckResult(
                        category: "身份", name: "DeviceID 标记检测",
                        risk: .info,
                        detail: "API 返回 HTTP \(httpResponse.statusCode)",
                        suggestion: "\(errorMessage.prefix(100))"
                    ))
                }

                continuation.resume(returning: results)
            }.resume()
        }
    }

    /// Check if IP/account is banned by testing connectivity to Anthropic API
    private func checkBanStatus() async -> [CheckResult] {
        await withCheckedContinuation { continuation in
            var results: [CheckResult] = []

            let url = URL(string: "https://api.anthropic.com/api/auth/check")!
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.httpMethod = "GET"
            request.setValue("claude-cli/1.0", forHTTPHeaderField: "User-Agent")

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 10
            let session = URLSession(configuration: config)

            session.dataTask(with: request) { _, response, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.code == -1009 {
                        results.append(CheckResult(
                            category: "网络", name: "API 连通性",
                            risk: .high,
                            detail: "无法连接到 api.anthropic.com (无网络)",
                            suggestion: nil
                        ))
                    } else if nsError.code == -1004 || nsError.code == -1003 {
                        results.append(CheckResult(
                            category: "网络", name: "API 封禁检测",
                            risk: .critical,
                            detail: "api.anthropic.com 连接被拒绝/无法解析",
                            suggestion: "你的 IP 可能已被 Anthropic 封禁。尝试更换网络环境。"
                        ))
                    } else {
                        results.append(CheckResult(
                            category: "网络", name: "API 连通性",
                            risk: .info,
                            detail: "连接异常: \(error.localizedDescription)",
                            suggestion: nil
                        ))
                    }
                    continuation.resume(returning: results)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200...299, 401, 404:
                        results.append(CheckResult(
                            category: "网络", name: "API 封禁检测",
                            risk: .safe,
                            detail: "api.anthropic.com 可达 (HTTP \(httpResponse.statusCode))",
                            suggestion: "IP 未被封禁，API 连通正常。"
                        ))
                    case 403:
                        results.append(CheckResult(
                            category: "网络", name: "API 封禁检测",
                            risk: .critical,
                            detail: "api.anthropic.com 返回 403 Forbidden",
                            suggestion: "你的 IP 或账号可能已被 Anthropic 封禁！建议更换 IP 或联系客服。"
                        ))
                    case 429:
                        results.append(CheckResult(
                            category: "网络", name: "API 封禁检测",
                            risk: .high,
                            detail: "api.anthropic.com 返回 429 Rate Limited",
                            suggestion: "当前 IP 被限速。短时间内过多请求可能触发封号。"
                        ))
                    default:
                        results.append(CheckResult(
                            category: "网络", name: "API 连通性",
                            risk: .info,
                            detail: "api.anthropic.com 响应 HTTP \(httpResponse.statusCode)",
                            suggestion: nil
                        ))
                    }
                }

                continuation.resume(returning: results)
            }.resume()
        }
    }

    /// Fetch IP info using a dedicated URLSession to avoid task cancellation issues
    private func fetchIPInfo() async -> [CheckResult] {
        await withCheckedContinuation { continuation in
            let url = URL(string: "https://ipinfo.io/json")!
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.setValue("OhMyIsland/1.0", forHTTPHeaderField: "User-Agent")

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 15
            let session = URLSession(configuration: config)

            session.dataTask(with: request) { data, _, error in
                var results: [CheckResult] = []

                if let error = error {
                    results.append(CheckResult(
                        category: "网络", name: "IP 检测",
                        risk: .info,
                        detail: "无法获取 IP 信息: \(error.localizedDescription)",
                        suggestion: "检查网络连接。"
                    ))
                    continuation.resume(returning: results)
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    results.append(CheckResult(
                        category: "网络", name: "IP 检测",
                        risk: .info,
                        detail: "IP 数据解析失败",
                        suggestion: nil
                    ))
                    continuation.resume(returning: results)
                    return
                }

                let ip = json["ip"] as? String ?? "unknown"
                let country = json["country"] as? String ?? "unknown"
                let city = json["city"] as? String ?? "unknown"
                let org = json["org"] as? String ?? "unknown"
                let ipTimezone = json["timezone"] as? String ?? ""

                // IP location
                results.append(CheckResult(
                    category: "网络", name: "IP 地区",
                    risk: .info,
                    detail: "\(ip) — \(country), \(city)",
                    suggestion: "IP 地址和地理位置可用于检测账号共享（不同地理位置短时间登录）。"
                ))

                // Data center / VPN IP detection
                let orgLower = org.lowercased()
                let dcKeywords = ["amazon", "google cloud", "microsoft", "digitalocean", "linode", "vultr",
                                  "hetzner", "ovh", "cloudflare", "data center", "hosting", "datacenter",
                                  "alibaba cloud", "tencent cloud", "oracle cloud", "rackspace"]
                let isDataCenter = dcKeywords.contains { orgLower.contains($0) }

                if isDataCenter {
                    results.append(CheckResult(
                        category: "网络", name: "数据中心 IP",
                        risk: .high,
                        detail: "IP 属于数据中心/VPN (\(org))",
                        suggestion: "使用数据中心 IP 会被视为服务器/自动化环境。建议使用住宅 IP。"
                    ))
                } else {
                    results.append(CheckResult(
                        category: "网络", name: "IP 类型",
                        risk: .safe,
                        detail: "住宅 IP (\(org))",
                        suggestion: nil
                    ))
                }

                // Timezone match
                let localTimezone = TimeZone.current.identifier
                if !ipTimezone.isEmpty && localTimezone != ipTimezone {
                    results.append(CheckResult(
                        category: "网络", name: "时区匹配",
                        risk: .medium,
                        detail: "本地: \(localTimezone) vs IP: \(ipTimezone)",
                        suggestion: "时区不匹配可能表明使用了 VPN。Anthropic 会对比本地时区与 IP 地理位置。"
                    ))
                } else if !ipTimezone.isEmpty {
                    results.append(CheckResult(
                        category: "网络", name: "时区匹配",
                        risk: .safe,
                        detail: "一致: \(localTimezone)",
                        suggestion: nil
                    ))
                }

                continuation.resume(returning: results)
            }.resume()
        }
    }

    // MARK: - Helpers

    private func runShellCommand(_ command: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
