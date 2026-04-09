import Lottie
import SwiftUI
import OhMyIslandCore

struct NotchPanelView: View {
    var appState: AppState
    let hasNotch: Bool
    let notchHeight: CGFloat
    let notchW: CGFloat
    let screenWidth: CGFloat

    @AppStorage(SettingsKey.contentFontSize) private var contentFontSize = SettingsDefaults.contentFontSize
    @AppStorage(SettingsKey.showAgentDetails) private var showAgentDetails = SettingsDefaults.showAgentDetails
    @AppStorage(SettingsKey.smartSuppress) private var smartSuppress = SettingsDefaults.smartSuppress
    @AppStorage(SettingsKey.hideWhenNoSession) private var hideWhenNoSession = SettingsDefaults.hideWhenNoSession

    /// Delayed hover: prevents accidental expansion when mouse passes through
    @State private var hoverTimer: Timer?
    @State private var idleHovered = false

    private var isActive: Bool { !appState.sessions.isEmpty }
    /// First launch / no-session state should still render a visible marker so the app
    /// doesn't disappear completely behind the physical notch.
    private var showIdleIndicator: Bool {
        !isActive && !hideWhenNoSession
    }
    /// Whether the bar content should be visible (respects hideWhenNoSession)
    private var showBar: Bool {
        isActive && !(hideWhenNoSession && appState.activeSessionCount == 0)
    }
    private var shouldShowExpanded: Bool {
        showBar && appState.surface.isExpanded
    }

    /// Mascot size — fits within the menu bar height
    private var mascotSize: CGFloat { min(27, notchHeight - 6) }

    private var tierBorderColor: Color {
        let hex = MembershipTracker.shared.currentTier.colorHex
        return Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    /// Minimum wing width needed to display compact bar content
    private var compactWingWidth: CGFloat { mascotSize + 14 }

    /// Total panel width — adapts based on state and screen geometry
    private var panelWidth: CGFloat {
        let maxWidth = min(620, screenWidth - 40)
        if showIdleIndicator { return idleHovered ? notchW + compactWingWidth * 2 + 80 : notchW + compactWingWidth * 2 }
        if !isActive { return hasNotch ? notchW - 20 : notchW }
        if shouldShowExpanded { return min(max(notchW + 200, 580), maxWidth) }
        let wing = compactWingWidth
        let extra: CGFloat = appState.status == .idle ? 0 : 20
        return notchW + wing * 2 + extra
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if showBar {
                    // Active: compact bar — wider version when expanded
                    HStack(spacing: 0) {
                        CompactLeftWing(appState: appState, expanded: shouldShowExpanded, mascotSize: mascotSize)
                        Spacer(minLength: hasNotch && !shouldShowExpanded ? notchW : 0)
                        CompactRightWing(appState: appState, expanded: shouldShowExpanded)
                    }
                    .frame(height: notchHeight)
                } else if showIdleIndicator {
                    IdleIndicatorBar(
                        mascotSize: mascotSize,
                        compactWingWidth: compactWingWidth,
                        notchW: notchW,
                        notchHeight: notchHeight,
                        hasNotch: hasNotch,
                        hovered: idleHovered
                    )
                } else {
                    // Idle: just the notch shell
                    Spacer()
                        .frame(height: notchHeight)
                }

                // Below-notch expanded content
                if shouldShowExpanded {
                    Line()
                        .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                        .frame(height: 0.5)
                        .padding(.horizontal, 12)

                    switch appState.surface {
                    case .approvalCard:
                        if let pending = appState.pendingPermission {
                            ApprovalBar(
                                tool: pending.event.toolName ?? "Unknown",
                                toolInput: pending.event.toolInput,
                                queuePosition: 1,
                                queueTotal: appState.permissionQueue.count,
                                onAllow: { appState.approvePermission(always: false) },
                                onAlwaysAllow: { appState.approvePermission(always: true) },
                                onDeny: { appState.denyPermission() }
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                        }
                    case .questionCard(let sid):
                        let session = appState.sessions[sid]
                        if let q = appState.pendingQuestion {
                            QuestionBar(
                                question: q.question.question,
                                options: q.question.options,
                                descriptions: q.question.descriptions,
                                sessionSource: session?.source,
                                sessionContext: session?.cwd,
                                queuePosition: 1,
                                queueTotal: appState.questionQueue.count,
                                onAnswer: { appState.answerQuestion($0) },
                                onSkip: { appState.skipQuestion() }
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                        } else if let preview = appState.previewQuestionPayload {
                            QuestionBar(
                                question: preview.question,
                                options: preview.options,
                                descriptions: preview.descriptions,
                                sessionSource: session?.source,
                                sessionContext: session?.cwd,
                                queuePosition: 1,
                                queueTotal: 1,
                                onAnswer: { _ in },
                                onSkip: { }
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                        }
                    case .chat(let sid):
                        if let session = appState.sessions[sid] {
                            ChatView(
                                session: session,
                                sessionId: sid,
                                appState: appState
                            )
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    case .completionCard:
                        SessionListView(appState: appState, onlySessionId: appState.justCompletedSessionId)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    case .sessionList:
                        SessionListView(appState: appState, onlySessionId: nil)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    case .buddyCard:
                        if let buddy = BuddyService.shared.buddy {
                            BuddyCardView(buddy: buddy)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                        }
                    case .usagePanel:
                        if let usageInfo = UsageTracker.shared.info {
                            UsagePanelView(info: usageInfo)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                        } else {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("正在加载用量数据…")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(.vertical, 16)
                            .task {
                                await UsageTracker.shared.refresh()
                            }
                        }
                    case .settingsPanel:
                        NotchSettingsView(appState: appState)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    case .environmentCheck:
                        EnvironmentCheckView()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    case .membershipCard:
                        MembershipCardView()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    case .collapsed:
                        EmptyView()
                    }
                }
            }
            .frame(width: panelWidth)
            .clipped()
            .background(
                NotchPanelShape(
                    topExtension: shouldShowExpanded ? 14 : 3,
                    bottomRadius: shouldShowExpanded ? 24 : 12,
                    minHeight: notchHeight
                )
                .fill(.black)
            )
            .overlay(
                isActive ? NotchPanelShape(
                    topExtension: shouldShowExpanded ? 14 : 3,
                    bottomRadius: shouldShowExpanded ? 24 : 12,
                    minHeight: notchHeight
                )
                .stroke(
                    MembershipTracker.shared.currentTier.level > 1
                        ? tierBorderColor.opacity(0.15)
                        : .clear,
                    lineWidth: 1
                ) : nil
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                // Idle indicator hover
                if showIdleIndicator {
                    withAnimation(NotchAnimation.micro) { idleHovered = hovering }
                    return
                }
                switch appState.surface {
                case .approvalCard, .questionCard, .chat, .buddyCard, .usagePanel, .settingsPanel, .environmentCheck: return
                case .completionCard:
                    // Completion card: mark entered on hover-in, block collapse until entered
                    if hovering {
                        appState.completionHasBeenEntered = true
                    } else if appState.completionHasBeenEntered {
                        // Mouse entered then left — allow collapse
                        hoverTimer?.invalidate()
                        hoverTimer = nil
                        withAnimation(NotchAnimation.close) {
                            appState.surface = .collapsed
                            appState.cancelCompletionQueue()
                        }
                    }
                    return
                default: break
                }
                // Respect collapseOnMouseLeave setting
                if !hovering && !SettingsManager.shared.collapseOnMouseLeave { return }
                // Smart suppress: don't auto-expand when active session's terminal is foreground
                if hovering && smartSuppress {
                    if let delegate = NSApp.delegate as? AppDelegate,
                       let pc = delegate.panelController,
                       pc.isActiveTerminalForeground() {
                        return
                    }
                }

                if hovering {
                    hoverTimer?.invalidate()
                    hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                        Task { @MainActor in
                            guard appState.surface == .collapsed else { return }
                            withAnimation(NotchAnimation.open) {
                                appState.surface = .sessionList
                                appState.cancelCompletionQueue()
                                if appState.activeSessionId == nil {
                                    appState.activeSessionId = appState.sessions.keys.sorted().first
                                }
                            }
                        }
                    }
                } else {
                    hoverTimer?.invalidate()
                    hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                        Task { @MainActor in
                            guard appState.surface == .sessionList else { return }
                            withAnimation(NotchAnimation.close) {
                                appState.surface = .collapsed
                            }
                        }
                    }
                }
            }

            Spacer()
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(NotchAnimation.open, value: appState.surface)
    }
}


// MARK: - Compact Wings (notch-level, 32px height)

/// Left side: pixel character + status info
private struct CompactLeftWing: View {
    var appState: AppState
    let expanded: Bool
    let mascotSize: CGFloat
    @AppStorage(SettingsKey.sessionGroupingMode) private var groupingMode = SettingsDefaults.sessionGroupingMode

    private var displaySource: String { appState.rotatingSession?.source ?? appState.primarySource }
    private var displayStatus: AgentStatus { appState.rotatingSession?.status ?? appState.status }

    private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        HStack(spacing: 6) {
            if expanded {
                ClaudeLogoCompact(size: 22)
                    .padding(.leading, 4)
                    .onTapGesture {
                        MembershipCardPopupController.shared.toggle()
                    }
                if appState.sessions.count > 1 {
                    HStack(spacing: 2) {
                        ForEach([("all", "All"), ("status", "Status"), ("cli", "CLI")], id: \.0) { tag, label in
                            let selected = groupingMode == tag
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { groupingMode = tag }
                            } label: {
                                Text(label)
                                    .font(.system(size: 10, weight: selected ? .semibold : .regular, design: .serif))
                                    .foregroundStyle(selected ? claudeOrange : .white.opacity(0.4))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(selected ? claudeOrange.opacity(0.12) : .clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                MascotView(source: displaySource, status: displayStatus, size: mascotSize)
                    .id(displaySource)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: displaySource)
                    .onTapGesture {
                        if BuddyService.shared.isLoaded {
                            withAnimation(NotchAnimation.open) {
                                appState.surface = appState.surface == .buddyCard ? .collapsed : .buddyCard
                            }
                        }
                    }
            }
        }
        .padding(.leading, 6)
        .clipped()
    }
}

/// Right side: model + session count
private struct CompactRightWing: View {
    var appState: AppState
    let expanded: Bool
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = SettingsDefaults.soundEnabled

    private var activeProjectName: String? {
        guard let id = appState.activeSessionId,
              let session = appState.sessions[id],
              let cwd = session.cwd else { return nil }
        return (cwd as NSString).lastPathComponent
    }

    private var environmentCheckColor: Color {
        guard let report = EnvironmentChecker.shared.report else {
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        }
        switch report.overallRisk {
        case .safe, .info: return .green
        case .low: return .gray
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if expanded {
                let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)
                NotchIconButton(icon: soundEnabled ? "speaker.wave.2" : "speaker.slash", tint: claudeOrange, tooltip: soundEnabled ? l10n["mute"] : l10n["enable_sound_tooltip"]) {
                    soundEnabled.toggle()
                }
                NotchIconButton(
                    icon: "shield.checkered",
                    tint: environmentCheckColor,
                    tooltip: "环境安全检测"
                ) {
                    withAnimation(NotchAnimation.open) {
                        appState.surface = appState.surface == .environmentCheck ? .sessionList : .environmentCheck
                    }
                }
                NotchIconButton(
                    icon: "person.crop.rectangle.stack",
                    tint: claudeOrange,
                    tooltip: "会员等级"
                ) {
                    withAnimation(NotchAnimation.open) {
                        appState.surface = appState.surface == .membershipCard ? .sessionList : .membershipCard
                    }
                }
                NotchIconButton(
                    icon: "chart.bar.fill",
                    tint: UsageTracker.shared.info?.color ?? claudeOrange,
                    tooltip: UsageTracker.shared.info?.tooltip ?? "用量"
                ) {
                    withAnimation(NotchAnimation.open) {
                        appState.surface = appState.surface == .usagePanel ? .sessionList : .usagePanel
                    }
                }
                NotchIconButton(icon: "line.3.horizontal", tint: claudeOrange, tooltip: l10n["settings"]) {
                    withAnimation(NotchAnimation.open) {
                        appState.surface = appState.surface == .settingsPanel ? .sessionList : .settingsPanel
                    }
                }
                NotchIconButton(icon: "power", tint: Color(red: 1.0, green: 0.45, blue: 0.35), tooltip: l10n["quit"]) {
                    NSApplication.shared.terminate(nil)
                }
            } else {
                if appState.status != .idle, let projectName = activeProjectName {
                    Text(projectName)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.3, green: 0.85, blue: 0.4))
                        .lineLimit(1)
                }

                if appState.status == .waitingApproval || appState.status == .waitingQuestion {
                    LottieTypingIndicator(size: 18)
                } else if appState.status == .processing || appState.status == .running {
                    LottieLoadingSpinner(size: 14)
                }

                if let usageInfo = UsageTracker.shared.info, let pct = usageInfo.fiveHourPercent {
                    UsageMiniBar(percent: pct, color: usageInfo.color)
                        .help(usageInfo.tooltip)
                        .onTapGesture {
                            withAnimation(NotchAnimation.open) {
                                appState.surface = appState.surface == .usagePanel ? .collapsed : .usagePanel
                            }
                        }
                }

                HStack(spacing: 1) {
                    let active = appState.activeSessionCount
                    let total = appState.totalSessionCount
                    if active > 0 {
                        Text("\(active)")
                            .foregroundStyle(Color(red: 0.85, green: 0.47, blue: 0.34))
                        Text("/")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Text("\(total)")
                        .foregroundStyle(.white.opacity(0.9))
                }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
        }
        .padding(.trailing, 6)
    }
}

private struct NotchIconButton: View {
    let icon: String
    var tint: Color = .white
    var tooltip: String? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint.opacity(hovering ? 1.0 : 0.85))
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(tint.opacity(hovering ? 0.2 : 0.08))
                )
                .scaleEffect(hovering ? 1.1 : 1.0)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(NotchAnimation.micro) { hovering = h } }
        .help(tooltip ?? "")
    }
}

// MARK: - Idle Indicator Bar

private struct IdleIndicatorBar: View {
    let mascotSize: CGFloat
    let compactWingWidth: CGFloat
    let notchW: CGFloat
    let notchHeight: CGFloat
    let hasNotch: Bool
    let hovered: Bool
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = SettingsDefaults.soundEnabled

    var body: some View {
        HStack(spacing: 0) {
            // Left: mascot
            HStack(spacing: 6) {
                MascotView(source: "claude", status: .idle, size: mascotSize)
                    .opacity(hovered ? 0.9 : 0.5)
            }
            .padding(.leading, 6)

            Spacer(minLength: hasNotch ? notchW : 0)

            // Right: expanded shows text + buttons, collapsed shows nothing
            if hovered {
                HStack(spacing: 8) {
                    Text("0")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))

                    HStack(spacing: 4) {
                        NotchIconButton(icon: soundEnabled ? "speaker.wave.2" : "speaker.slash", tooltip: soundEnabled ? l10n["mute"] : l10n["enable_sound_tooltip"]) {
                            soundEnabled.toggle()
                        }
                        NotchIconButton(icon: "power", tint: Color(red: 1.0, green: 0.4, blue: 0.4), tooltip: l10n["quit"]) {
                            NSApplication.shared.terminate(nil)
                        }
                    }
                }
                .padding(.trailing, 6)
                .transition(.opacity)
            }
        }
        .frame(height: notchHeight)
        .animation(NotchAnimation.micro, value: hovered)
    }
}

// MARK: - Approval Bar (below notch, auto-expanded)

private struct ApprovalBar: View {
    let tool: String
    let toolInput: [String: Any]?
    let queuePosition: Int
    let queueTotal: Int
    let onAllow: () -> Void
    let onAlwaysAllow: () -> Void
    let onDeny: () -> Void

    private var fileName: String? {
        guard let fp = toolInput?["file_path"] as? String else { return nil }
        return (fp as NSString).lastPathComponent
    }

    private var filePath: String? {
        toolInput?["file_path"] as? String
    }

    private var serverName: String? {
        toolInput?["server_name"] as? String
    }

    var body: some View {
        VStack(spacing: 8) {
            // Tool name + file context
            HStack(spacing: 6) {
                Text("!")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.85, green: 0.47, blue: 0.34))
                Text(tool)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.85, green: 0.47, blue: 0.34))
                if let server = serverName {
                    Text("(\(server))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color(red: 0.6, green: 0.7, blue: 0.9))
                }
                if let name = fileName {
                    Text(name)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                if queueTotal > 1 {
                    Text("\(queuePosition)/\(queueTotal)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Spacer()
            }
            .padding(.horizontal, 14)

            // Tool-specific detail view
            if toolInput != nil {
                toolDetailView
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
            }

            // Pixel-style buttons
            HStack(spacing: 6) {
                PixelButton(label: L10n.shared["deny"], fg: .white.opacity(0.95), bg: Color(red: 0.45, green: 0.12, blue: 0.12), border: Color(red: 0.7, green: 0.25, blue: 0.25), action: onDeny)
                PixelButton(label: L10n.shared["allow_once"], fg: .white.opacity(0.95), bg: Color(red: 0.16, green: 0.38, blue: 0.18), border: Color(red: 0.28, green: 0.62, blue: 0.32), action: onAllow)
                PixelButton(label: L10n.shared["always"], fg: .white.opacity(0.95), bg: Color(red: 0.14, green: 0.28, blue: 0.52), border: Color(red: 0.28, green: 0.48, blue: 0.82), action: onAlwaysAllow)
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var toolDetailView: some View {
        switch tool {
        case "Bash":
            // Show command as a terminal prompt
            VStack(alignment: .leading, spacing: 2) {
                if let cmd = toolInput?["command"] as? String {
                    HStack(alignment: .top, spacing: 4) {
                        Text("$")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.3, green: 0.85, blue: 0.4))
                        Text(cmd)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(3)
                    }
                }
            }

        case "Edit":
            VStack(alignment: .leading, spacing: 0) {
                if let fp = filePath {
                    Text(fp)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.head)
                        .padding(.bottom, 6)
                }
                VStack(alignment: .leading, spacing: 0) {
                    if let old = toolInput?["old_string"] as? String, !old.isEmpty {
                        DiffBlock(text: old, isAddition: false)
                    }
                    if let new = toolInput?["new_string"] as? String, !new.isEmpty {
                        DiffBlock(text: new, isAddition: true)
                    }
                }
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
            }

        case "Write":
            // Show file path + content preview
            VStack(alignment: .leading, spacing: 3) {
                if let fp = filePath {
                    Text(fp)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                if let content = toolInput?["content"] as? String {
                    Text(content.prefix(200))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(4)
                }
            }

        case "Read":
            // Show file path + line range
            VStack(alignment: .leading, spacing: 2) {
                if let fp = filePath {
                    Text(fp)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                if let offset = toolInput?["offset"] as? Int,
                   let limit = toolInput?["limit"] as? Int {
                    Text("\(L10n.shared["lines"]) \(offset + 1)–\(offset + limit)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

        case "Grep":
            // Show pattern + optional path
            VStack(alignment: .leading, spacing: 2) {
                if let pattern = toolInput?["pattern"] as? String {
                    HStack(alignment: .top, spacing: 4) {
                        Text("/")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.9))
                        Text(pattern)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.9).opacity(0.8))
                            .lineLimit(2)
                    }
                }
                if let path = toolInput?["path"] as? String {
                    Text(path)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }

        case "Glob":
            // Show glob pattern
            VStack(alignment: .leading, spacing: 2) {
                if let pattern = toolInput?["pattern"] as? String {
                    Text(pattern)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(red: 0.6, green: 0.8, blue: 1.0))
                        .lineLimit(2)
                }
                if let path = toolInput?["path"] as? String {
                    Text(path)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }

        default:
            // Generic: show all key-value pairs
            VStack(alignment: .leading, spacing: 2) {
                if let input = toolInput {
                    ForEach(Array(input.keys.sorted().prefix(4)), id: \.self) { key in
                        let val = input[key].map { "\($0)" } ?? ""
                        HStack(alignment: .top, spacing: 4) {
                            Text(key)
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.6, green: 0.7, blue: 0.9))
                            Text(String(val.prefix(100)))
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Diff Block (line-by-line red/green diff)

private struct DiffBlock: View {
    let text: String
    let isAddition: Bool

    private let maxLines = 8

    var body: some View {
        let lines = text.components(separatedBy: "\n")
        let displayLines = Array(lines.prefix(maxLines))
        let truncated = lines.count > maxLines

        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                HStack(spacing: 0) {
                    Text(isAddition ? "+" : "−")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(isAddition ? Color(red: 0.3, green: 0.85, blue: 0.4) : Color(red: 1.0, green: 0.4, blue: 0.4))
                        .frame(width: 16)

                    Text(line.isEmpty ? " " : line)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(isAddition
                            ? Color(red: 0.3, green: 0.85, blue: 0.4).opacity(0.8)
                            : Color(red: 1.0, green: 0.4, blue: 0.4).opacity(0.8))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 1.5)
                .padding(.horizontal, 6)
                .background(isAddition
                    ? Color(red: 0.3, green: 0.85, blue: 0.4).opacity(0.08)
                    : Color(red: 1.0, green: 0.4, blue: 0.4).opacity(0.08))
            }

            if truncated {
                Text("  … +\(lines.count - maxLines) more lines")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
        }
    }
}

// MARK: - Question Bar (below notch, auto-expanded)

private struct QuestionBar: View {
    let question: String
    let options: [String]?
    let descriptions: [String]?
    let sessionSource: String?
    let sessionContext: String?
    let queuePosition: Int
    let queueTotal: Int
    let onAnswer: (String) -> Void
    let onSkip: () -> Void

    @State private var textInput = ""
    @FocusState private var isFocused: Bool
    @State private var selectedIndex: Int? = nil

    private let cyan = Color(red: 0.4, green: 0.7, blue: 1.0)

    var body: some View {
        VStack(spacing: 8) {
            // Session context
            if sessionSource != nil || sessionContext != nil {
                HStack(spacing: 5) {
                    if let src = sessionSource, let icon = cliIcon(source: src, size: 12) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 12, height: 12)
                    }
                    if let cwd = sessionContext {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.5))
                        Text((cwd as NSString).lastPathComponent)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
            }

            // Header
            HStack(spacing: 6) {
                Text("?")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(cyan)
                Text(question)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
                if queueTotal > 1 {
                    Text("\(queuePosition)/\(queueTotal)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Spacer()
            }
            .padding(.horizontal, 14)

            // Options
            if let options = options, !options.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                        let desc = descriptions?.indices.contains(idx) == true ? descriptions?[idx] : nil
                        OptionRow(index: idx + 1, label: option, description: desc, isSelected: selectedIndex == idx, accent: cyan) {
                            selectedIndex = idx
                            onAnswer(option)
                        }
                    }
                }
                .padding(.horizontal, 14)
            } else {
                // Text input
                HStack(spacing: 6) {
                    Text(">")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.3, green: 0.85, blue: 0.4))
                    TextField(L10n.shared["type_answer"], text: $textInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.white)
                        .focused($isFocused)
                        .onSubmit {
                            if !textInput.isEmpty { onAnswer(textInput) }
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 14)
            }

            // Skip button
            HStack(spacing: 6) {
                PixelButton(
                    label: L10n.shared["skip"],
                    fg: .white.opacity(0.6),
                    bg: Color.white.opacity(0.06),
                    border: Color.white.opacity(0.12),
                    action: onSkip
                )
                if options == nil || options?.isEmpty == true {
                    PixelButton(
                        label: L10n.shared["submit"],
                        fg: .white.opacity(0.95),
                        bg: Color(red: 0.16, green: 0.38, blue: 0.18),
                        border: Color(red: 0.28, green: 0.62, blue: 0.32),
                        action: { if !textInput.isEmpty { onAnswer(textInput) } }
                    )
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 10)
        .onAppear { isFocused = true }
    }
}

// MARK: - Option Row

private struct OptionRow: View {
    let index: Int
    let label: String
    let description: String?
    let isSelected: Bool
    let accent: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Selector arrow
                Text(hovering ? "▸" : " ")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                    .frame(width: 10)
                // Number
                Text("\(index).")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent.opacity(hovering ? 1 : 0.6))
                // Label + Description
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 10.5, weight: hovering ? .semibold : .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(hovering ? 1 : 0.75))
                    if let description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(hovering ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(hovering ? accent.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(NotchAnimation.micro) { hovering = h } }
    }
}

private struct PixelButton: View {
    let label: String
    let fg: Color
    let bg: Color
    let border: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hovering ? bg.opacity(1.5) : bg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(hovering ? border : border.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(NotchAnimation.micro) { hovering = h } }
    }
}

// MARK: - Session List

private struct SessionListView: View {
    var appState: AppState
    /// When set, only show this session (auto-expand on completion)
    var onlySessionId: String? = nil
    @AppStorage(SettingsKey.sessionGroupingMode) private var groupingMode = SettingsDefaults.sessionGroupingMode
    @AppStorage(SettingsKey.maxVisibleSessions) private var maxVisibleSessions = SettingsDefaults.maxVisibleSessions

    private var groupedSessions: [(header: String, source: String?, ids: [String])] {
        if let only = onlySessionId, appState.sessions[only] != nil {
            return [("", nil, [only])]
        }

        let sorted = appState.sessions.keys.sorted()

        switch groupingMode {
        case "status":
            let l10n = L10n.shared
            let groups: [(Set<AgentStatus>, String)] = [
                ([.running], l10n["status_running"]),
                ([.waitingApproval, .waitingQuestion], l10n["status_waiting"]),
                ([.processing], l10n["status_processing"]),
                ([.idle], l10n["status_idle"]),
            ]
            var result: [(String, String?, [String])] = []
            for (statuses, label) in groups {
                let ids = sorted.filter { id in
                    guard let s = appState.sessions[id] else { return false }
                    return statuses.contains(s.status)
                }
                if !ids.isEmpty {
                    result.append(("\(label) (\(ids.count))", nil, ids))
                }
            }
            return result

        case "cli":
            let cliOrder: [(source: String, name: String)] = [
                ("claude", "Claude"),
                ("codex", "Codex"),
                ("gemini", "Gemini"),
                ("cursor", "Cursor"),
                ("qoder", "Qoder"),
                ("droid", "Factory"),
                ("codebuddy", "CodeBuddy"),
                ("opencode", "OpenCode"),
            ]
            var result: [(String, String?, [String])] = []
            var seen = Set<String>()
            for cli in cliOrder {
                let ids = sorted.filter { id in
                    appState.sessions[id]?.source == cli.source
                }
                ids.forEach { seen.insert($0) }
                if !ids.isEmpty {
                    result.append(("\(cli.name) (\(ids.count))", cli.source, ids))
                }
            }
            let remaining = sorted.filter { !seen.contains($0) }
            if !remaining.isEmpty {
                result.append(("\(L10n.shared["other"]) (\(remaining.count))", nil, remaining))
            }
            return result

        default: // "all"
            return [("", nil, sorted)]
        }
    }

    var body: some View {
        // Compute once per render — groupedSessions, totalCount, needsScroll
        let groups = groupedSessions
        let totalSessionCount = groups.reduce(0) { $0 + $1.ids.count }
        let needsScroll = onlySessionId == nil && totalSessionCount > maxVisibleSessions
        let content = VStack(spacing: 6) {
            ForEach(groups, id: \.header) { group in
                if !group.header.isEmpty {
                    HStack(spacing: 6) {
                        if let src = group.source, let icon = cliIcon(source: src) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 14, height: 14)
                        }
                        Text(group.header)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                }

                ForEach(group.ids, id: \.self) { sessionId in
                    if let session = appState.sessions[sessionId] {
                        SessionCard(
                            sessionId: sessionId,
                            session: session,
                            isCompletion: onlySessionId != nil,
                            onChat: session.source == "claude" ? {
                                withAnimation(NotchAnimation.open) {
                                    appState.surface = .chat(sessionId: sessionId)
                                }
                            } : nil
                        )
                    }
                }
            }

            // "Show all sessions" — hover with delay to expand
            if onlySessionId != nil && appState.sessions.count > 1 {
                SessionsExpandLink(count: appState.sessions.count) {
                    withAnimation(NotchAnimation.open) {
                        appState.surface = .sessionList
                        appState.cancelCompletionQueue()
                    }
                }
            }
        }
        .padding(.vertical, 4)

        if needsScroll {
            ThinScrollView(maxHeight: CGFloat(maxVisibleSessions) * 90) {
                content
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 20,
                    bottomTrailingRadius: 20, topTrailingRadius: 0,
                    style: .continuous
                )
            )
        } else {
            content
        }
    }
}

/// Thin overlay scrollbar via NSScrollView — ignores system "show scrollbar" preference.
private struct ThinScrollView<Content: View>: NSViewRepresentable {
    let maxHeight: CGFloat
    @ViewBuilder let content: Content

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller?.controlSize = .mini
        scrollView.drawsBackground = false
        scrollView.scrollerKnobStyle = .light

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hosting

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: maxHeight),
        ])

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let hosting = scrollView.documentView as? NSHostingView<Content> {
            hosting.rootView = content
        }
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller?.controlSize = .mini
    }
}

private struct SessionIdCopyButton: View {
    let sessionId: String
    var fontSize: CGFloat = 10

    @State private var hovering = false
    @State private var copied = false
    @State private var resetTask: Task<Void, Never>?

    private var compactLabel: String {
        "#\(shortSessionId(sessionId))"
    }

    var body: some View {
        Button(action: copySessionId) {
            HStack(spacing: 4) {
                Text(compactLabel)
                    .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: max(8, fontSize - 1), weight: .semibold))
            }
            .foregroundStyle(copied ? Color(red: 0.3, green: 0.85, blue: 0.4) : .white.opacity(hovering ? 0.68 : 0.42))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(hovering || copied ? 0.08 : 0.001))
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(NotchAnimation.micro) { hovering = h }
        }
        .onDisappear {
            resetTask?.cancel()
        }
        .help("\(L10n.shared["copy_session_id"]) \(sessionId)")
    }

    private func copySessionId() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sessionId, forType: .string)
        copied = true
        resetTask?.cancel()
        resetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            copied = false
        }
    }
}

private struct SessionIdentityLine: View {
    let session: SessionSnapshot
    let sessionId: String
    let projectFontSize: CGFloat
    let projectColor: Color
    let sessionFontSize: CGFloat
    let sessionColor: Color
    let dividerColor: Color
    let cardHovering: Bool

    private var displaySessionId: String { session.displaySessionId(sessionId: sessionId) }

    var body: some View {
        HStack(spacing: 4) {
            ProjectNameLink(
                name: session.projectDisplayName,
                cwd: session.cwd,
                fontSize: projectFontSize,
                color: projectColor,
                cardHovering: cardHovering
            )
            .layoutPriority(2)

            if let sessionLabel = session.sessionLabel {
                Text("#\(sessionLabel)")
                    .font(.system(size: sessionFontSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(sessionColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Text("·")
                    .font(.system(size: sessionFontSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(dividerColor)

                SessionIdCopyButton(
                    sessionId: displaySessionId,
                    fontSize: sessionFontSize
                )
                .fixedSize()
            } else {
                SessionIdCopyButton(
                    sessionId: displaySessionId,
                    fontSize: sessionFontSize
                )
                .fixedSize()
            }
        }
    }
}

private struct ProjectNameLink: View {
    let name: String
    let cwd: String?
    let fontSize: CGFloat
    let color: Color
    let cardHovering: Bool

    var body: some View {
        Text(name)
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .overlay(alignment: .bottom) {
                if cwd != nil {
                    GeometryReader { geo in
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: geo.size.height))
                            path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .foregroundStyle(color.opacity(cardHovering ? 0.5 : 0.2))
                    }
                }
            }
            .onTapGesture {
                if let cwd = cwd {
                    NSWorkspace.shared.open(URL(fileURLWithPath: cwd))
                }
            }
            .help(cwd != nil ? "\(L10n.shared["open_path"]) \(cwd!)" : "")
    }
}

private struct SessionsExpandLink: View {
    let count: Int
    let action: () -> Void
    @State private var hovering = false
    @State private var hoverTimer: Timer?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
                Text("\(count) \(L10n.shared["n_sessions"])")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(hovering ? 0.7 : 0.45))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(hovering ? 0.5 : 0.3))
                Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(NotchAnimation.micro) { hovering = h }
            hoverTimer?.invalidate()
            hoverTimer = nil
            if h {
                hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
                    Task { @MainActor in action() }
                }
            }
        }
    }
}

private struct SessionCard: View {
    let sessionId: String
    let session: SessionSnapshot
    var isCompletion: Bool = false
    var onChat: (() -> Void)? = nil
    @State private var hovering = false
    @AppStorage(SettingsKey.contentFontSize) private var contentFontSize = SettingsDefaults.contentFontSize
    @AppStorage(SettingsKey.aiMessageLines) private var aiMessageLines = SettingsDefaults.aiMessageLines
    @AppStorage(SettingsKey.showAgentDetails) private var showAgentDetails = SettingsDefaults.showAgentDetails
    private var fontSize: CGFloat { CGFloat(contentFontSize) }
    private var aiLineLimit: Int? { aiMessageLines > 0 ? aiMessageLines : nil }
    private var statusNameColor: Color {
        if session.status == .idle && session.interrupted {
            return Color(red: 1.0, green: 0.45, blue: 0.35)
        }
        switch session.status {
        case .processing, .running:              return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .waitingApproval, .waitingQuestion:  return Color(red: 0.96, green: 0.65, blue: 0.14)
        case .idle:                               return .white.opacity(0.85)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Column 1: Character + subagent icons
            VStack(spacing: 3) {
                MascotView(source: session.source, status: session.status, size: 40)
                if showAgentDetails && !session.subagents.isEmpty {
                    let sorted = session.subagents.values.sorted { $0.startTime < $1.startTime }
                    // Grid: 4 per row, 8px icons
                    let rows = stride(from: 0, to: sorted.count, by: 4).map {
                        Array(sorted[$0..<min($0 + 4, sorted.count)])
                    }
                    VStack(spacing: 1) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 1) {
                                ForEach(row, id: \.agentId) { sub in
                                    MiniAgentIcon(active: sub.status != .idle, size: 8)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 44)

            // Column 2: Content
            VStack(alignment: .leading, spacing: 6) {
                // Header: project name + optional session label + short ID
                HStack(alignment: .center, spacing: 8) {
                    SessionIdentityLine(
                        session: session,
                        sessionId: sessionId,
                        projectFontSize: fontSize + 2,
                        projectColor: statusNameColor,
                        sessionFontSize: fontSize,
                        sessionColor: .white.opacity(0.76),
                        dividerColor: .white.opacity(0.28),
                        cardHovering: hovering
                    )
                    Spacer(minLength: 8)

                    HStack(spacing: 4) {
                        if session.interrupted {
                            SessionTag("INT", color: Color(red: 1.0, green: 0.6, blue: 0.2))
                        }
                        if session.isYoloMode == true {
                            SessionTag("YOLO", color: Color(red: 1.0, green: 0.35, blue: 0.35))
                        }
                        SessionTag(timeAgo(session.startTime))
                        TerminalJumpButton(session: session, sessionId: sessionId)
                    }
                }

                // Session title: first user prompt (hide when detailed mode shows chat history)
                if let prompt = session.lastUserPrompt,
                   session.recentMessages.isEmpty {
                    Text(prompt)
                        .font(.system(size: fontSize, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

            // Chat history + live status
            if !session.recentMessages.isEmpty || session.status != .idle {
                VStack(alignment: .leading, spacing: 3) {
                    // Chat messages (detailed mode only)
                    let visibleMessages = session.status != .idle
                        ? Array(session.recentMessages.suffix(2))
                        : session.recentMessages
                    ForEach(visibleMessages) { msg in
                        if msg.isUser {
                            HStack(alignment: .top, spacing: 4) {
                                Text(">")
                                    .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.3, green: 0.85, blue: 0.4))
                                Text(renderUserText(msg.text))
                                    .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        } else {
                            HStack(alignment: .top, spacing: 4) {
                                Text("$")
                                    .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.85, green: 0.47, blue: 0.34))
                                Text(renderMarkdown(compactText(stripDirectives(msg.text))))
                                    .font(.system(size: fontSize, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(aiLineLimit)
                                    .truncationMode(.tail)
                            }
                        }
                    }

                    // Working indicator: show what AI is doing right now
                    if session.status != .idle {
                        HStack(spacing: 4) {
                            Text("$")
                                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.85, green: 0.47, blue: 0.34))
                            if let tool = session.currentTool {
                                Text(session.toolDescription ?? tool)
                                    .font(.system(size: fontSize, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            } else {
                                TypingIndicator(fontSize: fontSize, label: "thinking")
                            }
                        }
                    }
                }
                .padding(.leading, 4)
            }
            } // end Column 2 VStack
        } // end HStack
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(hovering
                    ? Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.12)
                    : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.85, green: 0.47, blue: 0.34).opacity(hovering ? 0.15 : 0), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(NotchAnimation.micro) { hovering = h } }
        .onTapGesture {
            if isCompletion {
                TerminalActivator.activate(session: session, sessionId: sessionId)
            } else if let onChat {
                onChat()
            }
        }
    }

    /// Collapse consecutive blank lines and trim leading/trailing whitespace
    private func compactText(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .reduce(into: [String]()) { result, line in
                // Skip consecutive empty lines
                if line.isEmpty && (result.last?.isEmpty ?? true) { return }
                result.append(line)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func renderMarkdown(_ text: String) -> AttributedString {
        ChatMessageTextFormatter.inlineMarkdown(text)
    }

    private func renderUserText(_ text: String) -> AttributedString {
        ChatMessageTextFormatter.literalText(text)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "<1m" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }
}

// MARK: - Claude Logo (official sunburst from simple-icons, viewBox 0 0 24 24)

private struct ClaudeLogo: View {
    var size: CGFloat = 22
    private static let color = Color(red: 0.85, green: 0.47, blue: 0.34) // #D97757

    // Official Claude logo SVG path (source: simple-icons)
    fileprivate static let svgPath = "m4.7144 15.9555 4.7174-2.6471.079-.2307-.079-.1275h-.2307l-.7893-.0486-2.6956-.0729-2.3375-.0971-2.2646-.1214-.5707-.1215-.5343-.7042.0546-.3522.4797-.3218.686.0608 1.5179.1032 2.2767.1578 1.6514.0972 2.4468.255h.3886l.0546-.1579-.1336-.0971-.1032-.0972L6.973 9.8356l-2.55-1.6879-1.3356-.9714-.7225-.4918-.3643-.4614-.1578-1.0078.6557-.7225.8803.0607.2246.0607.8925.686 1.9064 1.4754 2.4893 1.8336.3643.3035.1457-.1032.0182-.0728-.164-.2733-1.3539-2.4467-1.445-2.4893-.6435-1.032-.17-.6194c-.0607-.255-.1032-.4674-.1032-.7285L6.287.1335 6.6997 0l.9957.1336.419.3642.6192 1.4147 1.0018 2.2282 1.5543 3.0296.4553.8985.2429.8318.091.255h.1579v-.1457l.1275-1.706.2368-2.0947.2307-2.6957.0789-.7589.3764-.9107.7468-.4918.5828.2793.4797.686-.0668.4433-.2853 1.8517-.5586 2.9021-.3643 1.9429h.2125l.2429-.2429.9835-1.3053 1.6514-2.0643.7286-.8196.85-.9046.5464-.4311h1.0321l.759 1.1293-.34 1.1657-1.0625 1.3478-.8804 1.1414-1.2628 1.7-.7893 1.36.0729.1093.1882-.0183 2.8535-.607 1.5421-.2794 1.8396-.3157.8318.3886.091.3946-.3278.8075-1.967.4857-2.3072.4614-3.4364.8136-.0425.0304.0486.0607 1.5482.1457.6618.0364h1.621l3.0175.2247.7892.522.4736.6376-.079.4857-1.2142.6193-1.6393-.3886-3.825-.9107-1.3113-.3279h-.1822v.1093l1.0929 1.0686 2.0035 1.8092 2.5075 2.3314.1275.5768-.3218.4554-.34-.0486-2.2039-1.6575-.85-.7468-1.9246-1.621h-.1275v.17l.4432.6496 2.3436 3.5214.1214 1.0807-.17.3521-.6071.2125-.6679-.1214-1.3721-1.9246L14.38 17.959l-1.1414-1.9428-.1397.079-.674 7.2552-.3156.3703-.7286.2793-.6071-.4614-.3218-.7468.3218-1.4753.3886-1.9246.3157-1.53.2853-1.9004.17-.6314-.0121-.0425-.1397.0182-1.4328 1.9672-2.1796 2.9446-1.7243 1.8456-.4128.164-.7164-.3704.0667-.6618.4008-.5889 2.386-3.0357 1.4389-1.882.929-1.0868-.0062-.1579h-.0546l-6.3385 4.1164-1.1293.1457-.4857-.4554.0608-.7467.2307-.2429 1.9064-1.3114Z"

    var body: some View {
        ClaudeLogoShape()
            .fill(Self.color)
            .frame(width: size, height: size)
    }
}

private struct ClaudeLogoShape: Shape {
    private static let basePath: Path = ClaudeLogoShape.parseSVGPath(ClaudeLogo.svgPath)

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return Self.basePath.applying(transform)
    }

    // Minimal SVG path parser for m/l/h/v/c/z commands
    private static func parseSVGPath(_ d: String) -> Path {
        var path = Path()
        var x: CGFloat = 0, y: CGFloat = 0
        var i = d.startIndex
        var cmd: Character = "m"

        func skipWS() {
            while i < d.endIndex && (d[i] == " " || d[i] == ",") { i = d.index(after: i) }
        }

        func peekNum() -> Bool {
            guard i < d.endIndex else { return false }
            let c = d[i]
            return c == "-" || c == "." || c.isNumber
        }

        func num() -> CGFloat {
            skipWS()
            var s = ""
            if i < d.endIndex && d[i] == "-" { s.append(d[i]); i = d.index(after: i) }
            var hasDot = false
            while i < d.endIndex {
                let c = d[i]
                if c == "." {
                    if hasDot { break }
                    hasDot = true; s.append(c); i = d.index(after: i)
                } else if c.isNumber {
                    s.append(c); i = d.index(after: i)
                } else { break }
            }
            return CGFloat(Double(s) ?? 0)
        }

        while i < d.endIndex {
            skipWS()
            guard i < d.endIndex else { break }
            let c = d[i]
            if c.isLetter {
                cmd = c; i = d.index(after: i)
            }

            switch cmd {
            case "m":
                let dx = num(), dy = num(); x += dx; y += dy
                path.move(to: CGPoint(x: x, y: y))
                cmd = "l" // subsequent coords are implicit lineTo
            case "M":
                x = num(); y = num()
                path.move(to: CGPoint(x: x, y: y))
                cmd = "L"
            case "l":
                let dx = num(), dy = num(); x += dx; y += dy
                path.addLine(to: CGPoint(x: x, y: y))
            case "L":
                x = num(); y = num()
                path.addLine(to: CGPoint(x: x, y: y))
            case "h":
                x += num(); path.addLine(to: CGPoint(x: x, y: y))
            case "H":
                x = num(); path.addLine(to: CGPoint(x: x, y: y))
            case "v":
                y += num(); path.addLine(to: CGPoint(x: x, y: y))
            case "V":
                y = num(); path.addLine(to: CGPoint(x: x, y: y))
            case "c":
                let dx1 = num(), dy1 = num(), dx2 = num(), dy2 = num(), dx = num(), dy = num()
                path.addCurve(to: CGPoint(x: x+dx, y: y+dy),
                              control1: CGPoint(x: x+dx1, y: y+dy1),
                              control2: CGPoint(x: x+dx2, y: y+dy2))
                x += dx; y += dy
            case "C":
                let x1 = num(), y1 = num(), x2 = num(), y2 = num()
                x = num(); y = num()
                path.addCurve(to: CGPoint(x: x, y: y),
                              control1: CGPoint(x: x1, y: y1),
                              control2: CGPoint(x: x2, y: y2))
            case "Z", "z":
                path.closeSubpath()
            default:
                i = d.index(after: i)
            }

            // Handle repeated implicit commands
            skipWS()
            if i < d.endIndex && peekNum() && "mlhvcMLHVC".contains(cmd) {
                continue
            }
        }
        return path
    }
}

// MARK: - Notch Panel Shape (inverse radius at top, regular radius at bottom)

private struct NotchPanelShape: Shape {
    var topExtension: CGFloat
    var bottomRadius: CGFloat
    /// Fixed minimum height — NOT animated, prevents spring overshoot from exposing the notch
    var minHeight: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topExtension, bottomRadius) }
        set {
            topExtension = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let ext = topExtension
        let maxY = max(rect.maxY, rect.minY + minHeight)
        let br = min(bottomRadius, rect.width / 4, (maxY - rect.minY) / 2)
        // Smoothness factor for continuous-curvature corners (superellipse approximation).
        // 0.5523 = perfect circle; higher values tighten the curve for an Apple squircle feel.
        let k: CGFloat = 0.62

        var p = Path()
        // Top edge (extends into notch area via wings)
        p.move(to: CGPoint(x: rect.minX - ext, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX + ext, y: rect.minY))
        // Right shoulder: cubic bezier tangent to top line (horizontal) and right side (vertical)
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + ext),
            control1: CGPoint(x: rect.maxX + ext * 0.35, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + ext * 0.35)
        )
        // Right side down to bottom-right corner
        p.addLine(to: CGPoint(x: rect.maxX, y: maxY - br))
        // Bottom-right: cubic bezier for continuous-curvature corner
        p.addCurve(
            to: CGPoint(x: rect.maxX - br, y: maxY),
            control1: CGPoint(x: rect.maxX, y: maxY - br * (1 - k)),
            control2: CGPoint(x: rect.maxX - br * (1 - k), y: maxY)
        )
        // Bottom edge
        p.addLine(to: CGPoint(x: rect.minX + br, y: maxY))
        // Bottom-left: cubic bezier for continuous-curvature corner
        p.addCurve(
            to: CGPoint(x: rect.minX, y: maxY - br),
            control1: CGPoint(x: rect.minX + br * (1 - k), y: maxY),
            control2: CGPoint(x: rect.minX, y: maxY - br * (1 - k))
        )
        // Left side up to shoulder
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + ext))
        // Left shoulder: cubic bezier tangent to left side (vertical) and top line (horizontal)
        p.addCurve(
            to: CGPoint(x: rect.minX - ext, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + ext * 0.35),
            control2: CGPoint(x: rect.minX - ext * 0.35, y: rect.minY)
        )
        p.closeSubpath()
        return p
    }
}

/// Collapsed single-line row for idle sessions >15 min
private struct TerminalJumpButton: View {
    let session: SessionSnapshot
    let sessionId: String
    @State private var hovering = false

    private let green = Color(red: 0.3, green: 0.85, blue: 0.4)

    /// Known bundle IDs for IDE/app sources
    private static let sourceBundleIds: [String: String] = [
        "cursor": "com.todesktop.230313mzl4w4u92",
        "qoder": "com.qoder.ide",
        "droid": "com.factory.app",
        "codebuddy": "com.tencent.codebuddy",
        "codex": "com.openai.codex",
        "opencode": "ai.opencode.desktop",
    ]

    private static var termIconCache: [String: NSImage] = [:]

    private var termIcon: NSImage? {
        let bid = session.termBundleId ?? Self.sourceBundleIds[session.source]
        guard let bid else { return nil }
        if let cached = Self.termIconCache[bid] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)
        else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        Self.termIconCache[bid] = icon
        return icon
    }

    var body: some View {
        Button {
            TerminalActivator.activate(session: session, sessionId: sessionId)
        } label: {
            HStack(spacing: 4) {
                if let icon = termIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 13, height: 13)
                }
                if let term = session.terminalName {
                    Text(term)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(green)
                }
                Image(systemName: "arrow.right")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(green.opacity(hovering ? 1.0 : 0.5))
                    .offset(x: hovering ? 2 : 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(green.opacity(hovering ? 0.18 : 0.08))
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.15)) { hovering = h }
        }
    }
}

// MARK: - Pixel Text (5×7 dot matrix style)

private struct PixelText: View {
    let text: String
    let color: Color
    var pixelSize: CGFloat = 2

    private static let W = 5  // glyph width
    private static let H = 7  // glyph height

    // 5×7 bitmaps — each row is 5 bits, 7 rows per glyph
    private static let glyphs: [Character: [UInt8]] = [
        "0": [0,1,1,1,0, 1,0,0,1,1, 1,0,1,0,1, 1,1,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "1": [0,0,1,0,0, 0,1,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "2": [0,1,1,1,0, 1,0,0,0,1, 0,0,1,1,0, 0,1,0,0,0, 1,1,1,1,1, 0,0,0,0,0, 0,0,0,0,0],
        "3": [0,1,1,1,0, 1,0,0,0,1, 0,0,1,1,0, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "4": [0,0,0,1,0, 0,0,1,1,0, 0,1,0,1,0, 1,1,1,1,1, 0,0,0,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "5": [1,1,1,1,1, 1,0,0,0,0, 1,1,1,1,0, 0,0,0,0,1, 1,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "6": [0,1,1,1,0, 1,0,0,0,0, 1,1,1,1,0, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "7": [1,1,1,1,1, 0,0,0,0,1, 0,0,0,1,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,0,0,0, 0,0,0,0,0],
        "8": [0,1,1,1,0, 1,0,0,0,1, 0,1,1,1,0, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "9": [0,1,1,1,0, 1,0,0,0,1, 0,1,1,1,1, 0,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "A": [0,0,1,0,0, 0,1,0,1,0, 1,0,0,0,1, 1,1,1,1,1, 1,0,0,0,1, 0,0,0,0,0, 0,0,0,0,0],
        "B": [1,1,1,1,0, 1,0,0,0,1, 1,1,1,1,0, 1,0,0,0,1, 1,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "C": [0,1,1,1,0, 1,0,0,0,1, 1,0,0,0,0, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "D": [1,1,1,1,0, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "E": [1,1,1,1,1, 1,0,0,0,0, 1,1,1,1,0, 1,0,0,0,0, 1,1,1,1,1, 0,0,0,0,0, 0,0,0,0,0],
        "F": [1,1,1,1,1, 1,0,0,0,0, 1,1,1,1,0, 1,0,0,0,0, 1,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0],
        "G": [0,1,1,1,0, 1,0,0,0,0, 1,0,0,1,1, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "H": [1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,1, 1,0,0,0,1, 1,0,0,0,1, 0,0,0,0,0, 0,0,0,0,0],
        "I": [0,1,1,1,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "K": [1,0,0,1,0, 1,0,1,0,0, 1,1,0,0,0, 1,0,1,0,0, 1,0,0,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "L": [1,0,0,0,0, 1,0,0,0,0, 1,0,0,0,0, 1,0,0,0,0, 1,1,1,1,1, 0,0,0,0,0, 0,0,0,0,0],
        "N": [1,0,0,0,1, 1,1,0,0,1, 1,0,1,0,1, 1,0,0,1,1, 1,0,0,0,1, 0,0,0,0,0, 0,0,0,0,0],
        "O": [0,1,1,1,0, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "P": [1,1,1,1,0, 1,0,0,0,1, 1,1,1,1,0, 1,0,0,0,0, 1,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0],
        "R": [1,1,1,1,0, 1,0,0,0,1, 1,1,1,1,0, 1,0,0,1,0, 1,0,0,0,1, 0,0,0,0,0, 0,0,0,0,0],
        "S": [0,1,1,1,1, 1,0,0,0,0, 0,1,1,1,0, 0,0,0,0,1, 1,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "T": [1,1,1,1,1, 0,0,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,0,0,0, 0,0,0,0,0],
        "U": [1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "W": [1,0,0,0,1, 1,0,0,0,1, 1,0,1,0,1, 1,0,1,0,1, 0,1,0,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "X": [1,0,0,0,1, 0,1,0,1,0, 0,0,1,0,0, 0,1,0,1,0, 1,0,0,0,1, 0,0,0,0,0, 0,0,0,0,0],
        "/": [0,0,0,0,1, 0,0,0,1,0, 0,0,1,0,0, 0,1,0,0,0, 1,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0],
        "-": [0,0,0,0,0, 0,0,0,0,0, 1,1,1,1,1, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0],
        " ": [0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0],
    ]

    var body: some View {
        let chars = Array(text.uppercased())
        let px = pixelSize
        let gap: CGFloat = px

        Canvas { ctx, size in
            var xOff: CGFloat = 0
            for ch in chars {
                guard let glyph = Self.glyphs[ch] else {
                    xOff += 3 * px
                    continue
                }
                for row in 0..<Self.H {
                    for col in 0..<Self.W {
                        if glyph[row * Self.W + col] == 1 {
                            let rect = CGRect(x: xOff + CGFloat(col) * px, y: CGFloat(row) * px, width: px, height: px)
                            ctx.fill(Path(rect), with: .color(color))
                        }
                    }
                }
                xOff += CGFloat(Self.W) * px + gap
            }
        }
        .frame(width: charWidth(chars.count), height: CGFloat(Self.H) * pixelSize)
    }

    private func charWidth(_ count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let px = pixelSize
        return CGFloat(count) * (CGFloat(Self.W) * px + px) - px
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - Shared Helpers

private let cliIconFiles: [String: String] = [
    "claude": "claude",
    "codex": "codex",
    "gemini": "gemini",
    "cursor": "cursor",
    "qoder": "qoder",
    "droid": "factory",
    "codebuddy": "codebuddy",
    "opencode": "opencode",
]

private var cliIconCache: [String: NSImage] = [:]

func cliIcon(source: String, size: CGFloat = 16) -> NSImage? {
    let key = "\(source)_\(Int(size))"
    if let cached = cliIconCache[key] { return cached }
    guard let filename = cliIconFiles[source],
          let url = Bundle.module.url(forResource: filename, withExtension: "png", subdirectory: "Resources/cli-icons"),
          let image = NSImage(contentsOf: url)
    else { return nil }
    image.size = NSSize(width: size, height: size)
    cliIconCache[key] = image
    return image
}

private struct SessionTag: View {
    let text: String
    var color: Color = .white.opacity(0.7)

    init(_ text: String, color: Color = .white.opacity(0.7)) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(color.opacity(0.12))
            )
    }
}

// MARK: - Typing Indicator (three bouncing dots)

private struct TypingIndicator: View {
    let fontSize: CGFloat
    var label: String? = nil
    @State private var phase: CGFloat = -60

    var body: some View {
        if let label {
            Text(label)
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.3), location: 0.4),
                            .init(color: .white.opacity(0.5), location: 0.5),
                            .init(color: .white.opacity(0.3), location: 0.6),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 60)
                    .offset(x: phase)
                    .mask(
                        Text(label)
                            .font(.system(size: fontSize, design: .monospaced))
                    )
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false)) {
                        phase = 80
                    }
                }
                .onDisappear { phase = -60 }
        }
    }
}

// MARK: - Mini Agent Icon (8-bit robot head)

struct MiniAgentIcon: View {
    let active: Bool
    var size: CGFloat = 12

    // 0=empty, 1=body, 2=eye, 3=antenna tip, 4=highlight, 5=shadow
    private let grid: [[Int]] = [
        [0, 0, 0, 3, 0, 0, 0],  // antenna tip (glows)
        [0, 0, 0, 1, 0, 0, 0],  // antenna stem
        [0, 4, 1, 1, 1, 5, 0],  // head top
        [0, 1, 2, 1, 2, 1, 0],  // eyes
        [0, 1, 1, 1, 1, 1, 0],  // face
        [0, 5, 1, 0, 1, 5, 0],  // mouth
        [0, 0, 1, 0, 1, 0, 0],  // legs
    ]

    var body: some View {
        let base = active ? Color.green : Color.gray
        let bright = active ? Color(red: 0.5, green: 1.0, blue: 0.5) : Color(white: 0.7)
        let dark = active ? Color(red: 0.1, green: 0.5, blue: 0.15) : Color(white: 0.35)
        let eye = active ? Color.white : Color(white: 0.85)
        let glow = active ? Color(red: 0.4, green: 1.0, blue: 0.4) : Color(white: 0.6)

        Canvas { ctx, sz in
            let px = sz.width / 7
            for row in 0..<7 {
                for col in 0..<7 {
                    let v = grid[row][col]
                    guard v != 0 else { continue }
                    let color: Color = switch v {
                    case 2: eye
                    case 3: glow
                    case 4: bright
                    case 5: dark
                    default: base
                    }
                    ctx.fill(
                        Path(CGRect(x: CGFloat(col) * px, y: CGFloat(row) * px, width: px, height: px)),
                        with: .color(color)
                    )
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: active ? .green.opacity(0.4) : .clear, radius: 2)
    }
}

// MARK: - Claude Logo (Compact Bar)

private struct ClaudeLogoCompact: View {
    var size: CGFloat = 22

    var body: some View {
        ClaudeLogoShape()
            .fill(Color(red: 0.85, green: 0.47, blue: 0.34))
            .frame(width: size, height: size)
    }
}

// MARK: - Lottie Animation Views

private struct LottieLoadingSpinner: View {
    var size: CGFloat = 16

    var body: some View {
        LottieView {
            try await DotLottieFile.named("loading", bundle: .module)
        }
        .playing(loopMode: .loop)
        .frame(width: size, height: size)
    }
}

private struct LottieTypingIndicator: View {
    var size: CGFloat = 16

    var body: some View {
        LottieView {
            if let file = try? await DotLottieFile.named("typing", bundle: .module) {
                return file
            }
            return try await DotLottieFile.named("loading", bundle: .module)
        }
        .playing(loopMode: .loop)
        .frame(width: size, height: size)
    }
}

// MARK: - Shared Helpers

/// Inline markdown rendering (bold, italic, code, links)
private var markdownCache: [String: AttributedString] = [:]
private let markdownCacheLimit = 128

private func inlineMarkdown(_ text: String) -> AttributedString {
    if let cached = markdownCache[text] { return cached }
    let result: AttributedString
    if let attr = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
        result = attr
    } else {
        result = AttributedString(text)
    }
    if markdownCache.count >= markdownCacheLimit {
        markdownCache.removeAll(keepingCapacity: true)
    }
    markdownCache[text] = result
    return result
}

/// Generate a short session ID with better disambiguation.
private func shortSessionId(_ id: String) -> String {
    let clean = id.replacingOccurrences(of: "-", with: "")
    if clean.count >= 8 {
        return String(clean.suffix(4))
    }
    return String(id.prefix(4))
}

/// Strip internal directives (::code-comment{}, ::git-*{}, etc.) from message text
/// so they don't leak into the UI preview.
private func stripDirectives(_ text: String) -> String {
    // Match ::directive-name{...} patterns (may span multiple lines)
    // Use a simple approach: remove lines that start with ::word{ or are continuation of a directive
    var result: [String] = []
    var inDirective = false
    var braceDepth = 0

    for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
        if inDirective {
            for ch in line {
                if ch == "{" { braceDepth += 1 }
                if ch == "}" { braceDepth -= 1 }
            }
            if braceDepth <= 0 {
                inDirective = false
                braceDepth = 0
            }
            continue
        }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("::") && trimmed.contains("{") {
            // Count braces to handle single-line vs multi-line directives
            braceDepth = 0
            for ch in line {
                if ch == "{" { braceDepth += 1 }
                if ch == "}" { braceDepth -= 1 }
            }
            if braceDepth > 0 {
                inDirective = true
            }
            // Either way, skip this line
            continue
        }
        result.append(String(line))
    }

    let cleaned = result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned
}

// MARK: - Notch Settings View (inline in the island)

private struct NotchSettingsView: View {
    var appState: AppState
    @ObservedObject private var l10n = L10n.shared

    // General
    @AppStorage(SettingsKey.appLanguage) private var appLanguage = "system"
    @AppStorage(SettingsKey.displayChoice) private var displayChoice = SettingsDefaults.displayChoice
    @State private var launchAtLogin: Bool = SettingsManager.shared.launchAtLogin

    // Behavior
    @AppStorage(SettingsKey.hideInFullscreen) private var hideInFullscreen = SettingsDefaults.hideInFullscreen
    @AppStorage(SettingsKey.hideWhenNoSession) private var hideWhenNoSession = SettingsDefaults.hideWhenNoSession
    @AppStorage(SettingsKey.smartSuppress) private var smartSuppress = SettingsDefaults.smartSuppress
    @AppStorage(SettingsKey.collapseOnMouseLeave) private var collapseOnMouseLeave = SettingsDefaults.collapseOnMouseLeave
    @AppStorage(SettingsKey.sessionTimeout) private var sessionTimeout = SettingsDefaults.sessionTimeout
    @AppStorage(SettingsKey.maxToolHistory) private var maxToolHistory = SettingsDefaults.maxToolHistory
    @AppStorage(SettingsKey.rotationInterval) private var rotationInterval = SettingsDefaults.rotationInterval

    // Appearance
    @AppStorage(SettingsKey.contentFontSize) private var contentFontSize = SettingsDefaults.contentFontSize
    @AppStorage(SettingsKey.maxVisibleSessions) private var maxVisibleSessions = SettingsDefaults.maxVisibleSessions
    @AppStorage(SettingsKey.aiMessageLines) private var aiMessageLines = SettingsDefaults.aiMessageLines
    @AppStorage(SettingsKey.showAgentDetails) private var showAgentDetails = SettingsDefaults.showAgentDetails
    @AppStorage(SettingsKey.mascotSpeed) private var mascotSpeed = SettingsDefaults.mascotSpeed

    // Sound
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = SettingsDefaults.soundEnabled
    @AppStorage(SettingsKey.soundVolume) private var soundVolume = SettingsDefaults.soundVolume
    @AppStorage(SettingsKey.soundSessionStart) private var soundSessionStart = SettingsDefaults.soundSessionStart
    @AppStorage(SettingsKey.soundTaskComplete) private var soundTaskComplete = SettingsDefaults.soundTaskComplete
    @AppStorage(SettingsKey.soundTaskError) private var soundTaskError = SettingsDefaults.soundTaskError
    @AppStorage(SettingsKey.soundApprovalNeeded) private var soundApprovalNeeded = SettingsDefaults.soundApprovalNeeded
    @AppStorage(SettingsKey.soundPromptSubmit) private var soundPromptSubmit = SettingsDefaults.soundPromptSubmit
    @AppStorage(SettingsKey.soundBoot) private var soundBoot = SettingsDefaults.soundBoot

    // Usage
    @AppStorage(SettingsKey.usageWarningThreshold) private var usageWarningThreshold = SettingsDefaults.usageWarningThreshold
    @AppStorage(SettingsKey.claudeApiKeyFiveHourLimit) private var apiKeyFhLimit = SettingsDefaults.claudeApiKeyFiveHourLimit
    @AppStorage(SettingsKey.claudeApiKeyWeeklyLimit) private var apiKeyWkLimit = SettingsDefaults.claudeApiKeyWeeklyLimit

    private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                headerBar

                // General
                SettingsSection(title: "通用") {
                    SettingsToggle(label: "开机自启", icon: "power", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, v in SettingsManager.shared.launchAtLogin = v }
                    SettingsOptionRow(label: "语言", icon: "globe", options: [("system", "系统"), ("en", "EN"), ("zh", "中文")], selection: $appLanguage)
                    DisplayPickerRow(selection: $displayChoice)
                }

                // Behavior
                SettingsSection(title: "行为") {
                    SettingsToggle(label: "全屏时隐藏", icon: "arrow.up.left.and.arrow.down.right", isOn: $hideInFullscreen)
                    SettingsToggle(label: "无会话时隐藏", icon: "eye.slash", isOn: $hideWhenNoSession)
                    SettingsToggle(label: "智能抑制", icon: "brain", isOn: $smartSuppress)
                    SettingsToggle(label: "鼠标离开收起", icon: "rectangle.compress.vertical", isOn: $collapseOnMouseLeave)
                    SettingsOptionRow(label: "会话超时", icon: "clock", options: [(0, "不清理"), (10, "10分"), (30, "30分"), (60, "1时"), (120, "2时")], selection: $sessionTimeout)
                    SettingsOptionRow(label: "工具历史", icon: "clock.arrow.circlepath", options: [(10, "10"), (20, "20"), (50, "50"), (100, "100")], selection: $maxToolHistory)
                    SettingsOptionRow(label: "轮转间隔", icon: "arrow.triangle.2.circlepath", options: [(3, "3s"), (5, "5s"), (8, "8s"), (10, "10s")], selection: $rotationInterval)
                }

                // Appearance
                SettingsSection(title: "外观") {
                    SettingsStepper(label: "最大会话数", value: $maxVisibleSessions, range: 1...20)
                    SettingsOptionRow(label: "字体大小", icon: "textformat.size", options: [(10, "10"), (11, "11"), (12, "12"), (13, "13")], selection: $contentFontSize)
                    SettingsOptionRow(label: "AI回复行数", icon: "text.alignleft", options: [(1, "1行"), (2, "2行"), (3, "3行"), (5, "5行"), (0, "∞")], selection: $aiMessageLines)
                    SettingsToggle(label: "显示 Agent 详情", icon: "info.circle", isOn: $showAgentDetails)
                    HStack(spacing: 10) {
                        Image(systemName: "hare")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 18)
                        Text("吉祥物速度")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        Text(mascotSpeed == 0 ? "关" : String(format: "%.1f×", Double(mascotSpeed) / 100.0))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(claudeOrange.opacity(0.7))
                            .frame(width: 36)
                    }
                    .frame(height: 30)
                    Slider(value: Binding(get: { Double(mascotSpeed) }, set: { mascotSpeed = Int($0) }), in: 0...300, step: 25)
                        .tint(claudeOrange)
                }

                // Sound
                SettingsSection(title: "音效") {
                    SettingsToggle(label: "启用音效", icon: soundEnabled ? "speaker.wave.2" : "speaker.slash", isOn: $soundEnabled)
                    if soundEnabled {
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.4))
                            Slider(value: Binding(get: { Double(soundVolume) }, set: { soundVolume = Int($0) }), in: 0...100)
                                .tint(claudeOrange)
                            Text("\(soundVolume)%")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 28)
                        }
                        .frame(height: 22)
                        SoundToggleRow(label: "启动音", icon: "play.circle", soundName: "8bit_boot", isOn: $soundBoot)
                        SoundToggleRow(label: "会话开始", icon: "play", soundName: "8bit_start", isOn: $soundSessionStart)
                        SoundToggleRow(label: "任务完成", icon: "checkmark.circle", soundName: "8bit_complete", isOn: $soundTaskComplete)
                        SoundToggleRow(label: "任务出错", icon: "exclamationmark.triangle", soundName: "8bit_error", isOn: $soundTaskError)
                        SoundToggleRow(label: "需要审批", icon: "hand.raised", soundName: "8bit_approval", isOn: $soundApprovalNeeded)
                        SoundToggleRow(label: "提交确认", icon: "paperplane", soundName: "8bit_submit", isOn: $soundPromptSubmit)
                    }
                }

                // Usage
                SettingsSection(title: "用量告警") {
                    HStack(spacing: 2) {
                        ForEach([0, 50, 70, 80, 90, 95], id: \.self) { pct in
                            let selected = usageWarningThreshold == pct
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { usageWarningThreshold = pct }
                            } label: {
                                Text(pct == 0 ? "Off" : "\(pct)%")
                                    .font(.system(size: 9, weight: selected ? .bold : .regular, design: .monospaced))
                                    .foregroundStyle(selected ? claudeOrange : .white.opacity(0.35))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(selected ? claudeOrange.opacity(0.15) : .clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider().background(.white.opacity(0.06))

                    UsageServiceListView()

                    let hasApiKey = UsageTracker.shared.services.contains { $0.planName == "API Key" }
                    if hasApiKey {
                        Divider().background(.white.opacity(0.06))
                        SettingsInput(label: "5h", value: $apiKeyFhLimit, unit: "tokens")
                        SettingsInput(label: "7d", value: $apiKeyWkLimit, unit: "tokens")
                    }
                }

                // Hooks
                SettingsSection(title: "Hooks") {
                    NotchHooksSection()
                }

                // About
                SettingsSection(title: "飞行员") {
                    HStack(spacing: 10) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 18)
                        Text("名字")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        TextField("", text: Binding(
                            get: { MembershipTracker.shared.pilotName },
                            set: { MembershipTracker.shared.pilotName = $0 }
                        ))
                        .font(.system(size: 11, design: .monospaced))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(claudeOrange)
                        .frame(width: 120)
                    }
                    .frame(height: 30)
                }

                SettingsSection(title: "关于") {
                    HStack(spacing: 12) {
                        AppLogoView(size: 40, showBackground: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Oh My Island")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                    }
                    .frame(height: 36)
                }

                // Actions
                SettingsSection(title: "") {
                    UpdateStatusRow()
                    SettingsActionButton(label: "退出", icon: "power", tint: Color(red: 1.0, green: 0.45, blue: 0.35)) {
                        NSApplication.shared.terminate(nil)
                    }
                }

                Spacer().frame(height: 4)
            }
        }
        .frame(maxHeight: 400)
    }

    private var headerBar: some View {
        HStack {
            Button {
                withAnimation(NotchAnimation.open) { appState.surface = .sessionList }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("返回")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(claudeOrange.opacity(0.7))
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(claudeOrange.opacity(0.6))
                Text("设置")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            Color.clear.frame(width: 50)
        }
        .padding(.bottom, 4)
    }
}

private struct NotchHooksSection: View {
    @State private var refreshKey = 0

    private let cliList: [(name: String, source: String)] = [
        ("Claude Code", "claude"),
        ("Codex", "codex"),
        ("Gemini", "gemini"),
        ("Cursor", "cursor"),
        ("Qoder", "qoder"),
        ("Factory", "droid"),
        ("CodeBuddy", "codebuddy"),
        ("OpenCode", "opencode"),
    ]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(cliList, id: \.source) { cli in
                let exists = ConfigInstaller.cliExists(source: cli.source)
                let installed = exists && ConfigInstaller.isInstalled(source: cli.source)
                let enabled = ConfigInstaller.isEnabled(source: cli.source)
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(exists: exists, installed: installed, enabled: enabled))
                        .frame(width: 6, height: 6)
                    Text(cli.name)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(exists ? 0.8 : 0.3))
                    Spacer()
                    Text(statusText(exists: exists, installed: installed, enabled: enabled))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(height: 18)
                .id("\(cli.source)-\(refreshKey)")
            }

            Divider().background(.white.opacity(0.06))

            HStack(spacing: 8) {
                SettingsActionButton(label: "重新安装", icon: "arrow.triangle.2.circlepath") {
                    for cli in ConfigInstaller.allCLIs where ConfigInstaller.cliExists(source: cli.source) {
                        UserDefaults.standard.set(true, forKey: "cli_enabled_\(cli.source)")
                    }
                    _ = ConfigInstaller.install()
                    refreshKey += 1
                }
                SettingsActionButton(label: "卸载", icon: "trash", tint: Color(red: 0.9, green: 0.3, blue: 0.3)) {
                    ConfigInstaller.uninstall()
                    refreshKey += 1
                }
            }
        }
    }

    private func statusColor(exists: Bool, installed: Bool, enabled: Bool) -> Color {
        if !exists { return .gray.opacity(0.4) }
        if !enabled { return .orange }
        if installed { return .green }
        return .yellow
    }

    private func statusText(exists: Bool, installed: Bool, enabled: Bool) -> String {
        if !exists { return "未检测" }
        if !enabled { return "已禁用" }
        if installed { return "已安装" }
        return "未安装"
    }
}

private struct SettingsOptionRow<T: Hashable>: View {
    let label: String
    let icon: String
    let options: [(T, String)]
    @Binding var selection: T

    private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            HStack(spacing: 2) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                    let selected = selection == opt.0
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selection = opt.0 }
                    } label: {
                        Text(opt.1)
                            .font(.system(size: 10, weight: selected ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(selected ? claudeOrange : .white.opacity(0.4))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(selected ? claudeOrange.opacity(0.15) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 30)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(claudeOrange.opacity(0.7))
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .padding(.leading, 4)
            }
            VStack(spacing: 4) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.04), lineWidth: 0.5)
                    )
            )
        }
    }
}

private struct SettingsToggle: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool

    private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isOn ? claudeOrange.opacity(0.8) : .white.opacity(0.4))
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(claudeOrange)
                .scaleEffect(0.7)
                .frame(width: 40)
        }
        .frame(height: 30)
        .contentShape(Rectangle())
    }
}

private struct SettingsStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.2)) { if value > range.lowerBound { value -= 1 } }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                Text("\(value)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(claudeOrange)
                    .frame(width: 30)
                Button {
                    withAnimation(.spring(response: 0.2)) { if value < range.upperBound { value += 1 } }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 30)
    }
}

private struct SettingsInput: View {
    let label: String
    @Binding var value: Int
    let unit: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 22, alignment: .leading)
            TextField("", value: $value, format: .number)
                .font(.system(size: 10, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.06)))
                .foregroundStyle(.white.opacity(0.7))
            Text(unit)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

private struct SettingsActionButton: View {
    let label: String
    let icon: String
    var tint: Color = Color(red: 0.85, green: 0.47, blue: 0.34)
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(tint.opacity(hovering ? 1.0 : 0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(hovering ? 0.18 : 0.1))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Update Status Row

private struct UpdateStatusRow: View {
    @ObservedObject private var checker = UpdateChecker.shared
    private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        VStack(spacing: 6) {
            switch checker.status {
            case .idle:
                SettingsActionButton(label: "检查更新", icon: "arrow.down.circle") {
                    checker.checkForUpdates(silent: false)
                }
            case .checking:
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("正在检查…")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(height: 30)
            case .upToDate(let version):
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Text("已是最新 v\(version)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button {
                        checker.status = .idle
                    } label: {
                        Text("关闭")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 30)
            case .available(let version, _):
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(claudeOrange)
                        Text("新版本 v\(version) 可用")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                    }
                    SettingsActionButton(label: "前往下载", icon: "safari") {
                        checker.openRelease()
                    }
                }
            case .failed(let msg):
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.yellow)
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Button {
                        checker.checkForUpdates(silent: false)
                    } label: {
                        Text("重试")
                            .font(.system(size: 10))
                            .foregroundStyle(claudeOrange)
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 30)
            }
        }
    }
}

// MARK: - Display Picker Row

private struct DisplayPickerRow: View {
    @Binding var selection: String
    private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    private var screenOptions: [(String, String)] {
        var opts: [(String, String)] = [("auto", "自动")]
        for (index, screen) in NSScreen.screens.enumerated() {
            let name = screen.localizedName
            let isBuiltin = name.contains("Built-in") || name.contains("内置")
            opts.append(("screen_\(index)", isBuiltin ? "内置" : name))
        }
        return opts
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "display")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 18)
            Text("显示器")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            HStack(spacing: 2) {
                ForEach(screenOptions, id: \.0) { tag, label in
                    let selected = selection == tag
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selection = tag }
                    } label: {
                        Text(label)
                            .font(.system(size: 10, weight: selected ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(selected ? claudeOrange : .white.opacity(0.4))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(selected ? claudeOrange.opacity(0.15) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 30)
    }
}

// MARK: - Sound Toggle with Preview Button

private struct SoundToggleRow: View {
    let label: String
    let icon: String
    let soundName: String
    @Binding var isOn: Bool
    private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isOn ? claudeOrange.opacity(0.8) : .white.opacity(0.4))
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Button {
                SoundManager.shared.preview(soundName)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .buttonStyle(.plain)
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(claudeOrange)
                .scaleEffect(0.7)
                .frame(width: 40)
        }
        .frame(height: 30)
        .contentShape(Rectangle())
    }
}

// MARK: - Usage Service List

private struct UsageServiceListView: View {
    private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 4) {
            let services = UsageTracker.shared.services
            if services.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("未检测到服务")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
                .frame(height: 24)
            } else {
                ForEach(services) { svc in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(svc.service.color)
                            .frame(width: 6, height: 6)
                        Text(svc.service.rawValue)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.8))
                        if let plan = svc.planName {
                            Text(plan)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        Spacer()
                        if let primary = svc.primaryUsage {
                            Text("\(primary.percentInt)%")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(svc.color)
                        }
                    }
                    .frame(height: 20)
                }
            }

            SettingsActionButton(label: isRefreshing ? "刷新中…" : "刷新用量", icon: "arrow.clockwise") {
                guard !isRefreshing else { return }
                isRefreshing = true
                Task {
                    await UsageTracker.shared.refresh()
                    isRefreshing = false
                }
            }
        }
    }
}
