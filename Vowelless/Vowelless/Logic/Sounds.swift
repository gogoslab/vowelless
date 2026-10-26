import AVFoundation

/// Short sound effects. They follow the silent switch and mix with whatever music is playing.
@MainActor
final class Sounds {
    enum Effect: String, CaseIterable {
        case tap, correct, wrong, pop, coin, tick, reveal, fanfare, lose

        var volume: Float {
            switch self {
            case .tap: 0.35
            case .tick: 0.5
            default: 0.8
            }
        }
    }

    static let shared = Sounds()
    static let enabledKey = "soundsEnabled"

    private var players: [Effect: AVAudioPlayer] = [:]
    private var prepared = false

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    static func play(_ effect: Effect) { shared.play(effect) }

    func play(_ effect: Effect) {
        guard isEnabled else { return }
        prepareIfNeeded()
        guard let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    /// Ambient: silenced by the ring/silent switch and mixed with other audio.
    /// Also called after speech recognition, which switches the session to recording.
    static func restoreAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
    }

    private func prepareIfNeeded() {
        guard !prepared else { return }
        prepared = true
        Self.restoreAudioSession()
        for effect in Effect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.volume = effect.volume
            player.prepareToPlay()
            players[effect] = player
        }
    }
}
