import Foundation
import Testing
@testable import Vowelless

struct DailyReminderTests {
    private let cal = Calendar.current

    private func at(hour: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: hour))!
    }

    @Test func remindsTodayWhenNotPlayedAndStillAhead() {
        let plan = DailyReminder.plan(now: at(hour: 9), calendar: cal, minutes: 18 * 60, todayNumber: 11, playedToday: false, streak: 0)
        #expect(plan.count == DailyReminder.daysAhead)
        #expect(plan[0].date == at(hour: 18))
        #expect(plan[0].title == "Daily #11 is ready")
        #expect(plan.last?.title == "Daily #17 is ready")
    }

    @Test func skipsTodayOncePlayedOrPast() {
        let played = DailyReminder.plan(now: at(hour: 9), calendar: cal, minutes: 18 * 60, todayNumber: 11, playedToday: true, streak: 0)
        let late = DailyReminder.plan(now: at(hour: 20), calendar: cal, minutes: 18 * 60, todayNumber: 11, playedToday: false, streak: 0)
        for plan in [played, late] {
            #expect(plan.count == DailyReminder.daysAhead - 1)
            #expect(plan[0].title == "Daily #12 is ready")
        }
    }

    @Test func mentionsTheStreakOnlyWhereItCanBeSaved() {
        let unplayed = DailyReminder.plan(now: at(hour: 9), calendar: cal, minutes: 18 * 60, todayNumber: 11, playedToday: false, streak: 4)
        #expect(unplayed[0].body.contains("4-day streak"))
        #expect(!unplayed[1].body.contains("streak"))

        let played = DailyReminder.plan(now: at(hour: 9), calendar: cal, minutes: 18 * 60, todayNumber: 11, playedToday: true, streak: 5)
        #expect(played[0].body.contains("5-day streak"))
        #expect(!played[1].body.contains("streak"))

        // Missed today's reminder time without playing: tomorrow the streak is already gone.
        let late = DailyReminder.plan(now: at(hour: 20), calendar: cal, minutes: 18 * 60, todayNumber: 11, playedToday: false, streak: 4)
        #expect(late.allSatisfy { !$0.body.contains("streak") })
    }
}
