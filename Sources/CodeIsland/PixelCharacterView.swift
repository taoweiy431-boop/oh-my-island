import SwiftUI
import CodeIslandCore

// MARK: - Configurable Palette & Accessory

struct ClawdPalette {
    let body: Color
    let bodyHighlight: Color
    let eye: Color
    let alert: Color
    let blush: Color
    let accessory: Color
    let kbBase: Color
    let kbKey: Color
    let kbHighlight: Color
    let sparkle: Color

    static let claude = ClawdPalette(
        body:          Color(red: 0.85, green: 0.47, blue: 0.34),  // #D97857
        bodyHighlight: Color(red: 0.95, green: 0.65, blue: 0.50),
        eye:           Color(red: 0.20, green: 0.12, blue: 0.08),
        alert:         Color(red: 1.0, green: 0.30, blue: 0.15),
        blush:         Color(red: 0.95, green: 0.55, blue: 0.40),
        accessory:     Color(red: 0.90, green: 0.25, blue: 0.20),
        kbBase:        Color(red: 0.38, green: 0.30, blue: 0.25),
        kbKey:         Color(red: 0.60, green: 0.50, blue: 0.42),
        kbHighlight:   .white,
        sparkle:       .white
    )

    static let cursor = ClawdPalette(
        body:          Color(red: 0.15, green: 0.14, blue: 0.12),  // dark
        bodyHighlight: Color(red: 0.30, green: 0.28, blue: 0.24),
        eye:           Color(red: 0.93, green: 0.93, blue: 0.93),  // light eyes on dark body
        alert:         Color(red: 1.0, green: 0.24, blue: 0.0),
        blush:         Color(red: 0.35, green: 0.32, blue: 0.28),
        accessory:     Color(red: 0.93, green: 0.93, blue: 0.93),  // white tie
        kbBase:        Color(red: 0.12, green: 0.11, blue: 0.08),
        kbKey:         Color(red: 0.30, green: 0.28, blue: 0.22),
        kbHighlight:   Color(red: 0.93, green: 0.93, blue: 0.93),
        sparkle:       Color(red: 0.93, green: 0.93, blue: 0.93)
    )

    static let gemini = ClawdPalette(
        body:          Color(red: 0.518, green: 0.478, blue: 0.808), // #847ACE purple
        bodyHighlight: Color(red: 0.65, green: 0.60, blue: 0.90),
        eye:           Color.white,
        alert:         Color(red: 0.765, green: 0.404, blue: 0.498), // rose
        blush:         Color(red: 0.65, green: 0.55, blue: 0.85),
        accessory:     Color(red: 0.278, green: 0.588, blue: 0.894), // blue bow
        kbBase:        Color(red: 0.22, green: 0.25, blue: 0.38),
        kbKey:         Color(red: 0.40, green: 0.44, blue: 0.58),
        kbHighlight:   .white,
        sparkle:       Color(red: 0.765, green: 0.404, blue: 0.498)
    )

    static let codex = ClawdPalette(
        body:          Color(red: 0.92, green: 0.92, blue: 0.93),  // off-white
        bodyHighlight: .white,
        eye:           .black,
        alert:         Color(red: 1.0, green: 0.55, blue: 0.0),    // amber
        blush:         Color(red: 0.85, green: 0.85, blue: 0.87),
        accessory:     Color(red: 0.25, green: 0.25, blue: 0.28),  // dark tie
        kbBase:        Color(red: 0.18, green: 0.18, blue: 0.20),
        kbKey:         Color(red: 0.40, green: 0.40, blue: 0.42),
        kbHighlight:   .white,
        sparkle:       Color(red: 0.70, green: 0.70, blue: 0.72)
    )

    static let qoder = ClawdPalette(
        body:          Color(red: 0.165, green: 0.859, blue: 0.361), // #2ADB5C lime
        bodyHighlight: Color(red: 0.30, green: 0.95, blue: 0.50),
        eye:           .black,
        alert:         Color(red: 1.0, green: 0.24, blue: 0.0),
        blush:         Color(red: 0.20, green: 0.75, blue: 0.38),
        accessory:     Color(red: 0.08, green: 0.50, blue: 0.20),   // dark green bow
        kbBase:        Color(red: 0.10, green: 0.18, blue: 0.12),
        kbKey:         Color(red: 0.20, green: 0.38, blue: 0.24),
        kbHighlight:   Color(red: 0.165, green: 0.859, blue: 0.361),
        sparkle:       Color(red: 0.30, green: 0.95, blue: 0.50)
    )

    static let droid = ClawdPalette(
        body:          Color(red: 0.835, green: 0.416, blue: 0.149), // #D56A26 rust
        bodyHighlight: Color(red: 0.92, green: 0.55, blue: 0.25),
        eye:           Color(red: 0.89, green: 0.60, blue: 0.16),   // gold eyes
        alert:         Color(red: 1.0, green: 0.24, blue: 0.0),
        blush:         Color(red: 0.75, green: 0.40, blue: 0.15),
        accessory:     Color(red: 0.20, green: 0.18, blue: 0.15),   // dark tie
        kbBase:        Color(red: 0.15, green: 0.13, blue: 0.12),
        kbKey:         Color(red: 0.32, green: 0.28, blue: 0.25),
        kbHighlight:   Color(red: 0.835, green: 0.416, blue: 0.149),
        sparkle:       Color(red: 0.89, green: 0.60, blue: 0.16)
    )

    static let codebuddy = ClawdPalette(
        body:          Color(red: 0.424, green: 0.302, blue: 1.0),  // #6C4DFF purple
        bodyHighlight: Color(red: 0.55, green: 0.45, blue: 1.0),
        eye:           Color(red: 0.196, green: 0.902, blue: 0.725), // cyan-green
        alert:         Color(red: 1.0, green: 0.24, blue: 0.0),
        blush:         Color(red: 0.50, green: 0.38, blue: 0.90),
        accessory:     Color(red: 0.196, green: 0.902, blue: 0.725), // cyan bow
        kbBase:        Color(red: 0.18, green: 0.15, blue: 0.30),
        kbKey:         Color(red: 0.35, green: 0.30, blue: 0.55),
        kbHighlight:   Color(red: 0.196, green: 0.902, blue: 0.725),
        sparkle:       Color(red: 0.196, green: 0.902, blue: 0.725)
    )

    static let opencode = ClawdPalette(
        body:          Color(red: 0.22, green: 0.22, blue: 0.24),   // #383838
        bodyHighlight: Color(red: 0.35, green: 0.35, blue: 0.37),
        eye:           Color(red: 0.85, green: 0.85, blue: 0.87),   // light face
        alert:         Color(red: 1.0, green: 0.55, blue: 0.0),
        blush:         Color(red: 0.30, green: 0.30, blue: 0.32),
        accessory:     Color(red: 0.55, green: 0.55, blue: 0.57),   // gray tie
        kbBase:        Color(red: 0.12, green: 0.12, blue: 0.14),
        kbKey:         Color(red: 0.30, green: 0.30, blue: 0.32),
        kbHighlight:   .white,
        sparkle:       Color(red: 0.55, green: 0.55, blue: 0.57)
    )
}

enum ClawdAccessory {
    case bowTie
    case necktie
    case none
}

// MARK: - ClawdView

/// Clawd — universal pixel mascot with configurable palette and accessory.
struct ClawdView: View {
    let status: AgentStatus
    var size: CGFloat = 27
    var palette: ClawdPalette = .claude
    var accessory: ClawdAccessory = .bowTie
    @State private var alive = false
    @Environment(\.mascotSpeed) private var speed

    var body: some View {
        ZStack {
            switch status {
            case .idle:                 sleepScene
            case .processing, .running: workScene
            case .waitingApproval, .waitingQuestion: alertScene
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .onAppear { alive = true }
        .onChange(of: status) {
            alive = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { alive = true }
        }
    }

    private struct V {
        let ox: CGFloat, oy: CGFloat, s: CGFloat
        let y0: CGFloat

        init(_ sz: CGSize, svgW: CGFloat = 15, svgH: CGFloat = 10, svgY0: CGFloat = 6) {
            s = min(sz.width / svgW, sz.height / svgH)
            ox = (sz.width - svgW * s) / 2
            oy = (sz.height - svgH * s) / 2
            y0 = svgY0
        }
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, dy: CGFloat = 0) -> CGRect {
            CGRect(x: ox + x * s, y: oy + (y - y0 + dy) * s, width: w * s, height: h * s)
        }
    }

    // MARK: - Accessory Drawing

    private func drawAccessory(_ c: GraphicsContext, v: V, dy: CGFloat) {
        switch accessory {
        case .bowTie:
            drawBowTie(c, v: v, dy: dy)
        case .necktie:
            drawNecktie(c, v: v, dy: dy)
        case .none:
            break
        }
    }

    private func drawBowTie(_ c: GraphicsContext, v: V, dy: CGFloat) {
        let cx: CGFloat = 7.5
        let ac = palette.accessory
        c.fill(Path(v.r(cx - 3, 12.5, 2.5, 0.5, dy: dy)), with: .color(ac))
        c.fill(Path(v.r(cx - 2.5, 12, 2, 1.5, dy: dy)), with: .color(ac))
        c.fill(Path(v.r(cx + 0.5, 12.5, 2.5, 0.5, dy: dy)), with: .color(ac))
        c.fill(Path(v.r(cx + 0.5, 12, 2, 1.5, dy: dy)), with: .color(ac))
        c.fill(Path(v.r(cx - 0.5, 12.2, 1, 1.1, dy: dy)), with: .color(ac.opacity(0.7)))
    }

    private func drawNecktie(_ c: GraphicsContext, v: V, dy: CGFloat) {
        let ac = palette.accessory
        c.fill(Path(v.r(7, 12, 1, 0.7, dy: dy)), with: .color(ac))
        c.fill(Path(v.r(6.5, 12.5, 2, 1.2, dy: dy)), with: .color(ac))
        c.fill(Path(v.r(6.8, 13.5, 1.4, 0.8, dy: dy)), with: .color(ac))
        c.fill(Path(v.r(7.2, 12.3, 0.5, 1.8, dy: dy)), with: .color(palette.bodyHighlight.opacity(0.25)))
    }

    // MARK: - Arm rotation

    private func armPath(_ v: V, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                         pivotX: CGFloat, pivotY: CGFloat, angle: CGFloat, dy: CGFloat) -> Path {
        let a = angle * .pi / 180
        let ca = cos(a), sa = sin(a)
        let corners: [(CGFloat, CGFloat)] = [
            (x - pivotX, y - pivotY),
            (x + w - pivotX, y - pivotY),
            (x + w - pivotX, y + h - pivotY),
            (x - pivotX, y + h - pivotY),
        ]
        var path = Path()
        for (i, (cx, cy)) in corners.enumerated() {
            let rx = cx * ca - cy * sa + pivotX
            let ry = cx * sa + cy * ca + pivotY
            let pt = CGPoint(x: v.ox + rx * v.s, y: v.oy + (ry - v.y0 + dy) * v.s)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Sleeping

    private func drawSleeping(_ ctx: GraphicsContext, v: V, breathe: CGFloat) {
        let shadowScale: CGFloat = 1.0 + breathe * 0.03
        ctx.fill(Path(v.r(-1, 15, 17 * shadowScale, 1)),
                 with: .color(.black.opacity(0.35 + breathe * 0.08)))

        for x: CGFloat in [3, 5, 9, 11] {
            ctx.fill(Path(v.r(x, 8.5, 1, 1.5)), with: .color(palette.body))
        }

        let puff = max(0, breathe) * 0.25
        let torsoH: CGFloat = 5 * (1.0 + puff)
        let torsoY: CGFloat = 15 - torsoH
        let torsoW: CGFloat = 13 * (1.0 + breathe * 0.015)
        let torsoX: CGFloat = 1 - (torsoW - 13) / 2
        ctx.fill(Path(v.r(torsoX, torsoY, torsoW, torsoH)), with: .color(palette.body))
        ctx.fill(Path(v.r(torsoX + 2, torsoY + 1, torsoW - 4, 1.5)),
                 with: .color(palette.bodyHighlight.opacity(0.4)))

        ctx.fill(Path(v.r(-1, 13, 2, 2)), with: .color(palette.body))
        ctx.fill(Path(v.r(14, 13, 2, 2)), with: .color(palette.body))

        let eyeY: CGFloat = 12.2 - puff * 2.5
        ctx.fill(Path(v.r(1.5, eyeY + 1.2, 1.5, 1.0)), with: .color(palette.blush.opacity(0.35)))
        ctx.fill(Path(v.r(12.0, eyeY + 1.2, 1.5, 1.0)), with: .color(palette.blush.opacity(0.35)))
        ctx.fill(Path(v.r(3, eyeY, 2.5, 1.0)), with: .color(palette.eye))
        ctx.fill(Path(v.r(9.5, eyeY, 2.5, 1.0)), with: .color(palette.eye))
    }

    // MARK: - Sleep Scene

    private var sleepScene: some View {
        ZStack {
            TimelineView(.periodic(from: .now, by: 0.06)) { ctx in
                sleepCanvas(t: ctx.date.timeIntervalSinceReferenceDate * speed)
            }
            TimelineView(.periodic(from: .now, by: 0.05)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate * speed
                ZStack {
                    floatingZs(t: t)
                    floatingSparkles(t: t)
                }
            }
        }
    }

    private func floatingZs(t: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let ci = Double(i)
                let cycle = 2.8 + ci * 0.3
                let delay = ci * 0.9
                let phase = max(0, ((t - delay).truncatingRemainder(dividingBy: cycle)) / cycle)
                let fontSize = max(6, size * CGFloat(0.18 + phase * 0.10))
                let baseOp = 0.7 - ci * 0.1
                let opacity = phase < 0.8 ? baseOp : (1.0 - phase) * 3.5 * baseOp
                let xOff = size * CGFloat(0.08 + ci * 0.06 + sin(phase * .pi * 2) * 0.03)
                let yOff = -size * CGFloat(0.15 + phase * 0.38)
                Text("z")
                    .font(.system(size: fontSize, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(opacity))
                    .offset(x: xOff, y: yOff)
            }
        }
    }

    private func floatingSparkles(t: Double) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let ci = Double(i)
                let cycle = 3.5 + ci * 0.4
                let delay = ci * 0.7 + 0.3
                let phase = max(0, ((t - delay).truncatingRemainder(dividingBy: cycle)) / cycle)
                let sparkleSize = max(3, size * CGFloat(0.06 + phase * 0.04))
                let opacity = phase < 0.7 ? (0.5 + sin(phase * .pi * 4) * 0.3) : (1.0 - phase) * 2.5
                let angles: [CGFloat] = [-0.2, 0.15, -0.1, 0.25]
                let xOff = size * CGFloat(angles[i] + sin(phase * .pi) * 0.05)
                let yOff = -size * CGFloat(0.1 + phase * 0.35)
                Text("\u{2726}")
                    .font(.system(size: sparkleSize))
                    .foregroundStyle(palette.sparkle.opacity(max(0, opacity)))
                    .offset(x: xOff, y: yOff)
            }
        }
    }

    private func sleepCanvas(t: Double) -> some View {
        let phase = t.truncatingRemainder(dividingBy: 4.5) / 4.5
        let breathe: CGFloat = phase < 0.4 ? sin(phase / 0.4 * .pi) : 0
        return Canvas { c, sz in
            let v = V(sz, svgW: 17, svgH: 7, svgY0: 9)
            drawSleeping(c, v: v, breathe: breathe)
        }
    }

    // MARK: - Work Scene

    private var workScene: some View {
        ZStack {
            TimelineView(.periodic(from: .now, by: 0.03)) { timeline in
                workCanvas(t: timeline.date.timeIntervalSinceReferenceDate * speed)
            }
            TimelineView(.periodic(from: .now, by: 0.05)) { ctx in
                workSparkles(t: ctx.date.timeIntervalSinceReferenceDate * speed)
            }
        }
    }

    private func workSparkles(t: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let ci = Double(i)
                let cycle = 2.0 + ci * 0.5
                let phase = ((t + ci * 0.8).truncatingRemainder(dividingBy: cycle)) / cycle
                let twinkle = sin(phase * .pi * 6) * 0.5 + 0.5
                let sparkleSize = max(4, size * CGFloat(0.08))
                let positions: [(CGFloat, CGFloat)] = [(-0.35, -0.25), (0.38, -0.15), (-0.15, -0.35)]
                Text("\u{2726}")
                    .font(.system(size: sparkleSize))
                    .foregroundStyle(palette.sparkle.opacity(twinkle * 0.6))
                    .offset(x: size * positions[i].0, y: size * positions[i].1)
            }
        }
    }

    private func workCanvas(t: Double) -> some View {
        let bounce = sin(t * 2 * .pi / 0.35) * 1.2
        let breathe = sin(t * 2 * .pi / 3.2)

        let armLRaw = sin(t * 2 * .pi / 0.15)
        let armL = armLRaw * 22.5 - 32.5
        let armRRaw = sin(t * 2 * .pi / 0.12)
        let armR = armRRaw * 22.5 + 32.5

        let leftHit = armLRaw > 0.3
        let rightHit = armRRaw > 0.3
        let leftKeyCol = Int(t / 0.15) % 3
        let rightKeyCol = 3 + Int(t / 0.12) % 3

        let scanPhase = t.truncatingRemainder(dividingBy: 10.0)
        let eyeScale: CGFloat = (scanPhase > 5.7 && scanPhase < 6.9) ? 1.0 : 0.5
        let eyeDY: CGFloat = eyeScale < 0.8 ? 1.0 : -0.5
        let blinkPhase = t.truncatingRemainder(dividingBy: 3.5)
        let finalEyeScale = (blinkPhase > 1.4 && blinkPhase < 1.55) ? 0.1 : eyeScale

        return Canvas { c, sz in
            let v = V(sz, svgW: 16, svgH: 11, svgY0: 5.5)
            let dy = bounce

            let shadowW: CGFloat = 9 - abs(dy) * 0.3
            c.fill(Path(v.r(3 + (9 - shadowW) / 2, 15, shadowW, 1)),
                   with: .color(.black.opacity(max(0.1, 0.4 - abs(dy) * 0.03))))

            for x: CGFloat in [3, 5, 9, 11] {
                c.fill(Path(v.r(x, 13, 1, 2)), with: .color(palette.body))
            }

            let bScale = 1.0 + breathe * 0.015
            let torsoW = 11 * bScale
            c.fill(Path(v.r(2 - (torsoW - 11) / 2, 6, torsoW, 7, dy: dy)),
                   with: .color(palette.body))

            c.fill(Path(v.r(4, 8, 7, 2, dy: dy)), with: .color(palette.bodyHighlight.opacity(0.3)))

            drawAccessory(c, v: v, dy: dy)

            c.fill(Path(v.r(2.5, 9.5, 1.5, 1, dy: dy)), with: .color(palette.blush.opacity(0.3)))
            c.fill(Path(v.r(11, 9.5, 1.5, 1, dy: dy)), with: .color(palette.blush.opacity(0.3)))

            let eyeH: CGFloat = 2 * finalEyeScale
            let eyeY: CGFloat = 8 + (2 - eyeH) / 2 + eyeDY
            c.fill(Path(v.r(4, eyeY, 1, eyeH, dy: dy)), with: .color(palette.eye))
            c.fill(Path(v.r(10, eyeY, 1, eyeH, dy: dy)), with: .color(palette.eye))

            c.fill(Path(v.r(-0.5, 11.8, 16, 3.5)), with: .color(palette.kbBase))
            for row in 0..<3 {
                let ky = 12.2 + CGFloat(row) * 1.0
                for col in 0..<6 {
                    let kx = 0.3 + CGFloat(col) * 2.5
                    let w: CGFloat = (col == 2 && row == 1) ? 4.5 : 2.0
                    c.fill(Path(v.r(kx, ky, w, 0.7)), with: .color(palette.kbKey))
                }
            }
            if leftHit {
                let row = leftKeyCol % 3
                let kx = 0.3 + CGFloat(leftKeyCol) * 2.5
                let ky = 12.2 + CGFloat(row) * 1.0
                c.fill(Path(v.r(kx, ky, 2.0, 0.7)), with: .color(palette.kbHighlight.opacity(0.9)))
            }
            if rightHit {
                let row = (rightKeyCol - 3) % 3
                let kx = 0.3 + CGFloat(rightKeyCol) * 2.5
                let ky = 12.2 + CGFloat(row) * 1.0
                c.fill(Path(v.r(kx, ky, 2.0, 0.7)), with: .color(palette.kbHighlight.opacity(0.9)))
            }

            c.fill(armPath(v, x: 0, y: 9, w: 2, h: 2, pivotX: 2, pivotY: 10,
                           angle: armL, dy: dy), with: .color(palette.body))
            c.fill(armPath(v, x: 13, y: 9, w: 2, h: 2, pivotX: 13, pivotY: 10,
                           angle: armR, dy: dy), with: .color(palette.body))
        }
    }

    // MARK: - Alert Scene

    private var alertScene: some View {
        ZStack {
            Circle()
                .fill(palette.alert.opacity(alive ? 0.15 : 0))
                .frame(width: size * 0.85)
                .blur(radius: size * 0.06)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: alive)

            TimelineView(.periodic(from: .now, by: 0.03)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate * speed
                ZStack {
                    alertCanvas(t: t)
                    alertSparkles(t: t)
                }
            }
        }
    }

    private func alertSparkles(t: Double) -> some View {
        let cycle = t.truncatingRemainder(dividingBy: 3.5)
        let pct = cycle / 3.5
        let burstActive = pct > 0.03 && pct < 0.55

        return ZStack {
            if burstActive {
                ForEach(0..<5, id: \.self) { i in
                    let ci = Double(i)
                    let angle = ci * .pi * 2 / 5 + pct * 3
                    let dist = size * CGFloat(0.2 + (pct - 0.03) * 0.4)
                    let twinkle = sin(pct * 20 + ci * 2) * 0.5 + 0.5
                    let sparkleSize = max(3, size * 0.07)
                    Text("\u{2726}")
                        .font(.system(size: sparkleSize))
                        .foregroundStyle(palette.sparkle.opacity(twinkle * 0.7))
                        .offset(x: cos(angle) * dist, y: sin(angle) * dist - size * 0.1)
                }
            }
        }
    }

    private func lerp(_ keyframes: [(CGFloat, CGFloat)], at pct: CGFloat) -> CGFloat {
        guard let first = keyframes.first else { return 0 }
        if pct <= first.0 { return first.1 }
        for i in 1..<keyframes.count {
            if pct <= keyframes[i].0 {
                let t = (pct - keyframes[i-1].0) / (keyframes[i].0 - keyframes[i-1].0)
                return keyframes[i-1].1 + (keyframes[i].1 - keyframes[i-1].1) * t
            }
        }
        return keyframes.last?.1 ?? 0
    }

    private func alertCanvas(t: Double) -> some View {
        let cycle = t.truncatingRemainder(dividingBy: 3.5)
        let pct = cycle / 3.5

        let jumpY = lerp([
            (0, 0), (0.03, 0), (0.10, -1), (0.15, 1.5),
            (0.175, -10), (0.20, -10), (0.25, 1.5),
            (0.275, -8), (0.30, -8), (0.35, 1.2),
            (0.375, -5), (0.40, -5), (0.45, 1.0),
            (0.475, -3), (0.50, -3), (0.55, 0.5),
            (0.62, 0), (1.0, 0),
        ], at: pct)

        let scaleX: CGFloat = jumpY > 0.5 ? 1.0 + jumpY * 0.05 : 1.0
        let scaleY: CGFloat = jumpY > 0.5 ? 1.0 - jumpY * 0.04 : 1.0

        let armL = lerp([
            (0, 0), (0.03, 0), (0.10, 25),
            (0.15, 30), (0.20, 155), (0.25, 115),
            (0.30, 140), (0.35, 100), (0.40, 115),
            (0.45, 80), (0.50, 80), (0.55, 40),
            (0.62, 0), (1.0, 0),
        ], at: pct)
        let armR = -lerp([
            (0, 0), (0.03, 0), (0.10, 30),
            (0.15, 30), (0.20, 155), (0.25, 115),
            (0.30, 140), (0.35, 100), (0.40, 115),
            (0.45, 80), (0.50, 80), (0.55, 40),
            (0.62, 0), (1.0, 0),
        ], at: pct)

        let eyeScale: CGFloat = (pct > 0.03 && pct < 0.15) ? 1.3 : 1.0
        let eyeDY: CGFloat = (pct > 0.03 && pct < 0.15) ? -0.5 : 0

        let bangOpacity = lerp([
            (0, 0), (0.03, 1), (0.10, 1), (0.55, 1), (0.62, 0), (1.0, 0),
        ], at: pct)
        let bangScale = lerp([
            (0, 0.3), (0.03, 1.3), (0.10, 1.0), (0.55, 1.0), (0.62, 0.6), (1.0, 0.6),
        ], at: pct)

        return Canvas { c, sz in
            let v = V(sz, svgW: 15, svgH: 12, svgY0: 4)

            let shadowW: CGFloat = 9 * (1.0 - abs(min(0, jumpY)) * 0.04)
            let shadowOp = max(0.08, 0.5 - abs(min(0, jumpY)) * 0.04)
            c.fill(Path(v.r(3 + (9 - shadowW) / 2, 15, shadowW, 1)),
                   with: .color(.black.opacity(shadowOp)))

            for x: CGFloat in [3, 5, 9, 11] {
                c.fill(Path(v.r(x, 11, 1, 4)), with: .color(palette.body))
            }

            let torsoW = 11 * scaleX
            let torsoH = 7 * scaleY
            let torsoX = 2 - (torsoW - 11) / 2
            let torsoY = 6 + (7 - torsoH)
            c.fill(Path(v.r(torsoX, torsoY, torsoW, torsoH, dy: jumpY)),
                   with: .color(palette.body))

            c.fill(Path(v.r(torsoX + 2, torsoY + 2, torsoW - 4, 2, dy: jumpY)),
                   with: .color(palette.bodyHighlight.opacity(0.25)))

            drawAccessory(c, v: v, dy: jumpY)

            let blushPulse = (pct > 0.03 && pct < 0.55) ? 0.5 : 0.3
            c.fill(Path(v.r(2.5, 9.5, 1.5, 1, dy: jumpY)), with: .color(palette.blush.opacity(blushPulse)))
            c.fill(Path(v.r(11, 9.5, 1.5, 1, dy: jumpY)), with: .color(palette.blush.opacity(blushPulse)))

            let eyeH = 2 * eyeScale
            let eyeYPos = 8 + (2 - eyeH) / 2 + eyeDY
            c.fill(Path(v.r(4, eyeYPos, 1, eyeH, dy: jumpY)), with: .color(palette.eye))
            c.fill(Path(v.r(10, eyeYPos, 1, eyeH, dy: jumpY)), with: .color(palette.eye))

            c.fill(armPath(v, x: 0, y: 9, w: 2, h: 2, pivotX: 2, pivotY: 10,
                           angle: armL, dy: jumpY), with: .color(palette.body))
            c.fill(armPath(v, x: 13, y: 9, w: 2, h: 2, pivotX: 13, pivotY: 10,
                           angle: armR, dy: jumpY), with: .color(palette.body))

            if bangOpacity > 0.01 {
                let bw: CGFloat = 2 * bangScale
                let bx: CGFloat = 13
                let by: CGFloat = 4.5 + jumpY * 0.15
                c.fill(Path(v.r(bx, by, bw, 3.5 * bangScale, dy: 0)),
                       with: .color(palette.alert.opacity(bangOpacity)))
                c.fill(Path(v.r(bx, by + 4.0 * bangScale, bw, 1.5 * bangScale, dy: 0)),
                       with: .color(palette.alert.opacity(bangOpacity)))
            }
        }
    }
}
