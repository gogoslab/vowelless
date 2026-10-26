import Foundation
import Testing
@testable import Vowelless

/// Two engines wired together in memory, as if on two phones.
@MainActor
struct RaceEngineTests {
    private static let fast = RaceEngine.Timing(countdown: .milliseconds(20), roundLength: .milliseconds(300), betweenRounds: .milliseconds(20))

    private func makePair(timing: RaceEngine.Timing = fast) -> (host: RaceEngine, guest: RaceEngine) {
        let ids = ["A-host", "B-guest"]
        let names = ["A-host": "Ana", "B-guest": "Bob"]
        let host = RaceEngine(localPlayerID: "A-host", playerIDs: ids, playerNames: names, timing: timing)
        let guest = RaceEngine(localPlayerID: "B-guest", playerIDs: ids, playerNames: names, timing: timing)
        // Deliver asynchronously, like a network would.
        host.send = { message in Task { @MainActor in guest.receive(message, from: "A-host") } }
        guest.send = { message in Task { @MainActor in host.receive(message, from: "B-guest") } }
        return (host, guest)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<300 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    private var pool: [Puzzle] { Array(PuzzleStore.builtIn.prefix(40)) }

    @Test func lowestIDHosts() {
        let (host, guest) = makePair()
        #expect(host.isHost)
        #expect(!guest.isHost)
    }

    @Test func bothPhonesGetTheSameClues() async throws {
        let (host, guest) = makePair()
        host.begin(pool: pool, difficulty: .hard)
        try await waitUntil { guest.phase == .playing(index: 0) }
        #expect(guest.puzzles == host.puzzles)
        #expect(guest.puzzles.count == RaceEngine.rounds)
        #expect(guest.difficulty == .hard)
        #expect(guest.currentPuzzle == host.currentPuzzle)
    }

    @Test func guestWinsARoundAndBothAgree() async throws {
        let (host, guest) = makePair()
        host.begin(pool: pool, difficulty: .easy)
        try await waitUntil { guest.phase == .playing(index: 0) }

        guest.submitCorrect()

        try await waitUntil { guest.phase == .roundOver(index: 0, winner: "B-guest") }
        #expect(host.phase == .roundOver(index: 0, winner: "B-guest"))
        #expect(host.scores["B-guest"] == 1)
        #expect(guest.scores["B-guest"] == 1)
    }

    @Test func onlyTheFirstCorrectAnswerScores() async throws {
        let (host, guest) = makePair()
        host.begin(pool: pool, difficulty: .easy)
        try await waitUntil { guest.phase == .playing(index: 0) }

        host.submitCorrect()   // the host's answer is ruled on immediately
        guest.submitCorrect()  // arrives after the round closed

        try await waitUntil { guest.phase == .roundOver(index: 0, winner: "A-host") }
        try await Task.sleep(for: .milliseconds(10))
        #expect(host.scores == ["A-host": 1, "B-guest": 0])
        #expect(guest.scores == ["A-host": 1, "B-guest": 0])
    }

    @Test func unsolvedClueTimesOut() async throws {
        let (host, guest) = makePair()
        host.begin(pool: pool, difficulty: .easy)
        try await waitUntil { guest.phase == .roundOver(index: 0, winner: nil) }
        #expect(host.scores.values.allSatisfy { $0 == 0 })
    }

    @Test func fullMatchFinishesWithAWinner() async throws {
        let (host, guest) = makePair()
        host.begin(pool: pool, difficulty: .easy)
        for round in 0..<RaceEngine.rounds {
            try await waitUntil { guest.phase == .playing(index: round) }
            if round < 6 { guest.submitCorrect() } else { host.submitCorrect() }
            try await waitUntil { if case .roundOver(round, _) = guest.phase { true } else { guest.phase == .finished } }
        }
        try await waitUntil { guest.phase == .finished && host.phase == .finished }
        #expect(guest.scores == ["A-host": 4, "B-guest": 6])
        #expect(guest.outcome == .won)
        #expect(host.outcome == .lost)
    }

    @Test func messagesFromNonHostAreIgnored() {
        let (_, guest) = makePair()
        guest.receive(.finished, from: "someone-else")
        #expect(guest.phase == .waitingForSetup)
    }

    @Test func opponentLeavingMeansYouWin() {
        let (host, _) = makePair()
        host.begin(pool: pool, difficulty: .easy)
        host.playerLeft("B-guest")
        #expect(host.phase == .opponentLeft)
        #expect(host.outcome == .won)
    }

    @Test func messagesRoundTripThroughJSON() throws {
        let messages: [RaceMessage] = [
            .setup(puzzles: [PuzzleRef(Puzzle(answer: "Hey Jude", category: .song))], difficulty: "medium"),
            .startRound(index: 3), .claim(index: 3), .roundResult(index: 3, winner: nil), .finished,
        ]
        for message in messages {
            let data = try JSONEncoder().encode(message)
            #expect(try JSONDecoder().decode(RaceMessage.self, from: data) == message)
        }
    }
}

/// Bot games run the same engine on one phone.
@MainActor
struct BotRaceTests {
    private static let fast = RaceEngine.Timing(countdown: .milliseconds(10), roundLength: .milliseconds(200), betweenRounds: .milliseconds(10))
    private var pool: [Puzzle] { Array(PuzzleStore.builtIn.prefix(40)) }

    private func play(_ bot: BotRace, local: (RaceEngine, Int) -> Void = { _, _ in }) async throws {
        var lastStarted = -1
        for _ in 0..<1000 where bot.engine.phase != .finished {
            if case .playing(let index) = bot.engine.phase, index != lastStarted {
                lastStarted = index
                local(bot.engine, index)
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(bot.engine.phase == .finished)
    }

    @Test func perfectBotWinsEveryClue() async throws {
        let bot = BotRace(level: .hard, pool: pool, difficulty: .easy,
                          behavior: .init(solveChance: 1, delay: 0.01...0.02), timing: Self.fast)
        try await play(bot)
        #expect(bot.engine.scores[BotRace.botID] == RaceEngine.rounds)
        #expect(bot.engine.outcome == .lost)
    }

    @Test func hopelessBotNeverScores() async throws {
        let bot = BotRace(level: .easy, pool: pool, difficulty: .easy,
                          behavior: .init(solveChance: 0, delay: 0.01...0.02), timing: Self.fast)
        try await play(bot) { engine, _ in engine.submitCorrect() }
        #expect(bot.engine.scores[BotRace.botID] == 0)
        #expect(bot.engine.scores[BotRace.localID] == RaceEngine.rounds)
        #expect(bot.engine.outcome == .won)
    }

    @Test func catchUpFactorFollowsTheScoreGap() {
        #expect(BotRace.catchUpFactor(playerLead: 0) == 1)
        #expect(abs(BotRace.catchUpFactor(playerLead: 2) - 0.8) < 1e-9)   // player leads by 2
        #expect(abs(BotRace.catchUpFactor(playerLead: -3) - 1.3) < 1e-9)  // bot leads by 3
        #expect(abs(BotRace.catchUpFactor(playerLead: 10) - 0.2) < 1e-9)  // capped at 8
        #expect(abs(BotRace.catchUpFactor(playerLead: -10) - 1.8) < 1e-9)
    }

    @Test func playerWhoAnswersFirstBeatsTheBot() async throws {
        // The bot always solves, but slower than the player.
        let bot = BotRace(level: .medium, pool: pool, difficulty: .easy,
                          behavior: .init(solveChance: 1, delay: 0.1...0.12), timing: Self.fast)
        try await play(bot) { engine, _ in engine.submitCorrect() }
        #expect(bot.engine.scores[BotRace.localID] == RaceEngine.rounds)
    }

}

@MainActor
struct RaceCategoryTests {
    @Test func everyChoiceHasItsOwnPlayerGroup() {
        let groups = [RaceCategory.playerGroup(for: nil)] + Category.allCases.map { RaceCategory.playerGroup(for: $0) }
        #expect(Set(groups).count == groups.count)
        #expect(!groups.contains(0)) // 0 means "anyone" to Game Center
    }

    @Test func inviteGroupGivesBackTheCategory() {
        for category in Category.allCases {
            #expect(RaceCategory.category(forPlayerGroup: RaceCategory.playerGroup(for: category)) == category)
        }
        #expect(RaceCategory.category(forPlayerGroup: RaceCategory.mixedGroup) == nil)
    }

    @Test func categoryPoolsOnlyHoldThatCategory() {
        #expect(RaceCategory.pool(for: .movie).allSatisfy { $0.category == .movie })
        #expect(RaceCategory.pool(for: .movie).count >= RaceEngine.rounds)
    }
}

struct PuzzleLevelTests {
    @Test func aboutThirtyPercentOfEachCategoryIsHard() {
        for category in Category.allCases {
            let puzzles = PuzzleStore.builtIn.filter { $0.category == category }
            let share = Double(puzzles.filter { $0.level == .hard }.count) / Double(puzzles.count)
            #expect((0.27...0.33).contains(share), "\(category): \(share)")
        }
    }

    @Test func mixedHasOnlyEasyAnswers() {
        #expect(!PuzzleStore.builtIn.mixed.isEmpty)
        #expect(PuzzleStore.builtIn.mixed.allSatisfy { $0.level == .easy })
        #expect(RaceCategory.pool(for: nil).allSatisfy { $0.level == .easy })
    }

    @Test func categoriesKeepTheirHardAnswers() {
        #expect(RaceCategory.pool(for: .book).contains { $0.level == .hard })
    }
}
