import Foundation

/// A race in progress, as shown by RaceView: either an online match or a bot game.
struct ActiveRace: Identifiable {
    let id = UUID()
    let engine: RaceEngine
    /// Coins for winning, tying and losing.
    let rewards: (won: Int, tied: Int, lost: Int)
    let leave: () -> Void

    @MainActor
    static func online(_ race: OnlineRace) -> ActiveRace {
        ActiveRace(
            engine: race.engine,
            rewards: (Economy.raceWinReward, Economy.raceTieReward, Economy.raceLossReward),
            leave: race.leave
        )
    }

    @MainActor
    static func bot(_ race: BotRace) -> ActiveRace {
        // Bots stand in for missing players, so they pay the same as a person.
        ActiveRace(
            engine: race.engine,
            rewards: (Economy.raceWinReward, Economy.raceTieReward, Economy.raceLossReward),
            leave: race.leave
        )
    }
}
