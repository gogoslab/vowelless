import Foundation
import Observation

/// Lifetime stats, plus the leaderboards and achievements they feed.
/// Stats live on the phone; Game Center gets the totals whenever the player is signed in.
@MainActor
@Observable
final class PlayerProgress {
    enum Leaderboard: String, CaseIterable {
        case onlineWins = "club.gogoslab.vowelless.leaderboard.onlineWins"
        case totalStars = "club.gogoslab.vowelless.leaderboard.totalStars"
        case dailyStreak = "club.gogoslab.vowelless.leaderboard.dailyStreak"

        var title: String {
            switch self {
            case .onlineWins: "Online Wins"
            case .totalStars: "Total Stars"
            case .dailyStreak: "Best Daily Streak"
            }
        }
    }

    struct Achievement: Identifiable {
        let id: String
        let title: String
        let detail: String
        let points: Int
        /// 0...100.
        let progress: @MainActor (Stats) -> Double
    }

    struct Stats: Codable, Equatable {
        var cluesSolved = 0
        var cleanSolves = 0
        var hardSolved = 0
        var totalStars = 0
        var onlineRaces = 0
        var onlineWins = 0
        var flawlessRounds = 0
        var perfectDailies = 0
        var dailiesPlayed = 0
        var bestDailyStreak = 0
        var fastestRaceAnswer: Double? = nil
        var comebackWins = 0
    }

    static let achievements: [Achievement] = {
        func count(_ value: Int, of target: Int) -> Double { min(100, Double(value) / Double(target) * 100) }
        let p = "club.gogoslab.vowelless.achievement."
        return [
            Achievement(id: p + "firstClue", title: "First Letters", detail: "Solve your first clue.", points: 5) { count($0.cluesSolved, of: 1) },
            Achievement(id: p + "clues100", title: "Vowel Hunter", detail: "Solve 100 clues.", points: 20) { count($0.cluesSolved, of: 100) },
            Achievement(id: p + "clues500", title: "Consonant Connoisseur", detail: "Solve 500 clues.", points: 50) { count($0.cluesSolved, of: 500) },
            Achievement(id: p + "clean50", title: "No Help Needed", detail: "Solve 50 clues without hints or vowels.", points: 25) { count($0.cleanSolves, of: 50) },
            Achievement(id: p + "hard25", title: "Deep Cut", detail: "Solve 25 hard clues.", points: 25) { count($0.hardSolved, of: 25) },
            Achievement(id: p + "flawless", title: "Flawless", detail: "Finish a training round with every star.", points: 30) { count($0.flawlessRounds, of: 1) },
            Achievement(id: p + "firstWin", title: "First Blood", detail: "Win your first online race.", points: 10) { count($0.onlineWins, of: 1) },
            Achievement(id: p + "wins10", title: "Racer", detail: "Win 10 online races.", points: 25) { count($0.onlineWins, of: 10) },
            Achievement(id: p + "wins50", title: "Champion", detail: "Win 50 online races.", points: 50) { count($0.onlineWins, of: 50) },
            Achievement(id: p + "quickDraw", title: "Quick Draw", detail: "Win a race clue in under 5 seconds.", points: 20) { ($0.fastestRaceAnswer ?? .infinity) < 5 ? 100 : 0 },
            Achievement(id: p + "comeback", title: "Comeback Kid", detail: "Win a race after trailing by 3 points.", points: 30) { count($0.comebackWins, of: 1) },
            Achievement(id: p + "dailyFirst", title: "Daily Habit", detail: "Play your first daily puzzle.", points: 5) { count($0.dailiesPlayed, of: 1) },
            Achievement(id: p + "dailyPerfect", title: "Perfect Day", detail: "Get every star in a daily puzzle.", points: 25) { count($0.perfectDailies, of: 1) },
            Achievement(id: p + "streak7", title: "On Fire", detail: "Play the daily puzzle 7 days in a row.", points: 25) { count($0.bestDailyStreak, of: 7) },
            Achievement(id: p + "streak30", title: "Unstoppable", detail: "Play the daily puzzle 30 days in a row.", points: 50) { count($0.bestDailyStreak, of: 30) },
        ]
    }()

    private static let statsKey = "progress.stats"
    private static let reportedKey = "progress.reported"

    private(set) var stats: Stats
    private let defaults: UserDefaults
    /// Pushes leaderboard scores and achievement progress; set to Game Center in the app.
    var reporter: AchievementReporter?
    /// Achievement progress already sent, so only changes are reported.
    private var reported: [String: Double]

    init(defaults: UserDefaults = .standard, reporter: AchievementReporter? = nil) {
        self.defaults = defaults
        self.reporter = reporter
        stats = (defaults.data(forKey: Self.statsKey)).flatMap { try? JSONDecoder().decode(Stats.self, from: $0) } ?? Stats()
        reported = defaults.dictionary(forKey: Self.reportedKey) as? [String: Double] ?? [:]
    }

    func progress(of achievement: Achievement) -> Double { achievement.progress(stats) }

    // MARK: - Events

    func clueSolved(_ puzzle: Puzzle, clean: Bool, stars: Int) {
        update {
            $0.cluesSolved += 1
            if clean { $0.cleanSolves += 1 }
            if puzzle.level == .hard { $0.hardSolved += 1 }
            $0.totalStars += stars
        }
    }

    func trainingRoundFinished(score: Int, maxScore: Int) {
        guard score == maxScore, maxScore > 0 else { return }
        update { $0.flawlessRounds += 1 }
    }

    func dailyFinished(score: Int, maxScore: Int, streak: Int) {
        update {
            $0.dailiesPlayed += 1
            if score == maxScore, maxScore > 0 { $0.perfectDailies += 1 }
            $0.bestDailyStreak = max($0.bestDailyStreak, streak)
        }
    }

    /// `clueTimes` are the seconds this player took on the race clues they won.
    func raceFinished(won: Bool, clueTimes: [Double], trailedByThree: Bool) {
        update {
            $0.onlineRaces += 1
            if won { $0.onlineWins += 1 }
            if won, trailedByThree { $0.comebackWins += 1 }
            if let fastest = clueTimes.min() { $0.fastestRaceAnswer = min($0.fastestRaceAnswer ?? .infinity, fastest) }
        }
    }

    /// Sends everything again (after signing in to Game Center, or at launch).
    func resync() {
        reportAll(force: true)
    }

    // MARK: - Private

    private func update(_ change: (inout Stats) -> Void) {
        change(&stats)
        if let data = try? JSONEncoder().encode(stats) { defaults.set(data, forKey: Self.statsKey) }
        reportAll(force: false)
    }

    private func reportAll(force: Bool) {
        guard let reporter, reporter.isAvailable else { return }
        reporter.submit(scores: [
            .onlineWins: stats.onlineWins,
            .totalStars: stats.totalStars,
            .dailyStreak: stats.bestDailyStreak,
        ])
        var changed: [String: Double] = [:]
        for achievement in Self.achievements {
            let value = achievement.progress(stats)
            if force || value > (reported[achievement.id] ?? 0) { changed[achievement.id] = value }
        }
        guard !changed.isEmpty else { return }
        reporter.report(achievements: changed)
        reported.merge(changed) { max($0, $1) }
        defaults.set(reported, forKey: Self.reportedKey)
    }
}

@MainActor
protocol AchievementReporter: AnyObject {
    var isAvailable: Bool { get }
    func submit(scores: [PlayerProgress.Leaderboard: Int])
    func report(achievements: [String: Double])
}
