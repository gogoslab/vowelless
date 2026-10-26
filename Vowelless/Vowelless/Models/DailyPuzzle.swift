import Foundation
import Observation

/// How a clue went, for the daily puzzle's shareable result.
enum ClueResult: String, Codable {
    /// Solved without hints or vowels.
    case clean
    /// Solved with help.
    case helped
    /// Given up, or not reached.
    case missed

    var emoji: String {
        switch self {
        case .clean: "🟩"
        case .helped: "🟨"
        case .missed: "🟥"
        }
    }
}

/// The same five clues for everyone each calendar day, one try per day.
@Observable
final class DailyPuzzle {
    static let clueCount = 5
    /// Coins for each solved clue, and a bonus for solving all five.
    static let coinsPerClue = 10
    static let perfectBonus = 25
    /// Daily #1. Changing this renumbers every puzzle.
    static let firstDay = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 10, day: 26)

    private static let numberKey = "daily.number"
    private static let resultsKey = "daily.results"
    private static let scoreKey = "daily.score"
    private static let streakKey = "daily.streak"
    private static let lastCompletedKey = "daily.lastCompleted"
    private static let lockedNumberKey = "daily.lockedNumber"
    private static let lockedPuzzlesKey = "daily.lockedPuzzles"

    let feed: DailyFeed

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    /// The puzzle number last played on this phone, and how it went.
    private(set) var playedNumber: Int
    private(set) var results: [ClueResult]
    private(set) var score: Int
    /// Days in a row the daily puzzle was played.
    private(set) var streak: Int
    private var lastCompleted: Int

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, feed: DailyFeed = DailyFeed(), now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.feed = feed
        self.calendar = calendar
        self.now = now
        playedNumber = defaults.integer(forKey: Self.numberKey)
        results = (defaults.stringArray(forKey: Self.resultsKey) ?? []).compactMap(ClueResult.init(rawValue:))
        score = defaults.integer(forKey: Self.scoreKey)
        streak = defaults.integer(forKey: Self.streakKey)
        lastCompleted = defaults.integer(forKey: Self.lastCompletedKey)
    }

    /// Today's puzzle number: the same on every phone on the same calendar date.
    var todayNumber: Int { Self.number(for: now(), calendar: calendar) }

    var isPlayedToday: Bool { playedNumber > 0 && playedNumber == todayNumber }

    /// The streak as it stands today (broken if yesterday's puzzle was skipped).
    var currentStreak: Int { lastCompleted >= todayNumber - 1 ? streak : 0 }

    static func number(for date: Date, calendar: Calendar) -> Int {
        let start = calendar.date(from: firstDay) ?? date
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0
        return max(1, days + 1)
    }

    /// Four easy clues from different categories, then a hard one, picked the same way on every phone.
    static func puzzles(for number: Int, from pool: [Puzzle]) -> [Puzzle] {
        var rng = SeededGenerator(seed: UInt64(bitPattern: Int64(number)) &* 0x9E37_79B9_7F4A_7C15 &+ 1)
        let sorted = pool.sorted { ($0.category.rawValue, $0.answer) < ($1.category.rawValue, $1.answer) }
        let easy = sorted.filter { $0.level == .easy }.shuffled(using: &rng)
        let hard = sorted.filter { $0.level == .hard }.shuffled(using: &rng)

        var picked: [Puzzle] = []
        for puzzle in easy where picked.count < clueCount - 1 && !picked.contains(where: { $0.category == puzzle.category }) {
            picked.append(puzzle)
        }
        if let last = hard.first(where: { candidate in !picked.contains { $0.category == candidate.category } }) ?? hard.first {
            picked.append(last)
        }
        return picked
    }

    /// Today's puzzles: the published ones if this month is stored, otherwise the app's own pick.
    func todayPuzzles(from pool: [Puzzle] = PuzzleStore.builtIn) -> [Puzzle] {
        feed.puzzles(for: now()) ?? Self.puzzles(for: todayNumber, from: pool)
    }

    /// Call when the player starts today's puzzle. The clues are locked in, so a download finishing
    /// mid-game, or coming back to the app, never swaps them.
    func startToday() -> [Puzzle] {
        let number = todayNumber
        if defaults.integer(forKey: Self.lockedNumberKey) == number,
           let data = defaults.data(forKey: Self.lockedPuzzlesKey),
           let locked = try? JSONDecoder().decode([Puzzle].self, from: data), !locked.isEmpty {
            return locked
        }
        let puzzles = todayPuzzles()
        defaults.set(number, forKey: Self.lockedNumberKey)
        defaults.set(try? JSONEncoder().encode(puzzles), forKey: Self.lockedPuzzlesKey)
        return puzzles
    }

    /// Saves today's result and pays out. Returns the coins earned (0 if today was already recorded).
    @discardableResult
    func record(_ results: [ClueResult], score: Int, into wallet: Wallet) -> Int {
        guard !isPlayedToday else { return 0 }
        let number = todayNumber
        streak = lastCompleted == number - 1 ? streak + 1 : 1
        lastCompleted = number
        playedNumber = number
        self.results = results
        self.score = score
        defaults.set(number, forKey: Self.numberKey)
        defaults.set(results.map(\.rawValue), forKey: Self.resultsKey)
        defaults.set(score, forKey: Self.scoreKey)
        defaults.set(streak, forKey: Self.streakKey)
        defaults.set(lastCompleted, forKey: Self.lastCompletedKey)

        let solved = results.filter { $0 != .missed }.count
        let coins = solved * Self.coinsPerClue + (solved == results.count && solved > 0 ? Self.perfectBonus : 0)
        wallet.earn(coins)
        return coins
    }

    var maxScore: Int { max(results.count, 1) * GameSession.maxPoints }

    /// "VWLLSS Daily #12 ⭐ 13/15 🔥4" plus the colored squares.
    var shareText: String {
        var text = "VWLLSS Daily #\(playedNumber) ⭐ \(score)/\(maxScore)"
        if currentStreak > 1 { text += " 🔥\(currentStreak)" }
        return text + "\n" + results.map(\.emoji).joined()
    }

    /// Time left until the next puzzle (local midnight).
    var timeUntilNext: TimeInterval {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now())) ?? now()
        return tomorrow.timeIntervalSince(now())
    }
}
