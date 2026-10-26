import GameKit

/// Sends leaderboard scores and achievement progress to Game Center.
@MainActor
final class GameCenterReporter: AchievementReporter {
    var isAvailable: Bool { GKLocalPlayer.local.isAuthenticated }

    func submit(scores: [PlayerProgress.Leaderboard: Int]) {
        for (leaderboard, value) in scores where value > 0 {
            // Game Center keeps each player's best, so sending the same total again is harmless.
            GKLeaderboard.submitScore(value, context: 0, player: GKLocalPlayer.local,
                                      leaderboardIDs: [leaderboard.rawValue]) { @Sendable _ in }
        }
    }

    func report(achievements: [String: Double]) {
        let list = achievements.map { id, percent -> GKAchievement in
            let achievement = GKAchievement(identifier: id)
            achievement.percentComplete = percent
            achievement.showsCompletionBanner = true
            return achievement
        }
        GKAchievement.report(list) { @Sendable _ in }
    }
}
