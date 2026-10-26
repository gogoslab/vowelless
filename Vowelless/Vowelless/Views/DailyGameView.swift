import SwiftUI

/// Starts today's daily puzzle only when it's actually opened, so the clues are locked in at that moment.
struct DailyGameView: View {
    let daily: DailyPuzzle
    let wallet: Wallet
    @State private var session: GameSession?

    var body: some View {
        Group {
            if let session {
                GameView(session: session, accent: Category.book.color, daily: daily)
            } else {
                PlayfulBackground()
            }
        }
        .onAppear {
            guard session == nil else { return }
            let puzzles = daily.startToday()
            session = GameSession(puzzles: puzzles, wallet: wallet, rounds: puzzles.count, shuffles: false)
        }
    }
}
