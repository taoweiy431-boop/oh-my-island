import SwiftUI

// MARK: - Compact Usage Indicator (collapsed notch bar)

struct UsageMiniBar: View {
    let percent: Int
    let color: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.12))
                .frame(width: 30, height: 3)
            Capsule()
                .fill(color)
                .frame(width: max(2, 30 * CGFloat(min(percent, 100)) / 100), height: 3)
        }
        .shadow(color: color.opacity(percent >= 80 ? 0.6 : 0), radius: 3)
    }
}

// MARK: - Full Usage Panel (expanded notch view)

struct UsagePanelView: View {
    let info: UsageDisplayInfo
    @State private var pulseOpacity: Double = 1.0
    @State private var showSettings = false
    @AppStorage(SettingsKey.usageWarningThreshold) private var warningThreshold = SettingsDefaults.usageWarningThreshold
    @AppStorage(SettingsKey.claudeApiKeyFiveHourLimit) private var fiveHourLimit = SettingsDefaults.claudeApiKeyFiveHourLimit
    @AppStorage(SettingsKey.claudeApiKeyWeeklyLimit) private var weeklyLimit = SettingsDefaults.claudeApiKeyWeeklyLimit

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.85, green: 0.47, blue: 0.34))
                Text("用量监控")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showSettings.toggle() }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(showSettings ? 0.8 : 0.4))
                        .rotationEffect(.degrees(showSettings ? 90 : 0))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await UsageTracker.shared.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .rotationEffect(.degrees(UsageTracker.shared.isLoading ? 360 : 0))
                        .animation(
                            UsageTracker.shared.isLoading
                                ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                : .default,
                            value: UsageTracker.shared.isLoading
                        )
                }
                .buttonStyle(.plain)
            }

            let services = UsageTracker.shared.services
            if services.isEmpty && info.fiveHourPercent == nil && info.sevenDayPercent == nil {
                Text("无法获取用量数据")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.vertical, 8)
            } else if !services.isEmpty {
                ForEach(services) { svc in
                    ServiceRow(data: svc)
                    if svc.id != services.last?.id {
                        Divider()
                            .background(.white.opacity(0.06))
                    }
                }
            } else {
                if let fhPct = info.fiveHourPercent {
                    SimpleUsageRow(
                        label: "5小时", percent: fhPct, resetAt: info.fiveHourResetAt,
                        color: colorForPercent(fhPct), info: info
                    )
                }
                if let sdPct = info.sevenDayPercent {
                    SimpleUsageRow(
                        label: "7天", percent: sdPct, resetAt: info.sevenDayResetAt,
                        color: colorForPercent(sdPct), info: info
                    )
                }
            }

            if showSettings {
                Divider().background(.white.opacity(0.08))
                InlineSettingsSection(
                    warningThreshold: $warningThreshold,
                    fiveHourLimit: $fiveHourLimit,
                    weeklyLimit: $weeklyLimit
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(alertBorderColor, lineWidth: alertBorderWidth)
                .opacity(pulseOpacity)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseOpacity)
        )
        .onAppear {
            if info.maxPercent >= 80 { pulseOpacity = 0.3 }
        }
    }

    private var alertBorderColor: Color {
        let pct = info.maxPercent
        if pct >= 95 { return Color(red: 0.94, green: 0.27, blue: 0.27) }
        if pct >= 80 { return Color(red: 1.0, green: 0.6, blue: 0.2) }
        return .clear
    }

    private var alertBorderWidth: CGFloat {
        info.maxPercent >= 80 ? 1.0 : 0
    }

    private func colorForPercent(_ pct: Int) -> Color {
        if pct >= 90 { return Color(red: 0.94, green: 0.27, blue: 0.27) }
        if pct >= 70 { return Color(red: 1.0, green: 0.6, blue: 0.2) }
        return Color(red: 0.29, green: 0.87, blue: 0.5)
    }
}

// MARK: - Inline Settings (inside the island panel)

private struct InlineSettingsSection: View {
    @Binding var warningThreshold: Int
    @Binding var fiveHourLimit: Int
    @Binding var weeklyLimit: Int

    private let thresholdOptions = [0, 50, 70, 80, 90, 95]
    private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("告警")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                HStack(spacing: 2) {
                    ForEach(thresholdOptions, id: \.self) { pct in
                        let selected = warningThreshold == pct
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { warningThreshold = pct }
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
            }

            let hasApiKeyService = UsageTracker.shared.services.contains { $0.planName == "API Key" }
            if hasApiKeyService {
                Divider().background(.white.opacity(0.06))
                VStack(spacing: 6) {
                    HStack {
                        Text("API Key 限额")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                    LimitInputRow(label: "5h", value: $fiveHourLimit, placeholder: "5000000")
                    LimitInputRow(label: "7d", value: $weeklyLimit, placeholder: "50000000")
                }
            }
        }
    }
}

private struct LimitInputRow: View {
    let label: String
    @Binding var value: Int
    let placeholder: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 22, alignment: .leading)
            TextField(placeholder, value: $value, format: .number)
                .font(.system(size: 10, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.06))
                )
                .foregroundStyle(.white.opacity(0.7))
            Text("tokens")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// MARK: - Service Row (multi-service view)

private struct ServiceRow: View {
    let data: ServiceUsageData

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(data.isStale ? .gray : data.service.color)
                    .frame(width: 8, height: 8)
                Text(data.service.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(data.isStale ? 0.5 : 0.9))
                if data.isStale {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                        .help("离线 — 显示上次获取的数据")
                } else if let plan = data.planName {
                    Text(plan)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white.opacity(0.06))
                        )
                }
                Spacer()

                if let primary = data.primaryUsage {
                    ServiceMiniProgress(percent: primary.percentInt, color: data.color)
                }
            }

            if let primary = data.primaryUsage {
                MetricRow(
                    label: data.service.primaryLabel,
                    metric: primary,
                    color: usageColor(primary.percentInt)
                )
            }

            if let secondary = data.secondaryUsage, let secLabel = data.service.secondaryLabel {
                MetricRow(
                    label: secLabel,
                    metric: secondary,
                    color: usageColor(secondary.percentInt)
                )
            }

            if let rate = data.cacheHitRate, let hitColor = data.cacheHitColor {
                HStack(spacing: 4) {
                    Image(systemName: rate < 60 ? "exclamationmark.triangle.fill" : "memorychip")
                        .font(.system(size: 8))
                        .foregroundStyle(hitColor)
                    Text("Cache")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Text(String(format: "%.0f%%", rate))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(hitColor)
                }
                .help(data.cacheHitWarning ?? "缓存命中率良好")
            }
        }
        .padding(.vertical, 4)
    }

    private func usageColor(_ pct: Int) -> Color {
        if pct >= 90 { return Color(red: 0.94, green: 0.27, blue: 0.27) }
        if pct >= 70 { return Color(red: 1.0, green: 0.6, blue: 0.2) }
        return data.service.color
    }
}

private struct ServiceMiniProgress: View {
    let percent: Int
    let color: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.08))
                .frame(width: 60, height: 4)
            Capsule()
                .fill(color)
                .frame(width: max(1, 60 * CGFloat(min(percent, 100)) / 100), height: 4)
        }
    }
}

private struct MetricRow: View {
    let label: String
    let metric: UsageMetric
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 28, alignment: .leading)

            Text(metric.displayValue)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            if let resetTime = metric.resetTime {
                let remaining = resetTime.timeIntervalSinceNow
                if remaining > 0 {
                    Text(formatShortRemaining(remaining))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 7))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.horizontal, 2)
                }
            }

            Text("\(metric.percentInt)%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func formatShortRemaining(_ seconds: Double) -> String {
        if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else if seconds < 86400 {
            let h = Int(seconds / 3600)
            let m = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        let d = Int(seconds / 86400)
        let h = Int(seconds.truncatingRemainder(dividingBy: 86400) / 3600)
        return h > 0 ? "\(d)d \(h)h" : "\(d)d"
    }
}

// MARK: - Simple Usage Row (fallback when only legacy info available)

private struct SimpleUsageRow: View {
    let label: String
    let percent: Int
    let resetAt: Date?
    let color: Color
    let info: UsageDisplayInfo

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(2, geo.size.width * CGFloat(min(percent, 100)) / 100))
                        .shadow(color: color.opacity(0.4), radius: 4)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())

            if let resetAt = resetAt {
                let remaining = info.formatRemaining(resetAt)
                if !remaining.isEmpty {
                    HStack {
                        Spacer()
                        Text("\(remaining)后重置")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Multi-Service Panel") {
    UsagePanelView(info: UsageDisplayInfo(
        fiveHourPercent: 40,
        sevenDayPercent: 11,
        fiveHourResetAt: Date().addingTimeInterval(5760),
        sevenDayResetAt: Date().addingTimeInterval(277200)
    ))
    .frame(width: 400)
    .padding()
    .background(.black)
}

#Preview("UsageMiniBar") {
    HStack(spacing: 12) {
        UsageMiniBar(percent: 30, color: Color(red: 0.29, green: 0.87, blue: 0.5))
        UsageMiniBar(percent: 75, color: Color(red: 1.0, green: 0.6, blue: 0.2))
        UsageMiniBar(percent: 95, color: Color(red: 0.94, green: 0.27, blue: 0.27))
    }
    .padding()
    .background(.black)
}
