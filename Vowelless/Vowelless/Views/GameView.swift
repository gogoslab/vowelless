import SwiftUI

struct GameView: View {
    @State var session: GameSession
    var accent: Color = Category.song.color

    @Environment(\.dismiss) private var dismiss
    @AppStorage(Difficulty.storageKey) private var difficulty: Difficulty = .easy
    @State private var guess = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let puzzle = session.current {
                puzzleView(puzzle)
            } else {
                resultView
            }
        }
        .background(PlayfulBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.error, trigger: session.wrongAttempts)
        .sensoryFeedback(.success, trigger: session.score)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .black))
            }
            .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 4, cornerRadius: 14))

            GeometryReader { geo in
                Capsule().fill(.black.opacity(0.25))
                    .overlay(alignment: .leading) {
                        Capsule().fill(accent)
                            .frame(width: max(18, geo.size.width * session.progress))
                            .animation(.spring(bounce: 0.4), value: session.progress)
                    }
            }
            .frame(height: 16)

            Label("\(session.score)", systemImage: "star.fill")
                .font(.system(.headline, design: .rounded, weight: .black))
                .foregroundStyle(Category.artist.color)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Puzzle

    private func puzzleView(_ puzzle: Puzzle) -> some View {
        VStack(spacing: 28) {
            Spacer()

            Label(puzzle.category.title, systemImage: puzzle.category.symbol)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(puzzle.category.onColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(puzzle.category.color))
                .background(Capsule().fill(puzzle.category.color.darker()).offset(y: 4))

            ClueBoard(answer: puzzle.answer, revealed: session.revealed, difficulty: difficulty, accent: puzzle.category.color)
                .modifier(Shake(animatableData: CGFloat(session.wrongAttempts)))
                .animation(.default, value: session.wrongAttempts)
                .padding(.horizontal, 20)

            feedback

            Spacer()

            controls(puzzle)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .id(session.index)
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
        .onAppear { focused = true }
    }

    @ViewBuilder
    private var feedback: some View {
        Group {
            switch (session.revealed, session.lastGuessCorrect) {
            case (true, true): Text("Nailed it! 🎉").foregroundStyle(Theme.correct)
            case (true, _): Text("So close! Next one 💪").foregroundStyle(Category.artist.color)
            case (false, false): Text("Nope, try again!").foregroundStyle(Theme.wrong)
            default: Text(" ")
            }
        }
        .font(.system(.title3, design: .rounded, weight: .black))
        .shadow(color: .black.opacity(0.2), radius: 0, y: 2)
    }

    @ViewBuilder
    private func controls(_ puzzle: Puzzle) -> some View {
        if session.revealed {
            Button {
                guess = ""
                withAnimation(.spring(duration: 0.45)) { session.next() }
            } label: {
                Text(session.index + 1 == session.puzzles.count ? "See score" : "Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.correct, depth: 8))
        } else {
            VStack(spacing: 14) {
                TextField("", text: $guess, prompt: Text("Type your guess…").foregroundStyle(Theme.ink.opacity(0.4)))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .tint(accent)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(submit)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.tileFace))
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.tileFace.darker()).offset(y: 5))
                    .padding(.bottom, 5)

                HStack(spacing: 14) {
                    Button("Give up") { withAnimation(.spring(bounce: 0.5)) { session.giveUp() } }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.wrong))
                    Button(action: submit) {
                        Text("Guess!").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChunkyButtonStyle(color: accent))
                }
            }
        }
    }

    private func submit() {
        withAnimation(.spring(bounce: 0.5)) { session.submit(guess) }
        focused = !session.revealed
    }

    // MARK: - Result

    private var resultView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🏆")
                .font(.system(size: 96))
                .shadow(color: .black.opacity(0.25), radius: 0, y: 6)
            Text("Round complete!")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                ForEach(Array("\(session.score)/\(session.puzzles.count)".enumerated()), id: \.offset) { i, ch in
                    LetterTile(letter: ch, size: 56, tilt: Theme.tilt(i))
                }
            }
            Spacer()
            VStack(spacing: 14) {
                Button {
                    withAnimation(.spring) { session.restart() }
                } label: {
                    Label("Play again", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.correct, depth: 8))

                Button { dismiss() } label: {
                    Label("Home", systemImage: "house.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink))
            }
        }
        .padding(20)
    }
}

#Preview {
    NavigationStack {
        GameView(session: GameSession(puzzles: [Puzzle(answer: "Bohemian Rhapsody", category: .song)]))
    }
    .fontDesign(.rounded)
}
