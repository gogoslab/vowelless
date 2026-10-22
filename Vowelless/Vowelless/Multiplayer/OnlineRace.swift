import GameKit
import Observation

/// Connects a Game Center match to a RaceEngine: sends its messages and feeds it what arrives.
@MainActor
@Observable
final class OnlineRace: NSObject, Identifiable {
    let id = UUID()
    let match: GKMatch
    let engine: RaceEngine
    private let pool: [Puzzle]
    private let difficulty: Difficulty
    private var started = false

    init(match: GKMatch, pool: [Puzzle], difficulty: Difficulty) {
        self.match = match
        self.pool = pool
        self.difficulty = difficulty
        let local = GKLocalPlayer.local
        let players = [local] + match.players
        engine = RaceEngine(
            localPlayerID: local.gamePlayerID,
            playerIDs: players.map(\.gamePlayerID),
            playerNames: Dictionary(players.map { ($0.gamePlayerID, $0.displayName) }, uniquingKeysWith: { a, _ in a })
        )
        super.init()
        match.delegate = self
        engine.send = { [weak self] message in self?.broadcast(message) }
        startIfReady()
    }

    /// The host starts once everyone has connected.
    private func startIfReady() {
        guard !started, match.expectedPlayerCount == 0 else { return }
        started = true
        if engine.isHost {
            engine.begin(pool: pool, difficulty: difficulty)
        }
    }

    private func broadcast(_ message: RaceMessage) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        try? match.sendData(toAllPlayers: data, with: .reliable)
    }

    func leave() {
        engine.leave()
        match.delegate = nil
        match.disconnect()
    }
}

extension OnlineRace: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        let playerID = player.gamePlayerID
        guard let message = try? JSONDecoder().decode(RaceMessage.self, from: data) else { return }
        Task { @MainActor in self.engine.receive(message, from: playerID) }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        let playerID = player.gamePlayerID
        Task { @MainActor in
            switch state {
            case .connected: self.startIfReady()
            case .disconnected: self.engine.playerLeft(playerID)
            default: break
            }
        }
    }
}
