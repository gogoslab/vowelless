import Foundation

struct Puzzle: Codable, Identifiable, Hashable {
    var id: String { "\(category.rawValue):\(answer)" }
    let answer: String
    let category: Category
    /// Shown one at a time, from most cryptic to most obvious.
    var hints: [String] = []

    init(answer: String, category: Category, hints: [String] = []) {
        self.answer = answer
        self.category = category
        self.hints = hints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        answer = try container.decode(String.self, forKey: .answer)
        category = try container.decode(Category.self, forKey: .category)
        hints = try container.decodeIfPresent([String].self, forKey: .hints) ?? []
    }
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
