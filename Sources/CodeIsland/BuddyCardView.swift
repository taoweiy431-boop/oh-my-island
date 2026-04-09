import SwiftUI

struct BuddyCardView: View {
    let buddy: BuddyInfo
    @State private var frameIndex = 0
    @State private var timer: Timer?

    private var art: BuddyAsciiArt { BuddyAsciiArt.forSpecies(buddy.species.id) }
    private var currentFrame: [String] { art.frames[frameIndex % art.frames.count] }

    private var rarityColor: Color {
        Color(
            red: Double((buddy.rarity.colorHex >> 16) & 0xFF) / 255.0,
            green: Double((buddy.rarity.colorHex >> 8) & 0xFF) / 255.0,
            blue: Double(buddy.rarity.colorHex & 0xFF) / 255.0
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            leftPanel
            rightPanel
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(rarityColor.opacity(0.2), lineWidth: 0.5)
                )
        )
        .onAppear { startAnimation() }
        .onDisappear { stopAnimation() }
    }

    // MARK: - Left Panel: ASCII Art + Name

    private var leftPanel: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                ForEach(currentFrame.indices, id: \.self) { i in
                    Text(currentFrame[i])
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(buddy.isShiny ? rarityColor : .white.opacity(0.85))
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.03))
            )

            Text(buddy.name)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            HStack(spacing: 4) {
                Text(buddy.species.emoji)
                    .font(.system(size: 11))
                Text(buddy.species.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }

            if buddy.isShiny {
                Text("✦ SHINY ✦")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(rarityColor)
            }
        }
        .frame(minWidth: 90)
    }

    // MARK: - Right Panel: Stats + Rarity

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(buddy.rarity.stars)
                    .foregroundStyle(rarityColor)
                Text(buddy.rarity.label)
                    .foregroundStyle(rarityColor)
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))

            Divider()
                .background(Color.white.opacity(0.08))

            ForEach(0..<5, id: \.self) { i in
                HStack(spacing: 4) {
                    Text(BuddyStats.labels[i])
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 70, alignment: .trailing)
                    Text(buddy.stats.bar(for: i))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(statColor(for: buddy.stats.values[i]))
                    Text("\(buddy.stats.values[i])")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 16, alignment: .trailing)
                }
            }

            if !buddy.personality.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.08))

                Text(buddy.personality)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                detailChip("👁 \(buddy.eyeStyle)")
                if buddy.hat != "none" {
                    detailChip("🎩 \(buddy.hat)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func statColor(for value: Int) -> Color {
        if value >= 70 { return .green.opacity(0.8) }
        if value >= 40 { return .cyan.opacity(0.7) }
        if value >= 20 { return .yellow.opacity(0.7) }
        return .red.opacity(0.6)
    }

    private func detailChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.white.opacity(0.4))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.04))
            )
    }

    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.15)) {
                    frameIndex += 1
                }
            }
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}
