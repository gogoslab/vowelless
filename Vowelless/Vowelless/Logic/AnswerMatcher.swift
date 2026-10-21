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
        return numbersAsDigits(words).joined(separator: " ")
    }

    private static let units = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
                                "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
                                "seventeen", "eighteen", "nineteen"]
    private static let tens = ["twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
                               "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90]

    /// "twenty one pilots" -> "21 pilots", so spoken and written numbers match ("Maroon five" = "Maroon 5").
    private static func numbersAsDigits(_ words: [String]) -> [String] {
        var result: [String] = []
        var i = 0
        while i < words.count {
            let word = words[i]
            if let ten = tens[word] {
                if i + 1 < words.count, let unit = units.firstIndex(of: words[i + 1]), (1...9).contains(unit) {
                    result.append(String(ten + unit))
                    i += 2
                    continue
                }
                result.append(String(ten))
            } else if let unit = units.firstIndex(of: word) {
                result.append(String(unit))
            } else {
                result.append(word)
            }
            i += 1
        }
        return result
    }
}
