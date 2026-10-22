import Foundation

/// The clues an online race uses: one category, or mixed (`nil`).
/// Game Center only matches players in the same player group, so each choice gets its own group.
enum RaceCategory {
    static let mixedGroup = 1
    private static let firstCategoryGroup = 10

    static func playerGroup(for category: Category?) -> Int {
        guard let category, let index = Category.allCases.firstIndex(of: category) else { return mixedGroup }
        return firstCategoryGroup + index
    }

    static func category(forPlayerGroup group: Int) -> Category? {
        let index = group - firstCategoryGroup
        return Category.allCases.indices.contains(index) ? Category.allCases[index] : nil
    }

    /// Bundled puzzles only: Music library puzzles differ from phone to phone.
    static func pool(for category: Category?) -> [Puzzle] {
        guard let category else { return PuzzleStore.builtIn }
        return PuzzleStore.builtIn.filter { $0.category == category }
    }
}
