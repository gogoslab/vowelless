import SwiftUI

/// What the player picked on the home screen.
enum PlayMode: Hashable {
    case train, online

    var title: String {
        switch self {
        case .train: "Train"
        case .online: "Play Online"
        }
    }

    var subtitle: String {
        switch self {
        case .train: "Practice at your own pace, with hints and vowels."
        case .online: "Race another player. First correct answer wins!"
        }
    }

    var symbol: String {
        switch self {
        case .train: "dumbbell.fill"
        case .online: "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .train: Category.character.color
        case .online: Category.song.color
        }
    }
}

/// Mixed or one category, for training or an online race.
struct CategoryPickerView: View {
    let mode: PlayMode

    @Environment(\.dismiss) private var dismiss
    @Environment(MusicLibrary.self) private var library
    @Environment(Wallet.self) private var wallet
    @AppStorage(MusicSource.storageKey) private var musicSource: MusicSource = .builtIn
    @AppStorage(Difficulty.storageKey) private var difficulty: Difficulty = .easy
    /// The online race being set up; `.some(nil)` means mixed.
    @State private var onlineCategory: Category??

    /// Training can use the Music library; online races stick to the bundled puzzles both phones share.
    private var trainingPuzzles: [Puzzle] { PuzzleCatalog.puzzles(library: library, source: musicSource) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                choice(nil)
                categoryGrid
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(PlayfulBackground())
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: Binding(get: { onlineCategory != nil }, set: { if !$0 { onlineCategory = nil } })) {
            OnlinePlayView(category: onlineCategory ?? nil, difficulty: difficulty) {
                onlineCategory = nil
            }
            .fontDesign(.rounded)
            .environment(wallet)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .black))
            }
            .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 4, cornerRadius: 14, horizontalPadding: 16))
            .accessibilityLabel("Back")

            Label(mode.title, systemImage: mode.symbol)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(.white)
            Text(mode.subtitle)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
            Text("Pick a category")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 6)
        }
    }

    /// Two cards per row, under a full-width Mixed button.
    private var categoryGrid: some View {
        let categories = Category.allCases
        let rows = stride(from: 0, to: categories.count, by: 2).map { Array(categories[$0..<min($0 + 2, categories.count)]) }
        return VStack(spacing: 14) {
            ForEach(rows, id: \.first) { row in
                HStack(spacing: 14) {
                    ForEach(row) { choice($0) }
                }
            }
        }
    }

    /// A category card, or the Mixed button when `category` is nil.
    @ViewBuilder
    private func choice(_ category: Category?) -> some View {
        let label = cardLabel(category)
        let style = ChunkyButtonStyle(
            color: category?.color ?? Category.character.color,
            foreground: category?.onColor ?? .white,
            depth: category == nil ? 8 : 7,
            cornerRadius: 24
        )
        switch mode {
        case .train:
            let puzzles = category.map { c in trainingPuzzles.filter { $0.category == c } } ?? trainingPuzzles
            NavigationLink {
                GameView(session: GameSession(puzzles: puzzles, wallet: wallet), accent: category?.color ?? Category.song.color)
            } label: { label }
            .buttonStyle(style)
            .disabled(puzzles.isEmpty)
        case .online:
            Button { onlineCategory = .some(category) } label: { label }
                .buttonStyle(style)
        }
    }

    @ViewBuilder
    private func cardLabel(_ category: Category?) -> some View {
        if let category {
            VStack(spacing: 10) {
                Image(systemName: category.symbol)
                    .font(.system(size: 34, weight: .bold))
                    .shadow(color: .black.opacity(0.15), radius: 0, y: 3)
                Text(category.title)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
            }
            .frame(maxWidth: .infinity, minHeight: 100)
        } else {
            Label("Mixed", systemImage: "shuffle")
                .font(.system(.title2, design: .rounded, weight: .black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
    }
}
