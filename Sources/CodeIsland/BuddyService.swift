import Foundation
import os.log

private let log = Logger(subsystem: "com.codeisland", category: "Buddy")

// MARK: - Buddy Data Model

struct BuddySpecies: Identifiable {
    let id: String
    let name: String
    let emoji: String

    static let all: [BuddySpecies] = [
        BuddySpecies(id: "duck",      name: "Duck",      emoji: "🦆"),
        BuddySpecies(id: "goose",     name: "Goose",     emoji: "🪿"),
        BuddySpecies(id: "blob",      name: "Blob",      emoji: "🫠"),
        BuddySpecies(id: "cat",       name: "Cat",       emoji: "🐱"),
        BuddySpecies(id: "dragon",    name: "Dragon",    emoji: "🐉"),
        BuddySpecies(id: "octopus",   name: "Octopus",   emoji: "🐙"),
        BuddySpecies(id: "owl",       name: "Owl",       emoji: "🦉"),
        BuddySpecies(id: "penguin",   name: "Penguin",   emoji: "🐧"),
        BuddySpecies(id: "turtle",    name: "Turtle",    emoji: "🐢"),
        BuddySpecies(id: "snail",     name: "Snail",     emoji: "🐌"),
        BuddySpecies(id: "ghost",     name: "Ghost",     emoji: "👻"),
        BuddySpecies(id: "axolotl",   name: "Axolotl",   emoji: "🦎"),
        BuddySpecies(id: "capybara",  name: "Capybara",  emoji: "🦫"),
        BuddySpecies(id: "cactus",    name: "Cactus",    emoji: "🌵"),
        BuddySpecies(id: "robot",     name: "Robot",     emoji: "🤖"),
        BuddySpecies(id: "rabbit",    name: "Rabbit",    emoji: "🐰"),
        BuddySpecies(id: "mushroom",  name: "Mushroom",  emoji: "🍄"),
        BuddySpecies(id: "chonk",     name: "Chonk",     emoji: "🐾"),
    ]

    static func byId(_ id: String) -> BuddySpecies? {
        all.first { $0.id == id }
    }
}

enum BuddyRarity: Int, CaseIterable, Comparable {
    case common = 1
    case uncommon = 2
    case rare = 3
    case epic = 4
    case legendary = 5

    var label: String {
        switch self {
        case .common:    return "Common"
        case .uncommon:  return "Uncommon"
        case .rare:      return "Rare"
        case .epic:      return "Epic"
        case .legendary: return "Legendary"
        }
    }

    var stars: String { String(repeating: "★", count: rawValue) }

    var colorHex: UInt32 {
        switch self {
        case .common:    return 0x999999
        case .uncommon:  return 0x4ADE80
        case .rare:      return 0x60A5FA
        case .epic:      return 0xA78BFA
        case .legendary: return 0xFBBF24
        }
    }

    static func < (lhs: BuddyRarity, rhs: BuddyRarity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct BuddyStats {
    let debugging: Int  // 0-10
    let patience: Int
    let chaos: Int
    let wisdom: Int
    let snark: Int

    static let labels = ["DEBUGGING", "PATIENCE", "CHAOS", "WISDOM", "SNARK"]

    var values: [Int] { [debugging, patience, chaos, wisdom, snark] }

    func bar(for index: Int) -> String {
        let raw = values[index]
        let v = min(10, max(0, raw * 10 / 100))
        let filled = String(repeating: "█", count: v)
        let empty = String(repeating: "░", count: 10 - v)
        return "[\(filled)\(empty)]"
    }
}

struct BuddyInfo {
    let name: String
    let personality: String
    let species: BuddySpecies
    let rarity: BuddyRarity
    let stats: BuddyStats
    let isShiny: Bool
    let eyeStyle: String
    let hat: String
}

// MARK: - Mulberry32 PRNG (matches Claude Code's Math.imul-based implementation)

struct Mulberry32 {
    var state: UInt32

    init(seed: UInt32) {
        self.state = seed
    }

    mutating func next() -> Double {
        state &+= 0x6D2B79F5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t = (t &+ ((t ^ (t >> 7)) &* (t | 61))) ^ t
        let result = (t ^ (t >> 14))
        return Double(result) / 4294967296.0
    }
}

// MARK: - BuddyService

@MainActor
class BuddyService: ObservableObject {
    static let shared = BuddyService()

    @Published var buddy: BuddyInfo?
    @Published var isLoaded = false

    private init() {}

    func load() {
        Task {
            await loadBuddyData()
        }
    }

    private static let defaultSalt = "friend-2026-401"

    private func loadBuddyData() async {
        let claudeJsonPath = NSHomeDirectory() + "/.claude.json"

        guard FileManager.default.fileExists(atPath: claudeJsonPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: claudeJsonPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let companion = json["companion"] as? [String: Any],
              let name = companion["name"] as? String,
              let personality = companion["personality"] as? String else {
            log.info("No buddy companion data, generating default")
            generateDefaultBuddy()
            return
        }

        let userId: String
        if let oauth = json["oauthAccount"] as? [String: Any],
           let uuid = oauth["accountUuid"] as? String {
            userId = uuid
        } else if let uid = json["userID"] as? String {
            userId = uid
        } else {
            userId = "anon"
        }

        let salt = Self.readSalt()
        let bones = Self.rollBones(userId: userId, salt: salt)

        buddy = BuddyInfo(
            name: name,
            personality: personality,
            species: bones.species,
            rarity: bones.rarity,
            stats: bones.stats,
            isShiny: bones.isShiny,
            eyeStyle: bones.eye,
            hat: bones.hat
        )
        isLoaded = true
        log.info("Buddy loaded: \(name) the \(bones.species.name) (\(bones.rarity.label))")
    }

    private func generateDefaultBuddy() {
        let username = NSUserName()
        let bones = Self.rollBones(userId: username, salt: Self.defaultSalt)

        buddy = BuddyInfo(
            name: username,
            personality: "",
            species: bones.species,
            rarity: bones.rarity,
            stats: bones.stats,
            isShiny: bones.isShiny,
            eyeStyle: bones.eye,
            hat: bones.hat
        )
        isLoaded = true
    }

    // MARK: - Salt Detection

    private static func readSalt() -> String {
        let home = NSHomeDirectory()
        let cachePath = "\(home)/.claude/.codeisland-salt"
        if let cached = try? String(contentsOfFile: cachePath, encoding: .utf8),
           cached.count == defaultSalt.count,
           cached.allSatisfy({ $0.isASCII && !$0.isNewline }) {
            return cached
        }
        return defaultSalt
    }

    // MARK: - Bones Computation (matches Claude Code's rollFrom order exactly)

    private struct Bones {
        let species: BuddySpecies
        let rarity: BuddyRarity
        let stats: BuddyStats
        let eye: String
        let hat: String
        let isShiny: Bool
    }

    private static func rollBones(userId: String, salt: String) -> Bones {
        let key = userId + salt
        let hash = WyHash.hash(key)
        let seed = UInt32(hash & 0xFFFFFFFF)
        var rng = Mulberry32(seed: seed)

        // 1. Rarity FIRST
        let rarityWeights: [(BuddyRarity, Int)] = [
            (.common, 60), (.uncommon, 25), (.rare, 10), (.epic, 4), (.legendary, 1)
        ]
        var roll = rng.next() * 100.0
        var rarity: BuddyRarity = .common
        for (r, w) in rarityWeights {
            roll -= Double(w)
            if roll < 0 { rarity = r; break }
        }

        // 2. Species SECOND
        let speciesIndex = Int(floor(rng.next() * Double(BuddySpecies.all.count)))
        let species = BuddySpecies.all[speciesIndex]

        // 3. Eye
        let eyes = ["·", "✦", "×", "◉", "@", "°"]
        let eye = eyes[Int(floor(rng.next() * Double(eyes.count)))]

        // 4. Hat (common gets "none")
        let hats = ["none", "crown", "tophat", "propeller", "halo", "wizard", "beanie", "tinyduck"]
        let hat = rarity == .common ? "none" : hats[Int(floor(rng.next() * Double(hats.count)))]

        // 5. Shiny
        let isShiny = rng.next() < 0.01

        // 6. Stats
        let statNames = ["DEBUGGING", "PATIENCE", "CHAOS", "WISDOM", "SNARK"]
        let rarityFloor: [BuddyRarity: Int] = [.common: 5, .uncommon: 15, .rare: 25, .epic: 35, .legendary: 50]
        let fl = rarityFloor[rarity] ?? 5

        let peak = statNames[Int(floor(rng.next() * Double(statNames.count)))]
        var dump = statNames[Int(floor(rng.next() * Double(statNames.count)))]
        while dump == peak {
            dump = statNames[Int(floor(rng.next() * Double(statNames.count)))]
        }

        var statValues = [String: Int]()
        for name in statNames {
            if name == peak {
                statValues[name] = min(100, fl + 50 + Int(floor(rng.next() * 30)))
            } else if name == dump {
                statValues[name] = max(1, fl - 10 + Int(floor(rng.next() * 15)))
            } else {
                statValues[name] = fl + Int(floor(rng.next() * 40))
            }
        }

        return Bones(
            species: species,
            rarity: rarity,
            stats: BuddyStats(
                debugging: statValues["DEBUGGING"] ?? 0,
                patience: statValues["PATIENCE"] ?? 0,
                chaos: statValues["CHAOS"] ?? 0,
                wisdom: statValues["WISDOM"] ?? 0,
                snark: statValues["SNARK"] ?? 0
            ),
            eye: eye,
            hat: hat,
            isShiny: isShiny
        )
    }
}
