import AppKit
import SwiftUI

// MARK: - Popup Controller

@MainActor
final class MembershipCardPopupController {
    static let shared = MembershipCardPopupController()
    private var window: NSPanel?

    private static let cardWidth: CGFloat = 320
    private static let cardHeight: CGFloat = 420

    var isVisible: Bool { window != nil }

    func toggle() {
        if isVisible { dismiss(); return }
        show()
    }

    func show() {
        dismiss()

        let animState = CardAnimationState()
        let view = MembershipCardContent(animState: animState)
            .onTapGesture { }
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: Self.cardWidth, height: Self.cardHeight)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.cardWidth, height: Self.cardHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.contentView = hosting
        panel.isMovableByWindowBackground = true

        if let screen = NSScreen.main {
            let sx = (screen.frame.width - Self.cardWidth) / 2
            let sy = screen.frame.height - Self.cardHeight - 60
            panel.setFrame(NSRect(x: sx, y: sy, width: Self.cardWidth, height: Self.cardHeight), display: true)
        }

        panel.alphaValue = 0
        window = panel
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            animState.isPresented = true
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    func dismiss() {
        guard let panel = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor [weak self] in
                self?.window?.close()
                self?.window = nil
            }
        })
    }
}

// MARK: - Animation State

private class CardAnimationState: ObservableObject {
    @Published var isPresented = false
}

// MARK: - Card Content

private struct MembershipCardContent: View {
    @ObservedObject var animState: CardAnimationState
    @ObservedObject private var tracker = MembershipTracker.shared
    @State private var mascotBounce = false
    @State private var hoverLocation: CGPoint = .zero
    @State private var isHovering = false

    private let departureFont = "DepartureMono-Regular"

    private var tierColor: Color {
        let hex = tracker.currentTier.colorHex
        return Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    private var glowColor: Color {
        let hex = tracker.currentTier.glowHex
        return Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    private var tiltX: Double {
        guard isHovering else { return 0 }
        return (hoverLocation.y - 0.5) * -8
    }

    private var tiltY: Double {
        guard isHovering else { return 0 }
        return (hoverLocation.x - 0.5) * 8
    }

    var body: some View {
        VStack(spacing: 0) {
            topHalftone
            bottomInfo
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [tierColor.opacity(0.5), tierColor.opacity(0.15), tierColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isHovering ? 2.0 : 1.5
                )
        )
        .overlay(
            isHovering ?
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [tierColor.opacity(0.08), .clear],
                            center: UnitPoint(x: hoverLocation.x, y: hoverLocation.y),
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .allowsHitTesting(false)
            : nil
        )
        .rotation3DEffect(
            .degrees(tiltX),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.5
        )
        .rotation3DEffect(
            .degrees(tiltY),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .shadow(color: glowColor.opacity(isHovering ? 0.5 : 0.3), radius: isHovering ? 30 : 20, y: 8)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.08), value: hoverLocation.x)
        .animation(.easeOut(duration: 0.08), value: hoverLocation.y)
        .scaleEffect(animState.isPresented ? 1.0 : 0.6)
        .offset(y: animState.isPresented ? 0 : -40)
        .opacity(animState.isPresented ? 1 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.75, blendDuration: 0), value: animState.isPresented)
        .padding(16)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                isHovering = true
                let cardW: CGFloat = 288
                let cardH: CGFloat = 388
                hoverLocation = CGPoint(
                    x: min(1, max(0, location.x / cardW)),
                    y: min(1, max(0, location.y / cardH))
                )
            case .ended:
                isHovering = false
                hoverLocation = CGPoint(x: 0.5, y: 0.5)
            }
        }
        .onAppear {
            registerFont()
            withAnimation(.easeInOut(duration: 2).repeatForever()) {
                mascotBounce = true
            }
        }
    }

    // MARK: - Top: Halftone + Mascot

    private var topHalftone: some View {
        ZStack {
            Canvas { ctx, size in
                drawHalftone(ctx, size: size)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.03, blue: 0.15),
                        Color(red: 0.08, green: 0.05, blue: 0.22),
                        Color(red: 0.04, green: 0.02, blue: 0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            VStack(spacing: 0) {
                HStack {
                    Text("OH MY ISLAND")
                        .font(departure(size: 14))
                        .foregroundStyle(tierColor)
                        .kerning(1.5)
                    Spacer()
                    Text("[N]e-close")
                        .font(departure(size: 9))
                        .foregroundStyle(tierColor.opacity(0.5))
                        .onTapGesture {
                            MembershipCardPopupController.shared.dismiss()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer()

                MascotView(source: "claude", status: .idle, size: 42)
                    .offset(y: mascotBounce ? -4 : 4)

                Spacer()
            }
        }
        .frame(height: 200)
    }

    // MARK: - Bottom: Info

    private var bottomInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(tracker.currentTier.title)
                    .font(departure(size: 24))
                    .foregroundStyle(tierColor)
                Spacer()
                Text(tracker.currentTier.badge)
                    .font(.system(size: 16))
                    .foregroundStyle(tierColor)
            }
            .padding(.top, 14)

            Text(tracker.currentTier.subtitle)
                .font(departure(size: 10))
                .foregroundStyle(.white.opacity(0.3))
                .kerning(2)
                .padding(.top, 2)

            Spacer().frame(height: 16)

            infoRow("PILOT", value: tracker.pilotName)
            infoRow("STATUS", value: "ACTIVE", highlight: true)
            infoRow("JOINED", value: formatDate(tracker.joinDate))
            infoRow("TIME", value: tracker.formattedTime)
            infoRow("SESSIONS", value: "\(tracker.totalSessions)")
            infoRow("PROMPTS", value: "\(tracker.totalPrompts)")

            if let next = tracker.nextTier {
                Spacer().frame(height: 12)
                progressBar(to: next)
            }

            Spacer().frame(height: 14)

            dottedLine

            HStack {
                Text("OH MY ISLAND  #  V\(tracker.currentTier.level)")
                    .font(departure(size: 8))
                    .foregroundStyle(.white.opacity(0.18))
                Spacer()
                Text("WELCOME ABOARD")
                    .font(departure(size: 8))
                    .foregroundStyle(.white.opacity(0.18))
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 18)
        .background(Color(red: 0.06, green: 0.04, blue: 0.10))
    }

    // MARK: - Halftone

    private func drawHalftone(_ ctx: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 7
        let maxR: CGFloat = 3.2
        let cx = size.width / 2
        let cy = size.height / 2
        let maxDist = sqrt(cx * cx + cy * cy)

        var y: CGFloat = 0
        while y < size.height {
            var x: CGFloat = 0
            while x < size.width {
                let dist = sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy))
                let norm = 1.0 - min(dist / maxDist, 1.0)
                let r = maxR * norm * norm * norm
                if r > 0.3 {
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    ctx.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color(
                            red: 0.15 + norm * 0.15,
                            green: 0.10 + norm * 0.20,
                            blue: 0.45 + norm * 0.30
                        ).opacity(0.55 * norm))
                    )
                }
                x += spacing
            }
            y += spacing
        }
    }

    // MARK: - Info Row

    private func infoRow(_ label: String, value: String, highlight: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(departure(size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 60, alignment: .leading)
            Text(">")
                .font(departure(size: 11))
                .foregroundStyle(tierColor.opacity(0.5))
            if highlight {
                Text(value)
                    .font(departure(size: 11))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(tierColor.opacity(0.25))
                    )
            } else {
                Text(value)
                    .font(departure(size: 11))
                    .foregroundStyle(tierColor)
            }
            Spacer()
        }
        .padding(.vertical, 1)
    }

    // MARK: - Progress

    private func progressBar(to next: MembershipTier) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("NEXT: \(next.title)")
                    .font(departure(size: 9))
                    .foregroundStyle(.white.opacity(0.3))
                Spacer()
                let remaining = next.requiredMinutes - tracker.totalMinutes
                let h = remaining / 60
                let m = remaining % 60
                Text(h > 0 ? "\(h)h \(m)m left" : "\(m)m left")
                    .font(departure(size: 9))
                    .foregroundStyle(.white.opacity(0.25))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [tierColor.opacity(0.4), tierColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(2, geo.size.width * tracker.progressToNext))
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Dotted Line

    private var dottedLine: some View {
        GeometryReader { geo in
            Path { path in
                let y = geo.size.height / 2
                var x: CGFloat = 0
                while x < geo.size.width {
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + 3, y: y))
                    x += 6
                }
            }
            .stroke(tierColor.opacity(0.2), lineWidth: 1)
        }
        .frame(height: 1)
    }

    // MARK: - Helpers

    private func departure(size: CGFloat) -> Font {
        .custom(departureFont, size: size)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: date)
    }

    private func registerFont() {
        guard let url = Bundle.module.url(forResource: "DepartureMono-Regular", withExtension: "otf", subdirectory: "Resources")
                ?? Bundle.module.url(forResource: "DepartureMono-Regular", withExtension: "otf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

// MARK: - Inline Panel Card (kept for notch panel)

struct MembershipCardView: View {
    @ObservedObject private var tracker = MembershipTracker.shared
    @State private var mascotBounce: Bool = false

    private var tierColor: Color {
        let hex = tracker.currentTier.colorHex
        return Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                MascotView(source: "claude", status: .idle, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(tracker.currentTier.title)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(tierColor)
                        Text("Lv.\(tracker.currentTier.level)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(tierColor.opacity(0.6))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3).fill(tierColor.opacity(0.12)))
                    }
                    Text("\(tracker.formattedTime) · \(tracker.currentTier.subtitle)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
                Spacer()
                Button {
                    MembershipCardPopupController.shared.show()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 12))
                        .foregroundStyle(tierColor.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            if let next = tracker.nextTier {
                HStack(spacing: 6) {
                    Text("NEXT: \(next.title)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 2).fill(tierColor.opacity(0.5))
                                .frame(width: max(2, geo.size.width * tracker.progressToNext))
                        }
                    }
                    .frame(height: 3)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tierColor.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}
