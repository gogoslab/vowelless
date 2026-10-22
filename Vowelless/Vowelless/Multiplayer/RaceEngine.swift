import Foundation
import Observation

/// Messages exchanged between the phones in a race. One phone (the host) is the referee.
enum RaceMessage: Codable, Equatable {
    /// Host -> all: the clues for this match and the difficulty to show them at.
    case setup(puzzles: [PuzzleRef], difficulty: String)
    /// Host -> all: clue `index` is live.
    case startRound(index: Int)
    /// Player -> host: "I answered clue `index` correctly".
    case claim(index: Int)
    /// Host -> all: who won clue `index` (`nil` if nobody solved it in time).
    case roundResult(index: Int, winner: String?)
    /// Host -> all: the match is over.
    case finished
}

/// A puzzle as sent over the network; both phones look it up in their bundled puzzles.
struct PuzzleRef: Codable, Equatable {
    let answer: String
    let category: Category

    init(_ puzzle: Puzzle) {
        answer = puzzle.answer
        category = puzzle.category
    }

    var puzzle: Puzzle {
        PuzzleStore.builtIn.first { $0.answer == answer && $0.category == category }
            ?? Puzzle(answer: answer, category: category)
    }
}

/// The rules of a real-time race: everyone sees the same clue, the first correct answer wins it.
/// The host decides who was first, so every phone shows the same result.
@MainActor
@Observable
final class RaceEngine {
    enum Phase: Equatable {
        case waitingForSetup
        case countdown
        case playing(index: Int)
        case roundOver(index: Int, winner: String?)
        case finished
        case opponentLeft
    }

    enum Outcome: Equatable { case won, lost, tied }

    struct Timing {
        var countdown: Duration = .seconds(3)
        var roundLength: Duration = .seconds(45)
        var betweenRounds: Duration = .seconds(2.5)
    }

    static let rounds = 10

    let localPlayerID: String
    let playerIDs: [String]
    let playerNames: [String: String]
    var timing: Timing
    /// Sends a message to every other player.
    var send: (RaceMessage) -> Void = { _ in }
    /// Called on every phone when a clue goes live (used to drive bot opponents).
    var onRoundStart: (Int) -> Void = { _ in }

    private(set) var phase: Phase = .waitingForSetup
    private(set) var puzzles: [Puzzle] = []
    private(set) var difficulty: Difficulty = .easy
    private(set) var scores: [String: Int]
    /// True after this player sent a correct answer that the host hasn't ruled on yet.
    private(set) var waitingForRuling = false
    /// When the current clue started, for the countdown bar.
    private(set) var roundStartedAt: Date?

    private var roundTimer: Task<Void, Never>?
    private var nextTimer: Task<Void, Never>?

    init(localPlayerID: String, playerIDs: [String], playerNames: [String: String], timing: Timing = Timing()) {
        self.localPlayerID = localPlayerID
        self.playerIDs = playerIDs.sorted()
        self.playerNames = playerNames
        self.timing = timing
        scores = Dictionary(uniqueKeysWithValues: playerIDs.map { ($0, 0) })
    }

    /// The player with the lowest ID referees, so every phone agrees without negotiating.
    var hostID: String { playerIDs.first ?? localPlayerID }
    var isHost: Bool { hostID == localPlayerID }
    var opponentIDs: [String] { playerIDs.filter { $0 != localPlayerID } }

    var currentPuzzle: Puzzle? {
        switch phase {
        case .playing(let index), .roundOver(let index, _): puzzles.indices.contains(index) ? puzzles[index] : nil
        default: nil
        }
    }

    var currentIndex: Int? {
        switch phase {
        case .playing(let index), .roundOver(let index, _): index
        default: nil
        }
    }

    var outcome: Outcome? {
        guard phase == .finished || phase == .opponentLeft else { return nil }
        if phase == .opponentLeft { return .won }
        let mine = scores[localPlayerID, default: 0]
        let best = opponentIDs.map { scores[$0, default: 0] }.max() ?? 0
        return mine > best ? .won : mine < best ? .lost : .tied
    }

    func name(of playerID: String) -> String {
        playerID == localPlayerID ? "You" : playerNames[playerID] ?? "Opponent"
    }

    // MARK: - Host

    /// Host only: picks the clues and starts the match.
    func begin(pool: [Puzzle], difficulty: Difficulty) {
        guard isHost, phase == .waitingForSetup else { return }
        let chosen = Array(pool.shuffled().prefix(Self.rounds))
        let refs = chosen.map(PuzzleRef.init)
        apply(.setup(puzzles: refs, difficulty: difficulty.rawValue))
        send(.setup(puzzles: refs, difficulty: difficulty.rawValue))
        schedule(after: timing.countdown) { [weak self] in self?.startRound(0) }
    }

    private func startRound(_ index: Int) {
        guard index < puzzles.count else {
            broadcast(.finished)
            return
        }
        broadcast(.startRound(index: index))
        roundTimer?.cancel()
        roundTimer = Task { [weak self, timing] in
            try? await Task.sleep(for: timing.roundLength)
            guard !Task.isCancelled else { return }
            self?.resolve(index: index, winner: nil)
        }
    }

    private func resolve(index: Int, winner: String?) {
        guard isHost, phase == .playing(index: index) else { return }
        roundTimer?.cancel()
        broadcast(.roundResult(index: index, winner: winner))
        schedule(after: timing.betweenRounds) { [weak self] in self?.startRound(index + 1) }
    }

    private func broadcast(_ message: RaceMessage) {
        apply(message)
        send(message)
    }

    private func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) {
        nextTimer?.cancel()
        nextTimer = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        }
    }

    // MARK: - Everyone

    /// The local player typed or said the right answer.
    func submitCorrect() {
        guard case .playing(let index) = phase, !waitingForRuling else { return }
        if isHost {
            resolve(index: index, winner: localPlayerID)
        } else {
            waitingForRuling = true
            send(.claim(index: index))
        }
    }

    func receive(_ message: RaceMessage, from playerID: String) {
        switch message {
        case .claim(let index):
            // Only the host rules; the first claim to arrive wins, later ones find the round closed.
            if isHost, playerIDs.contains(playerID) { resolve(index: index, winner: playerID) }
        case .setup, .startRound, .roundResult, .finished:
            guard playerID == hostID else { return }
            apply(message)
        }
    }

    /// Another player disconnected. With two players, the one who stays wins.
    func playerLeft(_ playerID: String) {
        guard phase != .finished, playerID != localPlayerID else { return }
        cancelTimers()
        phase = .opponentLeft
    }

    func leave() {
        cancelTimers()
    }

    private func cancelTimers() {
        roundTimer?.cancel()
        nextTimer?.cancel()
    }

    private func apply(_ message: RaceMessage) {
        switch message {
        case .setup(let refs, let difficulty):
            puzzles = refs.map(\.puzzle)
            self.difficulty = Difficulty(rawValue: difficulty) ?? .easy
            phase = .countdown
        case .startRound(let index):
            waitingForRuling = false
            roundStartedAt = .now
            phase = .playing(index: index)
            onRoundStart(index)
        case .roundResult(let index, let winner):
            waitingForRuling = false
            if let winner { scores[winner, default: 0] += 1 }
            phase = .roundOver(index: index, winner: winner)
        case .finished:
            cancelTimers()
            phase = .finished
        case .claim:
            break
        }
    }
}
