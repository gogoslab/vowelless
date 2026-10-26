import Foundation

/// How well-known an answer is. About 70% of each category is easy; Mixed uses only easy answers.
enum PuzzleLevel: String, Codable {
    case easy, hard
}

struct Puzzle: Codable, Identifiable, Hashable {
    var id: String { "\(category.rawValue):\(answer)" }
    let answer: String
    let category: Category
    var level: PuzzleLevel = .easy
    /// Shown one at a time, from most cryptic to most obvious.
    var hints: [String] = []

    init(answer: String, category: Category, level: PuzzleLevel = .easy, hints: [String] = []) {
        self.answer = answer
        self.category = category
        self.level = level
        self.hints = hints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        answer = try container.decode(String.self, forKey: .answer)
        category = try container.decode(Category.self, forKey: .category)
        level = try container.decodeIfPresent(PuzzleLevel.self, forKey: .level) ?? .easy
        hints = try container.decodeIfPresent([String].self, forKey: .hints) ?? []
    }
}

extension Array where Element == Puzzle {
    /// The puzzles for Mixed: easy answers only.
    var mixed: [Puzzle] { filter { $0.level == .easy } }
}

enum PuzzleStore {
    /// The puzzles bundled with the app, loaded once.
    static let builtIn: [Puzzle] = loadAll()

    static func loadAll() -> [Puzzle] {
        guard let url = Bundle.main.url(forResource: "puzzles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let puzzles = try? JSONDecoder().decode([Puzzle].self, from: data)
        else { return [] }
        return puzzles
    }
}
