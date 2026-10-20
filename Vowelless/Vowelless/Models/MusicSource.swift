import Foundation

/// Where Songs and Artists & Bands puzzles come from.
enum MusicSource: String, CaseIterable, Identifiable {
    case builtIn, library, both

    static let storageKey = "musicSource"
    static let categories: Set<Category> = [.song, .artist]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .builtIn: "Built-in"
        case .library: "My Music"
        case .both: "Both"
        }
    }

    var usesLibrary: Bool { self != .builtIn }
}
