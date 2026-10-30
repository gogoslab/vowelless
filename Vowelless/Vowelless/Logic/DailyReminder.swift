import Foundation
import UserNotifications

/// A notification at the player's chosen time on each of the next few days, skipping today once
/// the daily puzzle is played. Rescheduled whenever the app opens, so it never nags someone who stopped playing.
enum DailyReminder {
    static let enabledKey = "reminder.enabled"
    /// Minutes after midnight.
    static let minutesKey = "reminder.minutes"
    static let defaultMinutes = 18 * 60
    static let daysAhead = 7
    private static let idPrefix = "daily-reminder-"

    struct Planned: Equatable {
        let id: String
        let date: Date
        let title: String
        let body: String
    }

    private static let bodies = [
        "5 new clues are waiting. Can you guess them without the vowels?",
        "Today's 5 clues are ready. No vowels, no problem!",
        "A fresh set of vowelless clues just dropped. Ready?",
    ]

    /// The reminders to schedule from `now`. A streak is mentioned on the next reminder that could save it.
    static func plan(now: Date, calendar: Calendar, minutes: Int, todayNumber: Int,
                     playedToday: Bool, streak: Int) -> [Planned] {
        let today = calendar.startOfDay(for: now)
        var planned: [Planned] = []
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let date = calendar.date(byAdding: .minute, value: minutes, to: day) else { continue }
            if offset == 0 && (playedToday || date <= now) { continue }
            let number = todayNumber + offset
            // Unplayed today: today's streak is at stake. Played today: tomorrow's is.
            let streakAtStake = streak > 0 && offset == (playedToday ? 1 : 0)
            let body = streakAtStake
                ? "Keep your \(streak)-day streak going 🔥 5 new clues are waiting."
                : bodies[number % bodies.count]
            planned.append(Planned(id: idPrefix + String(number), date: date, title: "Daily #\(number) is ready", body: body))
        }
        return planned
    }

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static var minutes: Int {
        UserDefaults.standard.object(forKey: minutesKey) as? Int ?? defaultMinutes
    }

    /// Asks for permission if needed. Returns whether reminders can be shown.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    static var isDenied: Bool {
        get async { await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied }
    }

    /// Replaces the pending reminders to match the settings and today's puzzle.
    @MainActor
    static func reschedule(for daily: DailyPuzzle, now: Date = Date(), calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard isEnabled else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let planned = plan(now: now, calendar: calendar, minutes: minutes, todayNumber: daily.todayNumber,
                           playedToday: daily.isPlayedToday, streak: daily.currentStreak)
        for reminder in planned {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}
