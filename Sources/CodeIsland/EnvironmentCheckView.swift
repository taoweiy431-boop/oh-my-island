import SwiftUI

struct EnvironmentCheckView: View {
    @ObservedObject private var checker = EnvironmentChecker.shared
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        VStack(spacing: 10) {
            header
            if checker.isChecking {
                loadingView
            } else if let report = checker.report {
                reportView(report)
            } else {
                emptyView
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "shield.checkered")
                .font(.system(size: 11))
                .foregroundStyle(headerColor)
            Text("环境安全检测")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Button {
                Task { await checker.runAllChecks() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .rotationEffect(.degrees(checker.isChecking ? 360 : 0))
                    .animation(
                        checker.isChecking
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: checker.isChecking
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var headerColor: Color {
        guard let report = checker.report else {
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        }
        return riskColor(report.overallRisk)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
            Text("正在检测环境安全…")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, 12)
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.3))
            Text("点击刷新按钮开始检测")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.vertical, 12)
        .task {
            await checker.runAllChecks()
        }
    }

    // MARK: - Report

    private func reportView(_ report: EnvironmentReport) -> some View {
        VStack(spacing: 8) {
            summaryBar(report)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 6) {
                    ForEach(report.grouped, id: \.0) { category, items in
                        categorySection(category: category, items: items)
                    }
                }
            }
            .frame(maxHeight: 340)

            footerBar(report)
        }
    }

    // MARK: - Summary Bar

    private func summaryBar(_ report: EnvironmentReport) -> some View {
        HStack(spacing: 12) {
            summaryBadge(count: report.highRiskCount, label: "风险", color: .red)
            summaryBadge(count: report.results.filter { $0.risk == .medium }.count, label: "注意", color: .yellow)
            summaryBadge(count: report.safeCount, label: "安全", color: .green)
            Spacer()
            Text(overallLabel(report.overallRisk))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(riskColor(report.overallRisk))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(riskColor(report.overallRisk).opacity(0.15))
                .clipShape(Capsule())
        }
    }

    private func summaryBadge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Category Section

    private func categorySection(category: String, items: [CheckResult]) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if expandedCategories.contains(category) {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: categoryIcon(category))
                        .font(.system(size: 9))
                        .foregroundStyle(categoryColor(category, items: items))
                        .frame(width: 14)
                    Text(category)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    let worst = items.map(\.risk).max() ?? .safe
                    if worst >= .medium {
                        riskPill(worst)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                        .rotationEffect(.degrees(expandedCategories.contains(category) ? 90 : 0))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            if expandedCategories.contains(category) {
                VStack(spacing: 2) {
                    ForEach(items) { item in
                        checkRow(item)
                    }
                }
                .padding(.leading, 14)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    // MARK: - Check Row

    private func checkRow(_ item: CheckResult) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: item.risk.icon)
                    .font(.system(size: 8))
                    .foregroundStyle(riskColor(item.risk))
                    .frame(width: 12)
                Text(item.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                riskPill(item.risk)
            }

            Text(item.detail)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(2)
                .padding(.leading, 17)

            if let suggestion = item.suggestion {
                Text(suggestion)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(3)
                    .padding(.leading, 17)
                    .padding(.top, 1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    // MARK: - Footer

    private func footerBar(_ report: EnvironmentReport) -> some View {
        HStack {
            Text("检测于 \(report.timestamp.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
            Spacer()
            Text("基于 Claude Code 源码分析")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Helpers

    private func riskPill(_ risk: RiskLevel) -> some View {
        Text(risk.rawValue)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(riskColor(risk))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(riskColor(risk).opacity(0.12))
            .clipShape(Capsule())
    }

    private func riskColor(_ risk: RiskLevel) -> Color {
        switch risk {
        case .safe: return .green
        case .info: return .blue
        case .low: return .gray
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    private func overallLabel(_ risk: RiskLevel) -> String {
        switch risk {
        case .safe: return "全部安全"
        case .info: return "基本安全"
        case .low: return "低风险"
        case .medium: return "需注意"
        case .high: return "存在风险"
        case .critical: return "高度危险"
        }
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "身份": return "person.fill"
        case "网络": return "network"
        case "环境": return "desktopcomputer"
        case "遥测": return "antenna.radiowaves.left.and.right"
        case "凭据": return "key.fill"
        case "客户端": return "app.badge"
        default: return "questionmark.circle"
        }
    }

    private func categoryColor(_ category: String, items: [CheckResult]) -> Color {
        let worst = items.map(\.risk).max() ?? .safe
        return riskColor(worst)
    }
}
