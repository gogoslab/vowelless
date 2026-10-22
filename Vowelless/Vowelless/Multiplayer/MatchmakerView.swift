import GameKit
import SwiftUI

/// Game Center's own screen for inviting friends or finding a random opponent.
struct MatchmakerView: UIViewControllerRepresentable {
    var invite: GKInvite?
    var category: Category? = nil
    let onMatch: (GKMatch) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller: GKMatchmakerViewController?
        if let invite {
            controller = GKMatchmakerViewController(invite: invite)
        } else {
            let request = GKMatchRequest()
            request.minPlayers = 2
            request.maxPlayers = 2
            request.playerGroup = RaceCategory.playerGroup(for: category)
            request.inviteMessage = "Race me in Vowelless! Guess it without the vowels."
            controller = GKMatchmakerViewController(matchRequest: request)
        }
        guard let controller else { return UIViewController() }
        controller.matchmakerDelegate = context.coordinator
        controller.canStartWithMinimumPlayers = true
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    /// Game Kit calls these on the main thread.
    @MainActor
    final class Coordinator: NSObject, @preconcurrency GKMatchmakerViewControllerDelegate {
        let parent: MatchmakerView
        init(parent: MatchmakerView) { self.parent = parent }

        func matchmakerViewController(_ controller: GKMatchmakerViewController, didFind match: GKMatch) {
            parent.onMatch(match)
        }

        func matchmakerViewControllerWasCancelled(_ controller: GKMatchmakerViewController) {
            parent.onCancel()
        }

        func matchmakerViewController(_ controller: GKMatchmakerViewController, didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}
