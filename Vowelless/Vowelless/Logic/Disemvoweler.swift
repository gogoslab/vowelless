import Foundation

/// One letter of an answer. `id` is its position in the whole answer, so a tile keeps its identity
/// whether it's shown in the clue or in the revealed answer.
struct ClueTile: Identifiable, Hashable {
    let id: Int
    let letter: Character
    let wordIndex: Int
    var isVowel: Bool { Disemvoweler.vowels.contains(letter) }
}

enum Disemvoweler {
    /// Y is treated as a consonant.
    static let vowels: Set<Character> = ["A", "E", "I", "O", "U"]

    /// Symbols that are shown as tiles; other punctuation (apostrophes, periods, commas…) is dropped.
    static let keptSymbols: Set<Character> = ["&", "-", "/"]

    /// Uppercased, accent-free letters of each word: "Beyoncé" -> [["B","E","Y","O","N","C","E"]].
    static func letters(of answer: String) -> [[Character]] {
        answer
            .folding(options: .diacriticInsensitive, locale: nil)
            .uppercased()
            .split(separator: " ")
            .map { word in word.filter { $0.isLetter || $0.isNumber || keptSymbols.contains($0) } }
            .filter { !$0.isEmpty }
            .map(Array.init)
    }

    /// Every letter of the answer, vowels included.
    static func tiles(of answer: String) -> [ClueTile] {
        var tiles: [ClueTile] = []
        for (w, word) in letters(of: answer).enumerated() {
            for letter in word {
                tiles.append(ClueTile(id: tiles.count, letter: letter, wordIndex: w))
            }
        }
        return tiles
    }

    /// The tiles the player sees, grouped into "words": every consonant, plus any vowels in `revealedVowels`.
    static func clueGroups(for answer: String, difficulty: Difficulty, revealedVowels: Set<Character> = []) -> [[ClueTile]] {
        let shown = tiles(of: answer).filter { !$0.isVowel || revealedVowels.contains($0.letter) }
        guard !shown.isEmpty else { return [] }

        switch difficulty {
        case .easy:
            return Dictionary(grouping: shown, by: \.wordIndex)
                .sorted { $0.key < $1.key }
                .map(\.value)
        case .medium:
            return [shown]
        case .hard:
            // Split the consonants first so buying a vowel never reshuffles the made-up spaces.
            var groups = randomConsonantGroups(for: answer)
            for vowel in shown where vowel.isVowel {
                insert(vowel, into: &groups)
            }
            return groups
        }
    }

    /// Puts a vowel into the group of the consonant just before it (or the first group if none).
    private static func insert(_ vowel: ClueTile, into groups: inout [[ClueTile]]) {
        guard !groups.isEmpty else {
            groups = [[vowel]]
            return
        }
        let target = groups.lastIndex { group in group.contains { $0.id < vowel.id } } ?? 0
        let position = groups[target].firstIndex { $0.id > vowel.id } ?? groups[target].endIndex
        groups[target].insert(vowel, at: position)
    }

    private static func randomConsonantGroups(for answer: String) -> [[ClueTile]] {
        let consonants = tiles(of: answer).filter { !$0.isVowel }
        guard !consonants.isEmpty else { return [] }
        let real = clueGroups(for: answer, difficulty: .easy)
        var rng = SeededGenerator(seed: stableHash(answer))
        // Retry a few times so the random split doesn't happen to match the real one.
        for _ in 0..<5 {
            let groups = randomSplit(consonants, using: &rng)
            if groups != real || consonants.count < 3 { return groups }
        }
        return randomSplit(consonants, using: &rng)
    }

    /// "Bohemian Rhapsody" -> "BHMN RHPSD" (easy), "BHMNRHPSD" (medium), "BH MNR HPSD" (hard).
    static func clue(for answer: String, difficulty: Difficulty = .easy) -> String {
        clueGroups(for: answer, difficulty: difficulty)
            .map { String($0.map(\.letter)) }
            .joined(separator: " ")
    }

    private static func randomSplit(_ tiles: [ClueTile], using rng: inout SeededGenerator) -> [[ClueTile]] {
        var groups: [[ClueTile]] = []
        var start = 0
        while start < tiles.count {
            let length = min(Int.random(in: 1...4, using: &rng), tiles.count - start)
            groups.append(Array(tiles[start..<start + length]))
            start += length
        }
        return groups
    }

    /// FNV-1a, so the same answer always gets the same "random" split (Swift's hashValue changes per launch).
    private static func stableHash(_ text: String) -> UInt64 {
        text.utf8.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
}

/// SplitMix64.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
