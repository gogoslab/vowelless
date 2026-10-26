import SwiftUI

struct GameView: View {
    @State var session: GameSession
    var accent: Color = Category.song.color

    @Environment(\.dismiss) private var dismiss
    @AppStorage(Difficulty.storageKey) private var difficulty: Difficulty = .easy
    @State private var guess = ""
    @State private var showVowels = false
    @State private var showShop = false
    @State private var speech = SpeechRecognizer()
    @State private var micProblem: SpeechRecognizer.Status?
    @Environment(Store.self) private var store
    @Environment(RewardedAds.self) private var ads
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
        .sensoryFeedback(.impact(weight: .light), trigger: session.revealedVowels)
        .sensoryFeedback(.start, trigger: speech.isListening)
        .onChange(of: session.index) {
            speech.cancel()
            micProblem = nil
        }
        .onDisappear { speech.cancel() }
        .sheet(isPresented: $showShop) {
            ShopView()
                .fontDesign(.rounded)
                .environment(session.wallet)
                .environment(store)
                .environment(ads)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .black))
                }
                .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 4, cornerRadius: 14, horizontalPadding: 14))

                Label("\(session.score)", systemImage: "star.fill")
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(Category.artist.color)
                    .contentTransition(.numericText())
                    .fixedSize()

                Button { showShop = true } label: {
                    CoinLabel(amount: session.wallet.coins, size: 18)
                }
                .modifier(Shake(amount: 6, animatableData: CGFloat(cantAffordTaps)))
                .animation(.spring(bounce: 0.4), value: session.wallet.coins)
                .accessibilityLabel("\(session.wallet.coins) coins. Get more coins")

                Spacer(minLength: 0)

                if let puzzle = session.current {
                    helpers(accent: puzzle.category.color)
                }
            }

            GeometryReader { geo in
                Capsule().fill(.black.opacity(0.25))
                    .overlay(alignment: .leading) {
                        Capsule().fill(accent)
                            .frame(width: max(10, geo.size.width * session.progress))
                            .animation(.spring(bounce: 0.4), value: session.progress)
                    }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// Bumped each time the player can't afford a helper, to wiggle the balance.
    @State private var cantAffordTaps = 0

    private func buy(_ action: () -> Void) {
        withAnimation(.spring(bounce: 0.5)) { action() }
        if session.cantAfford != nil {
            withAnimation(.default) { cantAffordTaps += 1 }
        }
    }

    // MARK: - Helpers

    /// The hint and vowel buttons in the top-right corner.
    private func helpers(accent: Color) -> some View {
        HStack(spacing: 8) {
            Button {
                buy { session.showHint() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(.headline, design: .rounded, weight: .black))
                    if session.canShowHint {
                        CoinLabel(amount: session.nextHintCost, size: 15, color: Theme.ink)
                    }
                }
                .fixedSize()
            }
            .buttonStyle(ChunkyButtonStyle(color: Category.artist.color, foreground: Theme.ink, depth: 4, cornerRadius: 14, horizontalPadding: 12))
            .disabled(!session.canShowHint)
            .opacity(session.canShowHint ? 1 : 0.5)
            .accessibilityLabel("Show a hint for \(session.nextHintCost) coins, \(session.hintsRemaining) left")

            Button { showVowels = true } label: {
                Text("A?")
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .fixedSize()
            }
            .buttonStyle(ChunkyButtonStyle(color: accent, depth: 4, cornerRadius: 14, horizontalPadding: 12))
            .disabled(!anyVowelLeft)
            .opacity(anyVowelLeft ? 1 : 0.5)
            .accessibilityLabel("Reveal a vowel for \(Economy.vowelCost) coins")
            .popover(isPresented: $showVowels, arrowEdge: .top) {
                vowelPicker(accent: accent)
                    .presentationCompactAdaptation(.popover)
                    .presentationBackground(Theme.tileFace)
            }
        }
    }

    private static let vowels: [Character] = ["A", "E", "I", "O", "U"]

    private var anyVowelLeft: Bool { Self.vowels.contains { session.canReveal($0) } }

    // MARK: - Puzzle

    private func puzzleView(_ puzzle: Puzzle) -> some View {
        VStack(spacing: 16) {
            // Centered when it fits; scrolls when hints and the keyboard leave too little room.
            ViewThatFits(in: .vertical) {
                clueArea(puzzle)
                    .frame(maxHeight: .infinity)
                ScrollView {
                    clueArea(puzzle)
                        .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }

            controls(puzzle)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .id(session.index)
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
        .onAppear { focused = true }
    }

    private func clueArea(_ puzzle: Puzzle) -> some View {
        VStack(spacing: 20) {
            CategoryBadge(puzzle: puzzle)

            ClueBoard(
                answer: puzzle.answer,
                revealed: session.revealed,
                difficulty: difficulty,
                revealedVowels: session.revealedVowels,
                accent: puzzle.category.color
            )
            .modifier(Shake(animatableData: CGFloat(session.wrongAttempts)))
            .animation(.default, value: session.wrongAttempts)
            .padding(.horizontal, 20)

            if session.hintsShown > 0 {
                VStack(spacing: 10) {
                    ForEach(0..<session.hintsShown, id: \.self) { i in
                        HintCard(number: i + 1, text: puzzle.hints[i], accent: puzzle.category.color)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
            }

            feedback
        }
    }

    /// Points just earned: hints are only reset by `next()`, so this still reflects the solved puzzle.
    private var lastPoints: Int { session.pointsAvailable }

    @ViewBuilder
    private var feedback: some View {
        Group {
            switch (session.revealed, session.lastGuessCorrect) {
            case (true, true):
                HStack(spacing: 8) {
                    Text("Nailed it! +\(lastPoints) ⭐")
                    CoinLabel(amount: session.lastReward, size: 20, color: Theme.correct)
                }
                .foregroundStyle(Theme.correct)
            case (true, _): Text("So close! Next one 💪").foregroundStyle(Category.artist.color)
            case (false, false): Text("Nope, try again!").foregroundStyle(Theme.wrong)
            case (false, _) where micProblem != nil:
                Text(micProblem == .denied
                     ? "Turn on Microphone and Speech Recognition in Settings to answer out loud."
                     : "Speech recognition isn't available right now.")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.orange)
            case (false, _) where session.cantAfford != nil:
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Text("Not enough coins! Need")
                        CoinLabel(amount: session.cantAfford!, size: 20, color: Theme.orange)
                    }
                    .foregroundStyle(Theme.orange)
                    HStack(spacing: 10) {
                        FreeCoinsCard(compact: true)
                        Button { showShop = true } label: {
                            Label("Get coins", systemImage: "plus.circle.fill")
                                .font(.system(.headline, design: .rounded, weight: .black))
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.correct, depth: 5, cornerRadius: 16))
                    }
                }
            case (false, nil) where session.missedVowel != nil:
                Text("No \(String(session.missedVowel!))'s in this one!").foregroundStyle(Theme.orange)
            default: Text("Worth " + String(repeating: "⭐", count: session.pointsAvailable)).foregroundStyle(.white.opacity(0.85))
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
                TextField("", text: $guess, prompt: Text(speech.isListening ? "Listening…" : "Type or say your guess…").foregroundStyle(Theme.ink.opacity(0.4)))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .tint(accent)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(submit)
                    .padding(.leading, 18)
                    .padding(.trailing, 64)
                    .padding(.vertical, 16)
                    .overlay(alignment: .trailing) { micButton(puzzle) }
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.tileFace))
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.tileFace.darker()).offset(y: 5))
                    .padding(.bottom, 5)

                HStack(spacing: 12) {
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

    /// The popup: chunky A E I O U tiles; tapping one drops that vowel into the clue and closes it.
    private func vowelPicker(accent: Color) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Text("Reveal a vowel ·")
                CoinLabel(amount: Economy.vowelCost, size: 15, color: Theme.ink)
                Text("each")
            }
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(Theme.ink.opacity(0.7))
            HStack(spacing: 8) {
                ForEach(Self.vowels, id: \.self) { vowel in
                    let available = session.canReveal(vowel)
                    Button {
                        showVowels = false
                        buy { session.reveal(vowel) }
                    } label: {
                        Text(String(vowel))
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .frame(width: 22)
                    }
                    .buttonStyle(ChunkyButtonStyle(
                        color: available ? accent : .white,
                        foreground: available ? .white : Theme.ink,
                        depth: available ? 5 : 2,
                        cornerRadius: 14,
                        horizontalPadding: 12
                    ))
                    .disabled(!available)
                    .opacity(available ? 1 : 0.4)
                    .accessibilityLabel(available ? "Reveal the letter \(vowel)" : "\(vowel) already revealed")
                }
            }
        }
        .padding(16)
        .fontDesign(.rounded)
    }

    @ViewBuilder
    private func micButton(_ puzzle: Puzzle) -> some View {
        let listening = speech.isListening
        Button {
            if listening { speech.stop() } else { Task { await listen(for: puzzle) } }
        } label: {
            Image(systemName: listening ? "waveform" : "mic.fill")
                .font(.system(size: 20, weight: .black))
                .symbolEffect(.variableColor.iterative, isActive: listening)
                .frame(width: 44, height: 44)
                .foregroundStyle(.white)
                .background(Circle().fill(listening ? Theme.wrong : accent))
                .background(Circle().fill((listening ? Theme.wrong : accent).darker()).offset(y: 3))
                .scaleEffect(listening ? 1.08 : 1)
                .animation(.spring(bounce: 0.5), value: listening)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 8)
        .accessibilityLabel(listening ? "Stop listening" : "Say your answer")
    }

    private func listen(for puzzle: Puzzle) async {
        focused = false
        guess = ""
        await speech.start(hints: [puzzle.answer]) { heard in
            guess = heard
            // Accept as soon as it matches, without waiting for the player to stop talking.
            return AnswerMatcher.matches(heard, puzzle.answer)
        } onFinish: { heard in
            guard !heard.isEmpty, session.current == puzzle, !session.revealed else { return }
            guess = heard
            submit()
        }
        if speech.status == .denied || speech.status == .unavailable {
            withAnimation { micProblem = speech.status }
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
                ForEach(Array("\(session.score)/\(session.maxScore)".enumerated()), id: \.offset) { i, ch in
                    LetterTile(letter: ch, size: 52, tilt: Theme.tilt(i))
                }
            }
            Text("⭐ \(session.correctCount) of \(session.puzzles.count) guessed")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 8) {
                Text("Coins won:")
                CoinLabel(amount: session.coinsEarned, size: 22)
            }
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(.white.opacity(0.85))
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

/// A revealed hint: a small chunky card with a light bulb.
private struct HintCard: View {
    let number: Int
    let text: String
    let accent: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(accent.darker(0.15))
            Text(text)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(shape.fill(Theme.tileFace))
        .background(shape.fill(Theme.tileFace.darker()).offset(y: 4))
        .padding(.bottom, 4)
        .accessibilityLabel("Hint \(number): \(text)")
    }
}

#Preview {
    NavigationStack {
        GameView(session: GameSession(
            puzzles: [Puzzle(answer: "Bohemian Rhapsody", category: .song, hints: ["A six-minute rock opera with no chorus", "By Queen"])],
            wallet: Wallet()
        ))
    }
    .environment(Store(wallet: Wallet()))
    .environment(RewardedAds())
    .environment(Wallet())
    .fontDesign(.rounded)
}
