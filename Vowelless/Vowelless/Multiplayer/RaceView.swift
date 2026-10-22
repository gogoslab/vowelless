import SwiftUI

/// A live race: same clue on both phones, first correct answer wins the point.
struct RaceView: View {
    let race: ActiveRace
    var onExit: () -> Void

    @Environment(Wallet.self) private var wallet
    @State private var guess = ""
    @State private var wrongAttempts = 0
    @State private var speech = SpeechRecognizer()
    @State private var rewarded = false
    @State private var reward = 0
    @State private var confirmLeave = false
    @FocusState private var focused: Bool

    private var engine: RaceEngine { race.engine }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            switch engine.phase {
            case .waitingForSetup, .countdown:
                waiting
            case .playing, .roundOver:
                if let puzzle = engine.currentPuzzle { round(puzzle) }
            case .finished, .opponentLeft:
                result
            }
        }
        .background(PlayfulBackground())
        .sensoryFeedback(.error, trigger: wrongAttempts)
        .sensoryFeedback(.success, trigger: engine.scores[engine.localPlayerID])
        .onChange(of: engine.currentIndex) {
            speech.cancel()
            guess = ""
            if case .playing = engine.phase { focused = true }
        }
        .onChange(of: engine.outcome) { _, outcome in award(outcome) }
        .onDisappear {
            speech.cancel()
            race.leave()
        }
        .confirmationDialog("Leave the race?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { onExit() }
        } message: {
            Text("Your opponent will win this match.")
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                if engine.phase == .finished || engine.phase == .opponentLeft { onExit() } else { confirmLeave = true }
            } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .black))
            }
            .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 4, cornerRadius: 14, horizontalPadding: 14))

            Spacer(minLength: 0)
            scorePill(engine.localPlayerID, color: Theme.correct)
            Text("–")
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(.white.opacity(0.8))
            ForEach(engine.opponentIDs, id: \.self) { scorePill($0, color: Category.song.color) }
            Spacer(minLength: 0)

            if let index = engine.currentIndex {
                Text("\(index + 1)/\(engine.puzzles.count)")
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func scorePill(_ playerID: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(engine.name(of: playerID))
                .lineLimit(1)
                .frame(maxWidth: 90)
            Text("\(engine.scores[playerID, default: 0])")
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .font(.system(.headline, design: .rounded, weight: .black))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(color))
        .background(Capsule().fill(color.darker()).offset(y: 3))
        .animation(.spring(bounce: 0.5), value: engine.scores[playerID])
    }

    // MARK: - Waiting

    private var waiting: some View {
        VStack(spacing: 24) {
            Spacer()
            HStack(spacing: 6) {
                ForEach(Array("VS".enumerated()), id: \.offset) { i, letter in
                    LetterTile(letter: letter, size: 64, face: Theme.palette[i], ink: .white, tilt: Theme.tilt(i))
                }
            }
            Text(engine.opponentIDs.map(engine.name(of:)).joined(separator: ", "))
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(.white)
            Text(engine.phase == .countdown ? "Get ready…" : "Connecting…")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(.white.opacity(0.8))
            ProgressView().tint(.white).controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Round

    private func round(_ puzzle: Puzzle) -> some View {
        let isOver: Bool = if case .roundOver = engine.phase { true } else { false }
        return VStack(spacing: 16) {
            ViewThatFits(in: .vertical) {
                clueArea(puzzle, isOver: isOver).frame(maxHeight: .infinity)
                ScrollView { clueArea(puzzle, isOver: isOver).padding(.vertical, 12) }
                    .scrollIndicators(.hidden)
            }
            if !isOver { answerField(puzzle) }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .id(engine.currentIndex)
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
        .animation(.spring(duration: 0.45), value: engine.currentIndex)
    }

    private func clueArea(_ puzzle: Puzzle, isOver: Bool) -> some View {
        VStack(spacing: 20) {
            Label(puzzle.category.title, systemImage: puzzle.category.symbol)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(puzzle.category.onColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(puzzle.category.color))
                .background(Capsule().fill(puzzle.category.color.darker()).offset(y: 4))

            ClueBoard(answer: puzzle.answer, revealed: isOver, difficulty: engine.difficulty, accent: puzzle.category.color)
                .modifier(Shake(animatableData: CGFloat(wrongAttempts)))
                .animation(.default, value: wrongAttempts)
                .animation(.spring(bounce: 0.4), value: isOver)
                .padding(.horizontal, 20)

            if !isOver { timerBar(color: puzzle.category.color) }

            feedback
        }
    }

    private func timerBar(color: Color) -> some View {
        TimelineView(.animation) { context in
            let total = engine.timing.roundLength.seconds
            let elapsed = engine.roundStartedAt.map { context.date.timeIntervalSince($0) } ?? 0
            let left = max(0, 1 - elapsed / total)
            GeometryReader { geo in
                Capsule().fill(.black.opacity(0.25))
                    .overlay(alignment: .leading) {
                        Capsule().fill(left < 0.25 ? Theme.wrong : color)
                            .frame(width: max(8, geo.size.width * left))
                    }
            }
            .frame(height: 10)
            .padding(.horizontal, 40)
        }
    }

    @ViewBuilder
    private var feedback: some View {
        Group {
            if case .roundOver(_, let winner) = engine.phase {
                if winner == engine.localPlayerID {
                    Text("⚡ You got it first! +1").foregroundStyle(Theme.correct)
                } else if let winner {
                    Text("⚡ \(engine.name(of: winner)) answered first!").foregroundStyle(Category.artist.color)
                } else {
                    Text("⏰ Time's up!").foregroundStyle(Theme.orange)
                }
            } else if engine.waitingForRuling {
                Text("Checking…").foregroundStyle(.white.opacity(0.85))
            } else if wrongAttempts > 0 && !guess.isEmpty {
                Text("Nope, try again!").foregroundStyle(Theme.wrong)
            } else {
                Text("First correct answer wins!").foregroundStyle(.white.opacity(0.85))
            }
        }
        .font(.system(.title3, design: .rounded, weight: .black))
        .multilineTextAlignment(.center)
        .shadow(color: .black.opacity(0.2), radius: 0, y: 2)
    }

    private func answerField(_ puzzle: Puzzle) -> some View {
        HStack(spacing: 12) {
            TextField("", text: $guess, prompt: Text(speech.isListening ? "Listening…" : "Type or say it, fast!").foregroundStyle(Theme.ink.opacity(0.4)))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
                .tint(puzzle.category.color)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .focused($focused)
                .submitLabel(.go)
                .onSubmit { check(guess, for: puzzle) }
                .padding(.leading, 18)
                .padding(.trailing, 64)
                .padding(.vertical, 16)
                .overlay(alignment: .trailing) { micButton(puzzle) }
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.tileFace))
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.tileFace.darker()).offset(y: 5))
                .padding(.bottom, 5)
                .onAppear { focused = true }
        }
        .disabled(engine.waitingForRuling)
    }

    private func micButton(_ puzzle: Puzzle) -> some View {
        let listening = speech.isListening
        return Button {
            if listening {
                speech.stop()
            } else {
                Task {
                    focused = false
                    guess = ""
                    await speech.start(hints: [puzzle.answer]) { heard in
                        guess = heard
                        return AnswerMatcher.matches(heard, puzzle.answer)
                    } onFinish: { heard in
                        guard !heard.isEmpty, engine.currentPuzzle == puzzle else { return }
                        check(heard, for: puzzle)
                    }
                }
            }
        } label: {
            Image(systemName: listening ? "waveform" : "mic.fill")
                .font(.system(size: 20, weight: .black))
                .symbolEffect(.variableColor.iterative, isActive: listening)
                .frame(width: 44, height: 44)
                .foregroundStyle(.white)
                .background(Circle().fill(listening ? Theme.wrong : puzzle.category.color))
                .background(Circle().fill((listening ? Theme.wrong : puzzle.category.color).darker()).offset(y: 3))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 8)
        .accessibilityLabel(listening ? "Stop listening" : "Say your answer")
    }

    private func check(_ text: String, for puzzle: Puzzle) {
        guard case .playing = engine.phase else { return }
        if AnswerMatcher.matches(text, puzzle.answer) {
            engine.submitCorrect()
        } else {
            withAnimation(.default) { wrongAttempts += 1 }
            focused = true
        }
    }

    // MARK: - Result

    private var result: some View {
        VStack(spacing: 22) {
            Spacer()
            Text(resultEmoji)
                .font(.system(size: 96))
                .shadow(color: .black.opacity(0.25), radius: 0, y: 6)
            Text(resultTitle)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            HStack(spacing: 14) {
                scorePill(engine.localPlayerID, color: Theme.correct)
                ForEach(engine.opponentIDs, id: \.self) { scorePill($0, color: Category.song.color) }
            }
            HStack(spacing: 8) {
                Text("Coins won:")
                CoinLabel(amount: reward, size: 22)
            }
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Button(action: onExit) {
                Label("Home", systemImage: "house.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.correct, depth: 8))
        }
        .padding(20)
    }

    private var resultEmoji: String {
        switch engine.outcome {
        case .won: "🏆"
        case .lost: "🥈"
        default: "🤝"
        }
    }

    private var resultTitle: String {
        if engine.phase == .opponentLeft { return "Your opponent left.\nYou win!" }
        switch engine.outcome {
        case .won: return "You won!"
        case .lost: return "\(engine.opponentIDs.first.map(engine.name(of:)) ?? "They") won!"
        default: return "It's a tie!"
        }
    }

    private func award(_ outcome: RaceEngine.Outcome?) {
        guard let outcome, !rewarded else { return }
        rewarded = true
        reward = switch outcome {
        case .won: race.rewards.won
        case .tied: race.rewards.tied
        case .lost: race.rewards.lost
        }
        wallet.earn(reward)
    }
}

private extension Duration {
    var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
