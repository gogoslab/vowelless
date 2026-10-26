import Foundation
import Testing
@testable import Vowelless

struct DailyRewardTests {
    private final class Clock: @unchecked Sendable {
        var date = Date(timeIntervalSince1970: 1_800_000_000)
        func advance(days: Int) { date = Calendar.current.date(byAdding: .day, value: days, to: date)! }
    }

    private func make() -> (DailyReward, Wallet, Clock) {
        let defaults = UserDefaults(suiteName: "DailyRewardTests-\(UUID().uuidString)")!
        let clock = Clock()
        return (DailyReward(defaults: defaults, now: { clock.date }), Wallet(defaults: defaults), clock)
    }

    @Test func firstClaimGivesDayOneAndOnlyOncePerDay() {
        let (reward, wallet, clock) = make()
        let start = wallet.coins
        #expect(reward.isAvailable)
        #expect(reward.claim(into: wallet) == 20)
        #expect(wallet.coins == start + 20)
        #expect(!reward.isAvailable)
        #expect(reward.claim(into: wallet) == nil)
        clock.advance(days: 0)
        #expect(wallet.coins == start + 20)
    }

    @Test func consecutiveDaysFollowTheScheduleAndWrapAfterAWeek() {
        let (reward, wallet, clock) = make()
        var got: [Int] = []
        for _ in 0..<8 {
            got.append(reward.claim(into: wallet) ?? -1)
            clock.advance(days: 1)
        }
        #expect(got == DailyReward.schedule + [20])
    }

    @Test func missingADayRestartsTheStreak() {
        let (reward, wallet, clock) = make()
        reward.claim(into: wallet); clock.advance(days: 1)
        reward.claim(into: wallet); clock.advance(days: 2)
        #expect(reward.nextDay == 1)
        #expect(reward.claim(into: wallet) == 20)
    }

    @Test func doublingFromAnAd() {
        let (reward, wallet, _) = make()
        #expect(reward.claim(into: wallet, multiplier: 2) == 40)
    }
}
