import Foundation
import MediaPlayer
import Observation

/// Reads song titles and artist names from the device's Music library.
@MainActor
@Observable
final class MusicLibrary {
    enum Status: Equatable {
        case notDetermined, denied, restricted, loading, loaded
    }

    private(set) var status: Status
    private(set) var puzzles: [Puzzle] = []

    init() {
        status = Self.status(for: MPMediaLibrary.authorizationStatus())
    }

    func count(of category: Category) -> Int {
        puzzles.filter { $0.category == category }.count
    }

    /// Asks for access if needed, then reads the library.
    func load() async {
        guard status != .loading else { return }
        let authorization = await Self.requestAuthorization()
        guard authorization == .authorized else {
            status = Self.status(for: authorization)
            return
        }
        status = .loading
        let songs = await Task.detached(priority: .userInitiated) { Self.readSongs() }.value
        puzzles = LibraryCleaner.puzzles(from: songs)
        status = .loaded
    }

    private nonisolated static func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus {
        let current = MPMediaLibrary.authorizationStatus()
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    private nonisolated static func readSongs() -> [LibrarySong] {
        (MPMediaQuery.songs().items ?? []).compactMap { item in
            item.title.map {
                LibrarySong(title: $0, artist: item.albumArtist ?? item.artist, album: item.albumTitle, genre: item.genre)
            }
        }
    }

    private static func status(for authorization: MPMediaLibraryAuthorizationStatus) -> Status {
        switch authorization {
        case .authorized: .loaded
        case .denied: .denied
        case .restricted: .restricted
        default: .notDetermined
        }
    }
}

enum PuzzleCatalog {
    /// Built-in puzzles, with Songs and Artists & Bands taken from the library according to `source`.
    /// Falls back to the built-in list for a category the library has nothing for.
    @MainActor
    static func puzzles(library: MusicLibrary, source: MusicSource) -> [Puzzle] {
        let builtIn = PuzzleStore.builtIn
        guard source.usesLibrary, !library.puzzles.isEmpty else { return builtIn }

        var result = builtIn.filter { !MusicSource.categories.contains($0.category) }
        for category in MusicSource.categories {
            let fromLibrary = library.puzzles.filter { $0.category == category }
            let fromBuiltIn = builtIn.filter { $0.category == category }
            switch source {
            case .library:
                result += fromLibrary.isEmpty ? fromBuiltIn : fromLibrary
            case .both:
                let known = Set(fromBuiltIn.map { AnswerMatcher.normalize($0.answer) })
                result += fromBuiltIn + fromLibrary.filter { !known.contains(AnswerMatcher.normalize($0.answer)) }
            case .builtIn:
                result += fromBuiltIn
            }
        }
        return result
    }
}
