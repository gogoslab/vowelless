import Foundation

/// A race against a computer opponent standing in for a missing player, played entirely on this phone.
/// The local player hosts; the bot "answers" by sending claims after a human-like delay.
@MainActor
final class BotRace {
    enum Level: String, CaseIterable, Identifiable {
        case easy, medium, hard

        var id: String { rawValue }

        /// The level of a bot standing in for a missing player: mostly medium, sometimes easy or hard.
        static func randomStandIn() -> Level {
            switch Double.random(in: 0..<1) {
            case ..<0.25: .easy
            case ..<0.8: .medium
            default: .hard
            }
        }

        var behavior: Behavior {
            switch self {
            case .easy: Behavior(solveChance: 0.65, delay: 30...42)
            case .medium: Behavior(solveChance: 0.8, delay: 24...38)
            case .hard: Behavior(solveChance: 0.95, delay: 20...32)
            }
        }

    }

    struct Behavior {
        /// Chance of solving a clue before the time runs out.
        var solveChance: Double
        /// Seconds the bot takes when it does solve one.
        var delay: ClosedRange<Double>
    }

    /// Bots stand in for missing players and look like them, so they get ordinary player names.
    static let names = [
        "maria_k", "Alex88", "TheRealDan", "sofi.r", "Mihai_B", "lucaa", "JennyP", "tomtom",
        "Ana-Maria", "kev_in", "Priya22", "Marco.R", "ellie", "NoahW", "zoe_x", "Daniel_C",
        "Ioana", "sam_plays", "Lena.M", "chris99", "Andrei", "katie_b", "Omar_T", "julia",
    ]

    /// Seconds into a clue after which the bot no longer answers (the clue lasts 45).
    static let latestAnswer: Double = 43

    static let localID = "A-local"
    static let botID = "B-bot"

    let level: Level
    let name: String
    let engine: RaceEngine
    private let behavior: Behavior
    private let difficulty: Difficulty
    private var answerTask: Task<Void, Never>?

    init(level: Level, pool: [Puzzle], difficulty: Difficulty,
         behavior: Behavior? = nil, timing: RaceEngine.Timing = RaceEngine.Timing()) {
        self.level = level
        self.behavior = behavior ?? level.behavior
        self.difficulty = difficulty
        name = Self.names.randomElement() ?? "Player"
        engine = RaceEngine(
            localPlayerID: Self.localID,
            playerIDs: [Self.localID, Self.botID],
            playerNames: [Self.botID: name],
            timing: timing
        )
        engine.onRoundStart = { [weak self] index in self?.play(index) }
        engine.begin(pool: pool, difficulty: difficulty)
    }

    private func play(_ index: Int) {
        answerTask?.cancel()
        guard Double.random(in: 0..<1) < behavior.solveChance else { return }
        // Harder clue layouts slow the bot down, like they slow people down.
        let slowdown: Double = switch difficulty {
        case .easy: 1
        case .medium: 1.2
        case .hard: 1.4
        }
        // A person needs time to read and type, so the bot never answers before the range starts;
        // harder layouts only stretch the time above that, and it still answers before the clock runs out.
        let base = Double.random(in: behavior.delay)
        let floor = behavior.delay.lowerBound
        let playerLead = engine.scores[Self.localID, default: 0] - engine.scores[Self.botID, default: 0]
        let seconds = (floor + (base - floor) * slowdown) * Self.catchUpFactor(playerLead: playerLead)
        // Too slow to beat the clock: the bot misses this clue, like a player who runs out of time.
        guard seconds <= Self.latestAnswer else { return }
        answerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            self.engine.receive(.claim(index: index), from: Self.botID)
        }
    }

    /// Keeps races close: the bot speeds up when the player leads and slows down when it leads.
    /// The answer time is multiplied by 1 - lead/10, with the lead capped at 8 either way
    /// (player 2 ahead -> x0.8, bot 3 ahead -> x1.3).
    static func catchUpFactor(playerLead: Int) -> Double {
        let lead = min(max(playerLead, -maxLead), maxLead)
        return 1 - Double(lead) / 10
    }

    static let maxLead = 8

    func leave() {
        answerTask?.cancel()
        engine.leave()
    }
}
