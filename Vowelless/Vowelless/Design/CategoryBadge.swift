import SwiftUI

/// The category pill above a clue, with a flame for hard answers.
struct CategoryBadge: View {
    let puzzle: Puzzle

    var body: some View {
        let category = puzzle.category
        HStack(spacing: 8) {
            Label(category.title, systemImage: category.symbol)
            if puzzle.level == .hard {
                Label("Hard", systemImage: "flame.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.wrong))
            }
        }
        .font(.system(.headline, design: .rounded, weight: .heavy))
        .foregroundStyle(category.onColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(category.color))
        .background(Capsule().fill(category.color.darker()).offset(y: 4))
        .accessibilityElement(children: .combine)
    }
}
