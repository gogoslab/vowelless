import Foundation

enum Difficulty: String, CaseIterable, Identifiable {
    case easy, medium, hard

    static let storageKey = "difficulty"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        }
    }

    var subtitle: String {
        switch self {
        case .easy: "Spaces stay where they belong"
        case .medium: "All the spaces are removed"
        case .hard: "Spaces are added at random"
        }
    }

    var symbol: String {
        switch self {
        case .easy: "tortoise.fill"
        case .medium: "hare.fill"
        case .hard: "flame.fill"
        }
    }
}
