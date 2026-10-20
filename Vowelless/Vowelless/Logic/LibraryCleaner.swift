import Foundation

/// Raw names read from the Music library.
struct LibraryNames: Sendable {
    var songs: [String] = []
    var artists: [String] = []
}

/// Turns messy library metadata into puzzle answers.
enum LibraryCleaner {
    static let maxLength = 40
    static let maxWords = 6
    static let ignoredArtists: Set<String> = ["various artists", "unknown artist", "various", "soundtrack", "original soundtrack"]

    /// "Hey Jude - Remastered 2015" -> "Hey Jude", "Stay (feat. Justin Bieber)" -> "Stay".
    static func cleanTitle(_ raw: String) -> String? {
        var title = raw
        // Drop (…) and […] parts: (feat. X), [Live], (Radio Edit)…
        title = title.replacingOccurrences(of: #"\s*[\(\[][^\)\]]*[\)\]]"#, with: "", options: .regularExpression)
        // Drop " - Remastered 2011", " - Live at Wembley"…
        if let dash = title.range(of: " - ") { title = String(title[..<dash.lowerBound]) }
        title = stripFeaturing(title)
        // Placeholder names from ripped CDs and voice memos.
        if title.range(of: #"^(track|audio track|untitled|new recording)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return nil
        }
        return acceptable(title)
    }

    /// "Calvin Harris feat. Rihanna" -> "Calvin Harris".
    static func cleanArtist(_ raw: String) -> String? {
        let artist = stripFeaturing(raw)
        guard !ignoredArtists.contains(artist.lowercased()) else { return nil }
        return acceptable(artist)
    }

    static func puzzles(from names: LibraryNames) -> [Puzzle] {
        var seen: Set<String> = []
        var puzzles: [Puzzle] = []
        func add(_ answer: String, _ category: Category) {
            let key = "\(category.rawValue):\(AnswerMatcher.normalize(answer))"
            guard seen.insert(key).inserted else { return }
            puzzles.append(Puzzle(answer: answer, category: category))
        }

        for song in names.songs.compactMap(cleanTitle) { add(song, .song) }
        for artist in names.artists.compactMap(cleanArtist) {
            add(artist, .artist)
        }
        return puzzles
    }

    private static func stripFeaturing(_ text: String) -> String {
        let cut = text.range(of: #"\s+(feat\.?|ft\.?|featuring)\s+.*$"#, options: [.regularExpression, .caseInsensitive])
        let stripped = cut.map { String(text[..<$0.lowerBound]) } ?? text
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Rejects names that would make bad puzzles: empty, too long, or with no vowels to hide.
    private static func acceptable(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxLength,
              trimmed.split(separator: " ").count <= maxWords
        else { return nil }
        let clue = Disemvoweler.clue(for: trimmed)
        let full = Disemvoweler.letters(of: trimmed).map { String($0) }.joined(separator: " ")
        guard !clue.isEmpty, clue != full else { return nil }
        return trimmed
    }
}
