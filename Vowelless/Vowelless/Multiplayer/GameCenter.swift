import GameKit
import Observation
import SwiftUI

/// Signs the player in to Game Center and listens for invites from friends.
@MainActor
@Observable
final class GameCenter: NSObject {
    enum Status: Equatable {
        case unknown, signingIn, signedIn, signedOut
    }

    private(set) var status: Status = .unknown
    /// An invite the player accepted (from Messages or a Game Center notification), waiting to be shown.
    var pendingInvite: GKInvite?

    var isSignedIn: Bool { status == .signedIn }
    var localPlayer: GKLocalPlayer { .local }

    /// Call once at launch. If Game Center needs the player to sign in, it shows its own sheet.
    func authenticate() {
        guard status == .unknown else { return }
        status = .signingIn
        // Game Kit may call this on a background thread, and more than once (e.g. after signing in from Settings).
        GKLocalPlayer.local.authenticateHandler = { @Sendable [weak self] viewController, _ in
            nonisolated(unsafe) let viewController = viewController
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    Self.topViewController()?.present(viewController, animated: true)
                    return
                }
                self.status = GKLocalPlayer.local.isAuthenticated ? .signedIn : .signedOut
                if self.status == .signedIn {
                    GKLocalPlayer.local.register(self)
                }
            }
        }
    }

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

extension GameCenter: GKLocalPlayerListener {
    nonisolated func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        nonisolated(unsafe) let invite = invite
        Task { @MainActor in self.pendingInvite = invite }
    }
}
