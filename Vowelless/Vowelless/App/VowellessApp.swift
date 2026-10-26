import SwiftUI

@main
struct VowellessApp: App {
    @State private var library = MusicLibrary()
    @State private var wallet: Wallet
    @State private var store: Store
    @State private var gameCenter = GameCenter()
    @State private var ads = RewardedAds()
    @State private var dailyReward = DailyReward()
    @State private var dailyPuzzle = DailyPuzzle()
    @State private var progress = PlayerProgress(reporter: GameCenterReporter())

    init() {
        let wallet = Wallet()
        _wallet = State(initialValue: wallet)
        _store = State(initialValue: Store(wallet: wallet))
    }
    @AppStorage(MusicSource.storageKey) private var musicSource: MusicSource = .builtIn

    var body: some Scene {
        WindowGroup {
            RootView()
                .fontDesign(.rounded)
                .preferredColorScheme(.dark)
                .environment(library)
                .environment(wallet)
                .environment(store)
                .environment(gameCenter)
                .environment(ads)
                .environment(dailyReward)
                .environment(dailyPuzzle)
                .environment(progress)
                .onChange(of: gameCenter.isSignedIn) { _, signedIn in
                    if signedIn { progress.resync() }
                }
                .task { await store.start() }
                .task { await dailyPuzzle.feed.refresh() }
                .task { gameCenter.authenticate() }
                .task {
                    if musicSource.usesLibrary { await library.load() }
                }
        }
    }
}

/// Shows the home screen, with SplashView on top until its tiles have landed.
/// This state lives here rather than in `VowellessApp`: SwiftUI can re-evaluate the
/// scene's content off the main actor during async renders, which traps if it reads changing state.
private struct RootView: View {
    @State private var showSplash = true
    @State private var titleFrame: CGRect?

    var body: some View {
        ZStack {
            HomeView(titleHidden: showSplash) { titleFrame = $0 }
            if showSplash {
                SplashView(target: titleFrame) { showSplash = false }
            }
        }
    }
}
