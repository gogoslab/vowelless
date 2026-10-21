import Foundation

/// One song as read from the Music library, before cleaning.
struct LibrarySong: Sendable {
    var title: String
    var artist: String?
    var album: String?
    var genre: String?
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

    static func puzzles(from songs: [LibrarySong]) -> [Puzzle] {
        var seen: Set<String> = []
        var puzzles: [Puzzle] = []
        func add(_ puzzle: Puzzle) {
            let key = "\(puzzle.category.rawValue):\(AnswerMatcher.normalize(puzzle.answer))"
            guard seen.insert(key).inserted else { return }
            puzzles.append(puzzle)
        }

        // Songs: the album is the cryptic hint, the artist the clear one.
        for song in songs {
            guard let title = cleanTitle(song.title) else { continue }
            let artist = song.artist.flatMap(cleanArtist)
            let album = song.album.flatMap(cleanTitle)
            // Fall back to the genre when the album is missing or named after the song itself.
            let albumHint = album.map { "From the album “\($0)”" }
            let genreHint = song.genre.map { "A \($0) track in your library" }
            let cryptic = safeHints([albumHint, genreHint], for: title).first
            add(Puzzle(answer: title, category: .song, hints: safeHints([cryptic, artist.map { "By \($0)" }], for: title)))
        }

        // Artists: the genre and song count are the cryptic hint, one of their songs the clear one.
        let byArtist = Dictionary(grouping: songs) { $0.artist.flatMap(cleanArtist) ?? "" }
        for (artist, theirSongs) in byArtist.sorted(by: { $0.key < $1.key }) where !artist.isEmpty {
            let genre = theirSongs.lazy.compactMap(\.genre).first
            let count = theirSongs.count == 1 ? "1 song" : "\(theirSongs.count) songs"
            let cryptic = genre.map { "\($0), with \(count) in your library" } ?? "\(count) in your library"
            let knownFor = theirSongs.lazy.compactMap { cleanTitle($0.title) }.first.map { "Known for “\($0)”" }
            add(Puzzle(answer: artist, category: .artist, hints: safeHints([cryptic, knownFor], for: artist)))
        }
        return puzzles
    }

    /// Drops missing hints and any that would give the answer away (e.g. a single named after its album).
    static func safeHints(_ hints: [String?], for answer: String) -> [String] {
        let answerKey = AnswerMatcher.normalize(answer)
        return hints.compactMap { $0 }.filter { !AnswerMatcher.normalize($0).contains(answerKey) }
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
