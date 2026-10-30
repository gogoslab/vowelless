import UIKit

/// Vibrations that go with the sound effects. They follow the system's own haptics setting too.
@MainActor
final class Haptics {
    static let shared = Haptics()
    static let enabledKey = "hapticsEnabled"

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    static func play(_ effect: Sounds.Effect) { shared.play(effect) }

    func play(_ effect: Sounds.Effect) {
        guard isEnabled else { return }
        switch effect {
        case .tap: light.impactOccurred(intensity: 0.6)
        case .pop: soft.impactOccurred()
        case .tick: rigid.impactOccurred(intensity: 0.5)
        case .correct, .coin, .fanfare: notification.notificationOccurred(.success)
        case .wrong: notification.notificationOccurred(.error)
        case .reveal, .lose: notification.notificationOccurred(.warning)
        }
    }
}
