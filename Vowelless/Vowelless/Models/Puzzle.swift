import Foundation

struct Puzzle: Codable, Identifiable, Hashable {
    var id: String { "\(category.rawValue):\(answer)" }
    let answer: String
    let category: Category
    var hint: String?
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
