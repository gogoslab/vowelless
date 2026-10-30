import SwiftUI

/// "How to play": shown once on first launch, and again from Settings.
struct TutorialView: View {
    static let seenKey = "tutorial.seen"

    var onFinish: () -> Void

    @Environment(DailyPuzzle.self) private var daily
    @AppStorage(DailyReminder.enabledKey) private var reminderEnabled = false
    @State private var page = 0

    private static let pageCount = 4
    private static let example = Puzzle(answer: "Harry Potter", category: .character)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < Self.pageCount - 1 {
                    Button("Skip", action: onFinish)
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
            }
            .frame(height: 44)

            TabView(selection: $page) {
                guessPage.tag(0)
                helpPage.tag(1)
                spacingPage.tag(2)
                everyDayPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < Self.pageCount - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < Self.pageCount - 1 ? "Next" : "Let's play!")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.correct, depth: 7))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .foregroundStyle(.white)
        .background(PlayfulBackground())
        .sensoryFeedback(.selection, trigger: page)
    }

    // MARK: - Pages

    private var guessPage: some View {
        page(title: "Guess it without the vowels!") {
            VStack(spacing: 22) {
                CategoryBadge(puzzle: Self.example)
                // Flips between the clue and the answer.
                TimelineView(.periodic(from: .now, by: 2.5)) { context in
                    let revealed = Int(context.date.timeIntervalSinceReferenceDate / 2.5) % 2 == 1
                    ClueBoard(answer: Self.example.answer, revealed: revealed, maxWidth: 300, maxTileSize: 40)
                        .animation(.spring(bounce: 0.4), value: revealed)
                }
                .frame(height: 110)
            }
        } text: {
            "Every clue is a name with its vowels taken out: a song, a movie, a famous person and more. Type the full name, or tap the mic and say it."
        }
    }

    private var helpPage: some View {
        page(title: "Stuck? Get some help") {
            VStack(alignment: .leading, spacing: 16) {
                helperRow(color: Category.artist.color, symbol: "lightbulb.fill",
                          title: "Hints", detail: "A cryptic one first, then a clear one.", cost: "\(Economy.hintCosts[0]) / \(Economy.hintCosts[1])")
                helperRow(color: Category.song.color, label: "A?",
                          title: "Vowels", detail: "Fills in every copy of a vowel.", cost: "\(Economy.vowelCost)")
                helperRow(color: Theme.correct, symbol: "star.fill",
                          title: "\(GameSession.maxPoints) stars", detail: "for solving with no help. Each helper costs a star.", cost: nil)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.black.opacity(0.2)))
        } text: {
            "Helpers cost coins. Earn coins by solving clues, playing the daily puzzle and claiming your daily gift."
        }
    }

    private var spacingPage: some View {
        page(title: "Pick your spacing") {
            VStack(spacing: 14) {
                ForEach(Difficulty.allCases) { option in
                    VStack(spacing: 8) {
                        Label(option.title, systemImage: option.symbol)
                            .font(.system(.headline, design: .rounded, weight: .black))
                        ClueBoard(answer: Self.example.answer, revealed: false, difficulty: option, maxWidth: 240, maxTileSize: 26)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.black.opacity(0.2)))
                }
            }
        } text: {
            "Easy keeps the spaces, Medium removes them, Hard adds random ones. Change it any time in Settings."
        }
    }

    private var everyDayPage: some View {
        page(title: "Come back every day") {
            VStack(alignment: .leading, spacing: 16) {
                modeRow(color: Category.book.color, symbol: "calendar", title: "Daily puzzle",
                        detail: "The same 5 clues for everyone. Keep your 🔥 streak going.")
                modeRow(color: PlayMode.online.color, symbol: PlayMode.online.symbol, title: PlayMode.online.title,
                        detail: PlayMode.online.subtitle)
                modeRow(color: PlayMode.train.color, symbol: PlayMode.train.symbol, title: PlayMode.train.title,
                        detail: PlayMode.train.subtitle)

                if !reminderEnabled {
                    Button {
                        Task {
                            reminderEnabled = await DailyReminder.requestPermission()
                            await DailyReminder.reschedule(for: daily)
                        }
                    } label: {
                        Label("Remind me daily", systemImage: "bell.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 5, cornerRadius: 18))
                    .padding(.top, 4)
                } else {
                    Label("Daily reminder is on. Change the time in Settings.", systemImage: "bell.badge.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
        } text: {
            nil
        }
    }

    // MARK: - Building blocks

    private func page(title: String, @ViewBuilder content: () -> some View, text: () -> String?) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .multilineTextAlignment(.center)
                content()
                if let text = text() {
                    Text(text)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .opacity(0.9)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 48)
        }
        .scrollIndicators(.hidden)
    }

    private func helperRow(color: Color, symbol: String? = nil, label: String? = nil,
                           title: String, detail: String, cost: String?) -> some View {
        HStack(spacing: 14) {
            Group {
                if let symbol { Image(systemName: symbol) } else { Text(label ?? "") }
            }
            .font(.system(.headline, design: .rounded, weight: .black))
            .foregroundStyle(color == Category.artist.color ? Theme.ink : .white)
            .frame(width: 48, height: 40)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color))
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.darker()).offset(y: 3))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title).font(.system(.headline, design: .rounded, weight: .black))
                    if let cost {
                        HStack(spacing: 4) {
                            CoinIcon(size: 14)
                            Text(cost)
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .black))
                    }
                }
                Text(detail)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .opacity(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func modeRow(color: Color, symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .black))
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color))
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.darker()).offset(y: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.headline, design: .rounded, weight: .black))
                Text(detail)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .opacity(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TutorialView {}
        .fontDesign(.rounded)
        .environment(DailyPuzzle())
}
