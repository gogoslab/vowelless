import Foundation
import Observation

@Observable
final class GameSession {
    private let pool: [Puzzle]
    private let rounds: Int
    private(set) var puzzles: [Puzzle] = []
    private(set) var index = 0
    private(set) var score = 0
    private(set) var revealed = false
    private(set) var lastGuessCorrect: Bool?
    private(set) var wrongAttempts = 0

    init(puzzles: [Puzzle], rounds: Int = 10) {
        self.pool = puzzles
        self.rounds = rounds
        restart()
    }

    var current: Puzzle? { puzzles.indices.contains(index) ? puzzles[index] : nil }
    var isFinished: Bool { current == nil }
    var progress: Double { puzzles.isEmpty ? 0 : Double(index) / Double(puzzles.count) }
    var progressLabel: String { "\(min(index + 1, puzzles.count)) / \(puzzles.count)" }

    func submit(_ guess: String) {
        guard let current, !revealed else { return }
        if AnswerMatcher.matches(guess, current.answer) {
            score += 1
            lastGuessCorrect = true
            revealed = true
        } else {
            lastGuessCorrect = false
            wrongAttempts += 1
        }
    }

    func giveUp() {
        revealed = true
        lastGuessCorrect = false
    }

    func next() {
        index += 1
        revealed = false
        lastGuessCorrect = nil
    }

    func restart() {
        puzzles = Array(pool.shuffled().prefix(rounds))
        index = 0
        score = 0
        revealed = false
        lastGuessCorrect = nil
    }
}
