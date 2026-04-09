import Foundation

struct BuddyAsciiArt {
    let frames: [[String]]
    let width: Int
    let height: Int

    static func forSpecies(_ id: String) -> BuddyAsciiArt {
        switch id {
        case "duck":      return duck
        case "goose":     return goose
        case "blob":      return blob
        case "cat":       return cat
        case "dragon":    return dragon
        case "octopus":   return octopus
        case "owl":       return owl
        case "penguin":   return penguin
        case "turtle":    return turtle
        case "snail":     return snail
        case "ghost":     return ghost
        case "axolotl":   return axolotl
        case "capybara":  return capybara
        case "cactus":    return cactus
        case "robot":     return robot
        case "rabbit":    return rabbit
        case "mushroom":  return mushroom
        case "chonk":     return chonk
        default:          return blob
        }
    }

    // MARK: - Species Definitions

    static let duck = BuddyAsciiArt(frames: [
        [
            "  __  ",
            "<(o )>",
            " (  ) ",
            "  ^^  ",
        ],
        [
            "  __  ",
            "<(- )>",
            " (  ) ",
            "  ^^  ",
        ],
    ], width: 6, height: 4)

    static let goose = BuddyAsciiArt(frames: [
        [
            "  ___  ",
            " (o  ) ",
            "  |  \\ ",
            " / \\  \\",
            " \\_/   ",
        ],
        [
            "  ___  ",
            " (O  )!",
            "  |  \\ ",
            " / \\  \\",
            " \\_/   ",
        ],
    ], width: 7, height: 5)

    static let blob = BuddyAsciiArt(frames: [
        [
            " .--. ",
            "(o  o)",
            " \\__/ ",
            "  \\/  ",
        ],
        [
            " .--. ",
            "(-  -)",
            " \\__/ ",
            "  \\/  ",
        ],
    ], width: 6, height: 4)

    static let cat = BuddyAsciiArt(frames: [
        [
            " /\\_/\\ ",
            "( o.o )",
            " > ^ < ",
            "  |||  ",
        ],
        [
            " /\\_/\\ ",
            "( -.- )",
            " > ^ < ",
            "  |||  ",
        ],
    ], width: 7, height: 4)

    static let dragon = BuddyAsciiArt(frames: [
        [
            "  /\\_  ",
            " / o\\> ",
            "<|   | ",
            " \\__/~ ",
        ],
        [
            "  /\\_  ",
            " / -\\> ",
            "<|   | ",
            " \\__/~~",
        ],
    ], width: 7, height: 4)

    static let octopus = BuddyAsciiArt(frames: [
        [
            " .--. ",
            "(o  o)",
            "/|/\\|\\",
            " |  | ",
        ],
        [
            " .--. ",
            "(o  o)",
            "\\|/\\|/",
            " |  | ",
        ],
    ], width: 6, height: 4)

    static let owl = BuddyAsciiArt(frames: [
        [
            " {o,o} ",
            " /)  ) ",
            "-\"--\"- ",
        ],
        [
            " {-,-} ",
            " /)  ) ",
            "-\"--\"- ",
        ],
    ], width: 7, height: 3)

    static let penguin = BuddyAsciiArt(frames: [
        [
            " (^) ",
            "(o o)",
            " )_( ",
            " / \\ ",
        ],
        [
            " (^) ",
            "(- -)",
            " )_( ",
            " / \\ ",
        ],
    ], width: 5, height: 4)

    static let turtle = BuddyAsciiArt(frames: [
        [
            "   ___  ",
            "o_/   \\ ",
            "  \\___/ ",
            "  _| |_ ",
        ],
        [
            "   ___  ",
            "-_/   \\ ",
            "  \\___/ ",
            "  _| |_ ",
        ],
    ], width: 8, height: 4)

    static let snail = BuddyAsciiArt(frames: [
        [
            "  @  @ ",
            " _/\"\\_ ",
            "(_____)",
            "-------",
        ],
        [
            " @  @  ",
            " _/\"\\_ ",
            "(_____)",
            "-------",
        ],
    ], width: 7, height: 4)

    static let ghost = BuddyAsciiArt(frames: [
        [
            " .--. ",
            "( oo )",
            " |  | ",
            " /\\/\\ ",
        ],
        [
            " .--. ",
            "( OO )",
            " |  | ",
            " \\/\\/ ",
        ],
    ], width: 6, height: 4)

    static let axolotl = BuddyAsciiArt(frames: [
        [
            "\\(o.o)/",
            "  | |  ",
            " /   \\ ",
            "~~   ~~",
        ],
        [
            "\\(-.-)\\",
            "  | |  ",
            " /   \\ ",
            " ~   ~ ",
        ],
    ], width: 7, height: 4)

    static let capybara = BuddyAsciiArt(frames: [
        [
            " .--.  ",
            "(o  o) ",
            " |--|\\ ",
            " |  | |",
        ],
        [
            " .--.  ",
            "(-  -) ",
            " |--|\\ ",
            " |  | |",
        ],
    ], width: 7, height: 4)

    static let cactus = BuddyAsciiArt(frames: [
        [
            "  |  ",
            " /|\\ ",
            "/ | \\",
            " \\|/ ",
            "  |  ",
        ],
        [
            "  |  ",
            " \\|/ ",
            "  |  ",
            " /|\\ ",
            "  |  ",
        ],
    ], width: 5, height: 5)

    static let robot = BuddyAsciiArt(frames: [
        [
            " [==] ",
            "[o  o]",
            " |--| ",
            " |  | ",
        ],
        [
            " [==] ",
            "[-  -]",
            " |--| ",
            " |  | ",
        ],
    ], width: 6, height: 4)

    static let rabbit = BuddyAsciiArt(frames: [
        [
            " /\\ /\\",
            "(  V  )",
            "(> . <)",
            " \" \" ",
        ],
        [
            " /\\ /\\",
            "(  V  )",
            "(> - <)",
            " \" \" ",
        ],
    ], width: 7, height: 4)

    static let mushroom = BuddyAsciiArt(frames: [
        [
            " .--.  ",
            "/o  o\\ ",
            "\\____/ ",
            "  ||   ",
        ],
        [
            " .--.  ",
            "/-  -\\ ",
            "\\____/ ",
            "  ||   ",
        ],
    ], width: 7, height: 4)

    static let chonk = BuddyAsciiArt(frames: [
        [
            " .----. ",
            "( o  o )",
            "(      )",
            " '----' ",
        ],
        [
            " .----. ",
            "( -  - )",
            "(      )",
            " '----' ",
        ],
    ], width: 8, height: 4)
}
