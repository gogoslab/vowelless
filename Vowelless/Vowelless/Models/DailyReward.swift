import Foundation
import Observation

/// A gift of coins once per calendar day. Coming back on consecutive days grows the gift;
/// missing a day starts the streak over.
@Observable
final class DailyReward {
    /// Coins for day 1...7 of a streak; after day 7 the week starts again.
    static let schedule = [20, 30, 40, 50, 60, 80, 150]

    private static let lastClaimKey = "dailyReward.lastClaim"
    private static let streakKey = "dailyReward.streak"

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    /// Days in a row claimed so far, including the last claim.
    private(set) var streak: Int
    private(set) var lastClaim: Date?

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        streak = defaults.integer(forKey: Self.streakKey)
        lastClaim = defaults.object(forKey: Self.lastClaimKey) as? Date
    }

    var isAvailable: Bool {
        guard let lastClaim else { return true }
        return !calendar.isDate(lastClaim, inSameDayAs: now())
    }

    /// The day of the streak today's claim would be (1-based).
    var nextDay: Int {
        guard let lastClaim, continuesStreak(from: lastClaim) else { return 1 }
        return streak + 1
    }

    /// Where `day` falls in the weekly schedule, 0-based.
    static func slot(forDay day: Int) -> Int { (day - 1) % schedule.count }

    var nextAmount: Int { Self.schedule[Self.slot(forDay: nextDay)] }

    /// Claims today's coins into `wallet`. Returns the amount, or nil if already claimed today.
    @discardableResult
    func claim(into wallet: Wallet, multiplier: Int = 1) -> Int? {
        guard isAvailable else { return nil }
        let amount = nextAmount * multiplier
        streak = nextDay
        lastClaim = now()
        defaults.set(streak, forKey: Self.streakKey)
        defaults.set(lastClaim, forKey: Self.lastClaimKey)
        wallet.earn(amount)
        return amount
    }

    /// True if claiming today continues the streak that `lastClaim` was part of (i.e. it was yesterday).
    private func continuesStreak(from lastClaim: Date) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now()) else { return false }
        return calendar.isDate(lastClaim, inSameDayAs: yesterday)
    }
}
