import Foundation
import Testing
@testable import Vowelless

@MainActor
struct DailyPuzzleTests {
    private final class Clock: @unchecked Sendable {
        var date: Date
        init() { date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 12))! }
        func advance(days: Int) { date = Calendar.current.date(byAdding: .day, value: days, to: date)! }
    }

    private func make() -> (DailyPuzzle, Wallet, Clock) {
        let defaults = UserDefaults(suiteName: "DailyPuzzleTests-\(UUID().uuidString)")!
        let clock = Clock()
        return (DailyPuzzle(defaults: defaults, now: { clock.date }), Wallet(defaults: defaults), clock)
    }

    @Test func numbersCountFromTheFirstDay() {
        let cal = Calendar.current
        #expect(DailyPuzzle.number(for: cal.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 23))!, calendar: cal) == 1)
        #expect(DailyPuzzle.number(for: cal.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 0, minute: 5))!, calendar: cal) == 2)
    }

    @Test func sameNumberSamePuzzlesOnEveryPhone() {
        let a = DailyPuzzle.puzzles(for: 42, from: PuzzleStore.builtIn)
        let b = DailyPuzzle.puzzles(for: 42, from: PuzzleStore.builtIn.shuffled())
        #expect(a == b)
        #expect(a != DailyPuzzle.puzzles(for: 43, from: PuzzleStore.builtIn))
    }

    @Test func fourEasyFromDifferentCategoriesThenOneHard() {
        for number in 1...60 {
            let p = DailyPuzzle.puzzles(for: number, from: PuzzleStore.builtIn)
            #expect(p.count == DailyPuzzle.clueCount)
            #expect(p.prefix(4).allSatisfy { $0.level == .easy })
            #expect(p.last?.level == .hard)
            #expect(Set(p.map(\.category)).count == DailyPuzzle.clueCount)
        }
    }

    @Test func oneTryPerDayAndCoins() {
        let (daily, wallet, _) = make()
        let start = wallet.coins
        #expect(!daily.isPlayedToday)
        #expect(daily.record([.clean, .clean, .helped, .clean, .clean], score: 13, into: wallet) == 5 * 10 + 25)
        #expect(wallet.coins == start + 75)
        #expect(daily.isPlayedToday)
        #expect(daily.record([.clean, .clean, .clean, .clean, .clean], score: 15, into: wallet) == 0)
        #expect(daily.score == 13)
    }

    @Test func streakGrowsAndBreaks() {
        let (daily, wallet, clock) = make()
        daily.record([.missed, .missed, .missed, .missed, .missed], score: 0, into: wallet)
        clock.advance(days: 1)
        daily.record([.clean, .missed, .missed, .missed, .missed], score: 3, into: wallet)
        #expect(daily.currentStreak == 2)
        clock.advance(days: 2)
        #expect(daily.currentStreak == 0)
        daily.record([.clean, .missed, .missed, .missed, .missed], score: 3, into: wallet)
        #expect(daily.currentStreak == 1)
    }

    @Test func shareText() {
        let (daily, wallet, clock) = make()
        daily.record([.clean, .clean, .clean, .clean, .clean], score: 15, into: wallet)
        clock.advance(days: 1)
        daily.record([.clean, .helped, .missed, .clean, .clean], score: 10, into: wallet)
        #expect(daily.shareText == "VWLLSS Daily #\(daily.todayNumber) ⭐ 10/15 🔥2\n🟩🟨🟥🟩🟩")
    }

    @Test func leavingEarlyCountsTheRestAsMissed() {
        let session = GameSession(puzzles: Array(PuzzleStore.builtIn.prefix(5)), wallet: Wallet(defaults: UserDefaults(suiteName: UUID().uuidString)!), rounds: 5, shuffles: false)
        session.submit(session.current!.answer)
        session.next()
        session.forfeitRemaining()
        #expect(session.results == [.clean, .missed, .missed, .missed, .missed])
        #expect(session.isFinished)
    }
}

struct DailyFeedTests {
    private func folder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("DailyFeedTests-\(UUID().uuidString)")
    }

    @Test func readsDayKeyedMonths() throws {
        let json = #"{"03": [{"answer": "Hey Jude", "category": "song"}, {"answer": "New Thing", "category": "movie", "level": "hard", "hints": ["a", "b"]}]}"#
        let days = try DailyFeed.decodeMonth(Data(json.utf8))
        #expect(days.keys.sorted() == [3])
        let puzzles = days[3]!.map(\.puzzle)
        #expect(puzzles[0].hints.count == 2) // filled in from the bundled puzzle
        #expect(puzzles[1].level == .hard && puzzles[1].hints == ["a", "b"])
    }

    @Test func readsFirebaseArrayShape() throws {
        // Firebase turns numeric-looking keys into an array: index 0 is null.
        let json = #"[null, [{"answer": "Hey Jude", "category": "song"}], null, [{"answer": "Imagine", "category": "song"}]]"#
        let days = try DailyFeed.decodeMonth(Data(json.utf8))
        #expect(days.keys.sorted() == [1, 3])
    }

    @Test func usesTheStoredMonthAndFallsBackWithoutIt() throws {
        let dir = folder()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let json = #"{"05": [{"answer": "Hey Jude", "category": "song"}]}"#
        try Data(json.utf8).write(to: dir.appendingPathComponent("2026-11.json"))
        let feed = DailyFeed(baseURL: nil, folder: dir)
        let cal = Calendar.current
        #expect(feed.puzzles(for: cal.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 9))!)?.map(\.answer) == ["Hey Jude"])
        #expect(feed.puzzles(for: cal.date(from: DateComponents(year: 2026, month: 11, day: 6))!) == nil)
        #expect(feed.puzzles(for: cal.date(from: DateComponents(year: 2026, month: 12, day: 5))!) == nil)
    }

    @Test @MainActor func startedPuzzleStaysLocked() throws {
        let dir = folder()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: "DailyLock-\(UUID().uuidString)")!
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 9))!
        let daily = DailyPuzzle(defaults: defaults, feed: DailyFeed(baseURL: nil, folder: dir), now: { date })
        let first = daily.startToday()
        #expect(first.count == DailyPuzzle.clueCount) // nothing published: the app's own pick
        // The month arrives after the player started: today's clues don't change.
        try Data(#"{"05": [{"answer": "Hey Jude", "category": "song"}]}"#.utf8).write(to: dir.appendingPathComponent("2026-11.json"))
        #expect(daily.startToday() == first)
        #expect(daily.todayPuzzles().map(\.answer) == ["Hey Jude"])
    }
}
