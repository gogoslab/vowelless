import Foundation
import Observation

/// Prices and rewards, in coins.
enum Economy {
    static let startingCoins = 100
    /// Cost of each hint, in order: the cryptic one, then the clear one.
    static let hintCosts = [10, 30]
    static let vowelCost = 20
    static let correctReward = 10
    /// Extra coins for solving a clue without any helpers.
    static let noHelpBonus = 10
    /// Coins for finishing an online race.
    static let raceWinReward = 50
    static let raceTieReward = 25
    static let raceLossReward = 10
}

/// The player's coins, saved between launches.
@Observable
final class Wallet {
    static let storageKey = "coins"

    private let defaults: UserDefaults
    private(set) var coins: Int {
        didSet { defaults.set(coins, forKey: Self.storageKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        coins = defaults.object(forKey: Self.storageKey) as? Int ?? Economy.startingCoins
    }

    func canAfford(_ cost: Int) -> Bool { coins >= cost }

    /// Takes `cost` coins if the player has them; returns whether it did.
    @discardableResult
    func spend(_ cost: Int) -> Bool {
        guard canAfford(cost) else { return false }
        coins -= cost
        return true
    }

    func earn(_ amount: Int) {
        coins += amount
    }
}
