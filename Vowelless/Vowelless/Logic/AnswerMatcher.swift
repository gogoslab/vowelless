import Foundation

enum AnswerMatcher {
    static func matches(_ guess: String, _ answer: String) -> Bool {
        // Spaces are ignored so "Spiderman" matches "Spider-Man".
        let g = normalize(guess).replacingOccurrences(of: " ", with: "")
        return !g.isEmpty && g == normalize(answer).replacingOccurrences(of: " ", with: "")
    }

    /// Lowercases, strips accents and punctuation, and drops a leading "the".
    static func normalize(_ text: String) -> String {
        var words = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0 == "n" ? "and" : $0 } // "Guns N' Roses"
        if words.first == "the" { words.removeFirst() }
        // Club prefixes/suffixes are optional: "Barcelona" matches "FC Barcelona".
        words.removeAll { ["fc", "cf", "afc"].contains($0) }
        return words.joined(separator: " ")
    }
}
