import AppKit
import Foundation
import UserNotifications

struct MembershipTier: Equatable {
    let level: Int
    let title: String
    let subtitle: String
    let colorHex: UInt32
    let glowHex: UInt32
    let requiredMinutes: Int
    let badge: String

    var requiredHours: Double { Double(requiredMinutes) / 60.0 }

    static let tiers: [MembershipTier] = [
        MembershipTier(level: 1, title: "NEWCOMER",  subtitle: "FIRST_STEPS",    colorHex: 0xA0A0A0, glowHex: 0x808080, requiredMinutes: 0,    badge: "☆"),
        MembershipTier(level: 2, title: "EXPLORER",  subtitle: "BOARDING_PASS",   colorHex: 0x3DDC84, glowHex: 0x2AAA5F, requiredMinutes: 60,   badge: "★"),
        MembershipTier(level: 3, title: "BUILDER",   subtitle: "DEEP_SPACE",      colorHex: 0x4A90D9, glowHex: 0x3A72B0, requiredMinutes: 300,  badge: "★★"),
        MembershipTier(level: 4, title: "ARCHITECT", subtitle: "NEBULA_ACCESS",   colorHex: 0x9B59B6, glowHex: 0x7D3F99, requiredMinutes: 1440, badge: "★★★"),
        MembershipTier(level: 5, title: "MASTER",    subtitle: "GOLDEN_ORBIT",    colorHex: 0xF1C40F, glowHex: 0xD4A90A, requiredMinutes: 3000, badge: "★★★★"),
        MembershipTier(level: 6, title: "LEGEND",    subtitle: "ISLAND_FOUNDER",  colorHex: 0xD97842, glowHex: 0xB85E30, requiredMinutes: 6000, badge: "★★★★★"),
    ]

    static func tier(for totalMinutes: Int) -> MembershipTier {
        tiers.last(where: { totalMinutes >= $0.requiredMinutes }) ?? tiers[0]
    }

    static func nextTier(after current: MembershipTier) -> MembershipTier? {
        guard let idx = tiers.firstIndex(where: { $0.level == current.level }),
              idx + 1 < tiers.count else { return nil }
        return tiers[idx + 1]
    }
}

@MainActor
final class MembershipTracker: ObservableObject {
    static let shared = MembershipTracker()

    private let defaults = UserDefaults.standard
    private static let totalMinutesKey = "membership_totalMinutes"
    private static let joinDateKey = "membership_joinDate"
    private static let lastTickKey = "membership_lastTick"
    private static let pilotNameKey = "membership_pilotName"
    private static let totalSessionsKey = "membership_totalSessions"
    private static let totalPromptsKey = "membership_totalPrompts"

    @Published private(set) var totalMinutes: Int
    @Published private(set) var currentTier: MembershipTier
    @Published private(set) var joinDate: Date
    @Published var pilotName: String {
        didSet { defaults.set(pilotName, forKey: Self.pilotNameKey) }
    }
    @Published private(set) var totalSessions: Int
    @Published private(set) var totalPrompts: Int
    @Published var justLeveledUp: MembershipTier?

    private var tickTimer: Timer?

    private init() {
        let minutes = defaults.integer(forKey: Self.totalMinutesKey)
        let join = defaults.object(forKey: Self.joinDateKey) as? Date ?? Date()
        self.totalMinutes = minutes
        self.currentTier = MembershipTier.tier(for: minutes)
        self.joinDate = join
        self.pilotName = defaults.string(forKey: Self.pilotNameKey) ?? NSFullUserName()
        self.totalSessions = defaults.integer(forKey: Self.totalSessionsKey)
        self.totalPrompts = defaults.integer(forKey: Self.totalPromptsKey)

        if defaults.object(forKey: Self.joinDateKey) == nil {
            defaults.set(join, forKey: Self.joinDateKey)
        }
    }

    var nextTier: MembershipTier? { MembershipTier.nextTier(after: currentTier) }

    var progressToNext: Double {
        guard let next = nextTier else { return 1.0 }
        let base = currentTier.requiredMinutes
        let range = next.requiredMinutes - base
        guard range > 0 else { return 1.0 }
        return Double(totalMinutes - base) / Double(range)
    }

    var formattedTime: String {
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    func startTracking() {
        guard tickTimer == nil else { return }
        defaults.set(Date(), forKey: Self.lastTickKey)
        tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    func stopTracking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    func recordSessionStart() {
        totalSessions += 1
        defaults.set(totalSessions, forKey: Self.totalSessionsKey)
    }

    func recordPrompt() {
        totalPrompts += 1
        defaults.set(totalPrompts, forKey: Self.totalPromptsKey)
    }

    private func tick() {
        totalMinutes += 1
        defaults.set(totalMinutes, forKey: Self.totalMinutesKey)
        let newTier = MembershipTier.tier(for: totalMinutes)
        if newTier.level != currentTier.level {
            let oldTier = currentTier
            currentTier = newTier
            handleLevelUp(from: oldTier, to: newTier)
        }
    }

    private func handleLevelUp(from old: MembershipTier, to new: MembershipTier) {
        justLeveledUp = new

        SoundManager.shared.preview("8bit_complete")

        sendLevelUpNotification(tier: new)

        MembershipCardPopupController.shared.show()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.justLeveledUp = nil
        }
    }

    private func sendLevelUpNotification(tier: MembershipTier) {
        let content = UNMutableNotificationContent()
        content.title = "\(tier.badge) Level Up!"
        content.body = "You've reached \(tier.title) tier — \(tier.subtitle.replacingOccurrences(of: "_", with: " "))"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "levelup-\(tier.level)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func addMinutes(_ count: Int) {
        totalMinutes += count
        defaults.set(totalMinutes, forKey: Self.totalMinutesKey)
        let newTier = MembershipTier.tier(for: totalMinutes)
        if newTier.level != currentTier.level {
            let oldTier = currentTier
            currentTier = newTier
            handleLevelUp(from: oldTier, to: newTier)
        }
    }
}
