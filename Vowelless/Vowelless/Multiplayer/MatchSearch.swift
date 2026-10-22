import GameKit
import Observation

/// Looks for a random opponent on Game Center, and gives up after a while so a bot can step in.
@MainActor
@Observable
final class MatchSearch {
    /// Only created and used on the main actor; GKMatch just isn't marked Sendable.
    enum Result: @unchecked Sendable {
        case match(GKMatch)
        case noOneAvailable
    }

    static let timeout: Duration = .seconds(30)

    private(set) var isSearching = false
    private var finished = false

    func find(category: Category?, timeout: Duration = timeout) async -> Result {
        isSearching = true
        finished = false
        defer { isSearching = false }

        return await withCheckedContinuation { continuation in
            let request = GKMatchRequest()
            request.minPlayers = 2
            request.maxPlayers = 2
            // Only players who picked the same category are matched together.
            request.playerGroup = RaceCategory.playerGroup(for: category)

            // Game Kit may call back on a background thread, so this closure mustn't be main-actor-isolated.
            GKMatchmaker.shared().findMatch(for: request) { @Sendable [weak self] match, _ in
                nonisolated(unsafe) let match = match
                Task { @MainActor in
                    guard let self, !self.finished else {
                        // Found someone just after giving up: let them go rather than leave them hanging.
                        match?.disconnect()
                        return
                    }
                    self.finished = true
                    continuation.resume(returning: match.map(Result.match) ?? .noOneAvailable)
                }
            }

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                guard let self, !self.finished else { return }
                self.finished = true
                GKMatchmaker.shared().cancel()
                continuation.resume(returning: .noOneAvailable)
            }
        }
    }

    func cancel() {
        guard isSearching, !finished else { return }
        GKMatchmaker.shared().cancel()
    }
}
