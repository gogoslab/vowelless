import Foundation
import Observation

@Observable
final class GameSession {
    private let pool: [Puzzle]
    private let rounds: Int
    private let shuffles: Bool
    let wallet: Wallet
    private(set) var puzzles: [Puzzle] = []
    private(set) var index = 0
    private(set) var score = 0
    private(set) var revealed = false
    private(set) var lastGuessCorrect: Bool?
    private(set) var wrongAttempts = 0
    private(set) var hintsShown = 0
    private(set) var revealedVowels: Set<Character> = []
    /// The last vowel the player picked that isn't in the answer, for a quick "no luck" message.
    private(set) var missedVowel: Character?
    private(set) var correctCount = 0
    /// Coins won on the last correct answer, for the "Nailed it!" message.
    private(set) var lastReward = 0
    private(set) var coinsEarned = 0
    /// Set when the player tried a helper they can't afford: the price they were short for.
    private(set) var cantAfford: Int?
    /// Called after each correct answer with the puzzle, whether it was solved without help, and the stars won.
    var onClueSolved: ((Puzzle, Bool, Int) -> Void)?
    /// How each finished clue went, in order.
    private(set) var results: [ClueResult] = []

    /// Points for a correct answer: 3 with no help, minus one per hint or vowel, never below 1.
    static let maxPoints = 3

    /// `shuffles: false` plays `puzzles` in the given order (the daily puzzle).
    init(puzzles: [Puzzle], wallet: Wallet, rounds: Int = 10, shuffles: Bool = true) {
        self.pool = puzzles
        self.wallet = wallet
        self.rounds = rounds
        self.shuffles = shuffles
        restart()
    }

    var current: Puzzle? { puzzles.indices.contains(index) ? puzzles[index] : nil }
    var isFinished: Bool { current == nil }
    var progress: Double { puzzles.isEmpty ? 0 : Double(index) / Double(puzzles.count) }
    var progressLabel: String { "\(min(index + 1, puzzles.count)) / \(puzzles.count)" }
    var maxScore: Int { puzzles.count * Self.maxPoints }
    var pointsAvailable: Int { max(1, Self.maxPoints - hintsShown - revealedVowels.count) }
    var hintsRemaining: Int { max(0, (current?.hints.count ?? 0) - hintsShown) }
    var canShowHint: Bool { !revealed && hintsRemaining > 0 }
    var nextHintCost: Int { Economy.hintCosts[min(hintsShown, Economy.hintCosts.count - 1)] }
    var usedHelpers: Bool { hintsShown > 0 || !revealedVowels.isEmpty }

    func showHint() {
        guard canShowHint else { return }
        guard wallet.spend(nextHintCost) else {
            cantAfford = nextHintCost
            return
        }
        hintsShown += 1
        missedVowel = nil
        cantAfford = nil
    }

    func canReveal(_ vowel: Character) -> Bool {
        !revealed && !revealedVowels.contains(vowel)
    }

    /// Reveals every copy of `vowel` in the answer. It costs coins and a point even when the vowel isn't there.
    func reveal(_ vowel: Character) {
        guard let current, canReveal(vowel) else { return }
        guard wallet.spend(Economy.vowelCost) else {
            cantAfford = Economy.vowelCost
            return
        }
        cantAfford = nil
        revealedVowels.insert(vowel)
        let inAnswer = Disemvoweler.letters(of: current.answer).joined().contains(vowel)
        missedVowel = inAnswer ? nil : vowel
        lastGuessCorrect = nil
    }

    func submit(_ guess: String) {
        guard let current, !revealed else { return }
        if AnswerMatcher.matches(guess, current.answer) {
            score += pointsAvailable
            correctCount += 1
            results.append(usedHelpers ? .helped : .clean)
            onClueSolved?(current, !usedHelpers, pointsAvailable)
            lastReward = Economy.correctReward + (usedHelpers ? 0 : Economy.noHelpBonus)
            coinsEarned += lastReward
            wallet.earn(lastReward)
            cantAfford = nil
            lastGuessCorrect = true
            revealed = true
        } else {
            lastGuessCorrect = false
            missedVowel = nil
            cantAfford = nil
            wrongAttempts += 1
        }
    }

    func giveUp() {
        guard !revealed else { return }
        cantAfford = nil
        results.append(.missed)
        revealed = true
        lastGuessCorrect = false
    }

    /// Leaving early: every clue not yet finished counts as missed.
    func forfeitRemaining() {
        while results.count < puzzles.count { results.append(.missed) }
        index = puzzles.count
        revealed = false
    }

    func next() {
        index += 1
        revealed = false
        lastGuessCorrect = nil
        hintsShown = 0
        revealedVowels = []
        missedVowel = nil
        cantAfford = nil
    }

    func restart() {
        puzzles = Array((shuffles ? pool.shuffled() : pool).prefix(rounds))
        results = []
        index = 0
        score = 0
        correctCount = 0
        coinsEarned = 0
        cantAfford = nil
        hintsShown = 0
        revealedVowels = []
        missedVowel = nil
        revealed = false
        lastGuessCorrect = nil
    }
}
