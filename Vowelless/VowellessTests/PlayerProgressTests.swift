import Foundation
import Testing
@testable import Vowelless

@MainActor
struct PlayerProgressTests {
    final class FakeReporter: AchievementReporter {
        var isAvailable = true
        var scores: [PlayerProgress.Leaderboard: Int] = [:]
        var achievements: [String: Double] = [:]
        var reportCalls = 0
        func submit(scores: [PlayerProgress.Leaderboard: Int]) { self.scores = scores }
        func report(achievements: [String: Double]) {
            reportCalls += 1
            self.achievements.merge(achievements) { $1 }
        }
    }

    private func make() -> (PlayerProgress, FakeReporter) {
        let reporter = FakeReporter()
        return (PlayerProgress(defaults: UserDefaults(suiteName: "Progress-\(UUID().uuidString)")!, reporter: reporter), reporter)
    }

    private let p = "club.gogoslab.vowelless.achievement."

    @Test func solvingCluesFeedsStatsLeaderboardsAndAchievements() {
        let (progress, reporter) = make()
        let hard = Puzzle(answer: "Ulysses", category: .book, level: .hard)
        progress.clueSolved(hard, clean: true, stars: 3)
        #expect(progress.stats.cluesSolved == 1 && progress.stats.hardSolved == 1 && progress.stats.totalStars == 3)
        #expect(reporter.scores[.totalStars] == 3)
        #expect(reporter.achievements[p + "firstClue"] == 100)
        #expect(reporter.achievements[p + "hard25"] == 4)
    }

    @Test func onlyChangedAchievementsAreReported() {
        let (progress, reporter) = make()
        let easy = Puzzle(answer: "Hey Jude", category: .song)
        progress.clueSolved(easy, clean: true, stars: 3)
        let before = reporter.achievements.count
        reporter.achievements = [:]
        progress.trainingRoundFinished(score: 10, maxScore: 30) // not flawless: nothing new
        #expect(reporter.achievements.isEmpty)
        #expect(before > 0)
    }

    @Test func raceAchievements() {
        let (progress, reporter) = make()
        progress.raceFinished(won: true, clueTimes: [12, 4.2], trailedByThree: true)
        #expect(progress.stats.onlineWins == 1)
        #expect(reporter.scores[.onlineWins] == 1)
        #expect(reporter.achievements[p + "firstWin"] == 100)
        #expect(reporter.achievements[p + "quickDraw"] == 100)
        #expect(reporter.achievements[p + "comeback"] == 100)
        progress.raceFinished(won: false, clueTimes: [], trailedByThree: true)
        #expect(progress.stats.comebackWins == 1 && progress.stats.onlineRaces == 2)
    }

    @Test func dailyStreakIsTheBestSoFar() {
        let (progress, reporter) = make()
        progress.dailyFinished(score: 15, maxScore: 15, streak: 7)
        progress.dailyFinished(score: 3, maxScore: 15, streak: 1)
        #expect(progress.stats.bestDailyStreak == 7)
        #expect(reporter.scores[.dailyStreak] == 7)
        #expect(reporter.achievements[p + "streak7"] == 100)
        #expect(reporter.achievements[p + "dailyPerfect"] == 100)
    }

    @Test func progressMadeWhileSignedOutIsSentLater() {
        let (progress, reporter) = make()
        reporter.isAvailable = false
        progress.raceFinished(won: true, clueTimes: [], trailedByThree: false)
        #expect(reporter.scores.isEmpty)
        reporter.isAvailable = true
        progress.resync()
        #expect(reporter.scores[.onlineWins] == 1)
        #expect(reporter.achievements[p + "firstWin"] == 100)
    }

    @Test func achievementIDsAreUnique() {
        let ids = PlayerProgress.achievements.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
