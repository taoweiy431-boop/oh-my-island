import Lottie
import SwiftUI
import CodeIslandCore

// MARK: - Mascot Animation Speed Environment

private struct MascotSpeedKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

extension EnvironmentValues {
    var mascotSpeed: Double {
        get { self[MascotSpeedKey.self] }
        set { self[MascotSpeedKey.self] = newValue }
    }
}

/// Routes a CLI source identifier to the correct mascot view.
/// Uses Clawd Lottie animations with agent-specific color tinting.
struct MascotView: View {
    let source: String
    let status: AgentStatus
    var size: CGFloat = 27
    @AppStorage(SettingsKey.mascotSpeed) private var speedPct = SettingsDefaults.mascotSpeed

    private var useLottie: Bool { speedPct > 0 }

    private var resolved: (palette: ClawdPalette, accessory: ClawdAccessory) {
        switch source {
        case "claude":    return (.claude, .bowTie)
        case "cursor":    return (.cursor, .necktie)
        case "gemini":    return (.gemini, .bowTie)
        case "codex":     return (.codex, .necktie)
        case "qoder":     return (.qoder, .bowTie)
        case "droid":     return (.droid, .necktie)
        case "codebuddy": return (.codebuddy, .bowTie)
        case "opencode":  return (.opencode, .necktie)
        default:          return (.claude, .none)
        }
    }

    var body: some View {
        if useLottie {
            ClawdLottieMascot(source: source, status: status, size: size)
        } else {
            ClawdView(status: status, size: size,
                      palette: resolved.palette, accessory: resolved.accessory)
                .environment(\.mascotSpeed, 0)
        }
    }
}

// MARK: - Clawd Lottie Mascot

private struct ClawdLottieMascot: View {
    let source: String
    let status: AgentStatus
    var size: CGFloat = 27

    private var lottieName: String {
        switch status {
        case .processing, .running: return "clawd-working"
        case .waitingApproval:      return "clawd-question"
        case .waitingQuestion:      return "clawd-idea"
        case .idle:                 return "clawd-idle"
        }
    }

    private var tintColor: Color {
        switch source {
        case "claude":    return Color(red: 0.85, green: 0.47, blue: 0.34)
        case "cursor":    return Color(red: 0.55, green: 0.55, blue: 0.60)
        case "gemini":    return Color(red: 0.278, green: 0.588, blue: 0.894)
        case "codex":     return Color(red: 0.70, green: 0.70, blue: 0.72)
        case "qoder":     return Color(red: 0.165, green: 0.859, blue: 0.361)
        case "droid":     return Color(red: 0.835, green: 0.416, blue: 0.149)
        case "codebuddy": return Color(red: 0.424, green: 0.302, blue: 1.0)
        case "opencode":  return Color(red: 0.55, green: 0.55, blue: 0.57)
        default:          return Color(red: 0.85, green: 0.47, blue: 0.34)
        }
    }

    private var needsTint: Bool { source != "claude" }

    var body: some View {
        LottieView {
            try await DotLottieFile.named(lottieName, bundle: .module)
        }
        .playing(loopMode: .loop)
        .frame(width: size * 1.6, height: size * 1.6)
        .frame(width: size, height: size)
        .clipped()
        .id("\(source)-\(lottieName)")
    }
}

// MARK: - Lottie Mascot (legacy fallback)

private struct LottieMascotView: View {
    let status: AgentStatus
    var size: CGFloat = 27

    private var lottieName: String {
        switch status {
        case .processing, .running: return "mascot-working"
        case .waitingApproval:      return "mascot-question"
        case .waitingQuestion:      return "mascot-idea"
        case .idle:                 return "mascot-idle"
        }
    }

    var body: some View {
        LottieView {
            try await DotLottieFile.named(lottieName, bundle: .module)
        }
        .playing(loopMode: .loop)
        .frame(width: size, height: size)
        .id(lottieName)
    }
}
