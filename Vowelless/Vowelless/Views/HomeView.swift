import SwiftUI

struct HomeView: View {
    @Environment(MusicLibrary.self) private var library
    @AppStorage(MusicSource.storageKey) private var musicSource: MusicSource = .builtIn
    private var allPuzzles: [Puzzle] { PuzzleCatalog.puzzles(library: library, source: musicSource) }
    @State private var bounce = false
    @State private var showSettings = false
    @AppStorage(Difficulty.storageKey) private var difficulty: Difficulty = .easy


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header

                    NavigationLink {
                        GameView(session: GameSession(puzzles: allPuzzles), accent: Category.song.color)
                    } label: {
                        Label("Play Mixed", systemImage: "shuffle")
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Category.character.color, depth: 8))

                    categoryGrid
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(PlayfulBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { bounce = true }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .fontDesign(.rounded)
                .environment(library)
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Label(difficulty.title, systemImage: difficulty.symbol)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.black.opacity(0.2)))
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 18, weight: .black))
                }
                .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 4, cornerRadius: 14))
                .accessibilityLabel("Settings")
            }

            HStack(spacing: 6) {
                ForEach(Array("VWLLSS".enumerated()), id: \.offset) { i, letter in
                    let color = Theme.palette[i % Theme.palette.count]
                    LetterTile(letter: letter, size: 50, face: color, ink: .white, tilt: Theme.tilt(i))
                        .offset(y: bounce ? -8 : 0)
                        .animation(.easeInOut(duration: 0.7).repeatForever().delay(Double(i) * 0.12), value: bounce)
                }
            }
            .padding(.top, 4)

            Text("Guess it without the vowels!")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    /// Two cards per row; an odd last card stretches across the full width.
    private var categoryGrid: some View {
        let categories = Category.allCases
        let rows = stride(from: 0, to: categories.count, by: 2).map { Array(categories[$0..<min($0 + 2, categories.count)]) }
        return VStack(spacing: 14) {
            ForEach(rows, id: \.first) { row in
                HStack(spacing: 14) {
                    ForEach(row) { categoryCard($0) }
                }
            }
        }
    }

    private func categoryCard(_ category: Category) -> some View {
        let puzzles = allPuzzles.filter { $0.category == category }
        return NavigationLink {
            GameView(session: GameSession(puzzles: puzzles), accent: category.color)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: category.symbol)
                    .font(.system(size: 34, weight: .bold))
                    .shadow(color: .black.opacity(0.15), radius: 0, y: 3)
                Text(category.title)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
            }
            .frame(maxWidth: .infinity, minHeight: 100)
        }
        .buttonStyle(ChunkyButtonStyle(color: category.color, foreground: category.onColor, depth: 7, cornerRadius: 24))
        .disabled(puzzles.isEmpty)
    }
}

#Preview {
    HomeView()
        .fontDesign(.rounded)
        .environment(MusicLibrary())
}
