import GameKit
import SwiftUI

struct HomeView: View {
    @Environment(MusicLibrary.self) private var library
    @Environment(Wallet.self) private var wallet
    @Environment(Store.self) private var store
    @Environment(GameCenter.self) private var gameCenter
    @State private var showOnline = false
    @State private var showDailyReward = false
    @Environment(DailyReward.self) private var dailyReward
    @Environment(DailyPuzzle.self) private var dailyPuzzle
    @State private var showDailyResult = false
    @State private var showSignInForTrophies = false
    @Environment(RewardedAds.self) private var ads
    @State private var showShop = false
    @State private var bounce = false
    @State private var showSettings = false
    @State private var showTutorial = false
    @AppStorage(TutorialView.seenKey) private var tutorialSeen = false
    @AppStorage(Difficulty.storageKey) private var difficulty: Difficulty = .easy
    /// Hides the title while SplashView's tiles are flying into its place.
    var titleHidden = false
    var onTitleFrame: (CGRect) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header

                    dailyCard
                    modeButton(.online)
                    modeButton(.train)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(PlayfulBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: titleHidden, initial: true) { _, hidden in
            if !hidden {
                bounce = true
                if !tutorialSeen {
                    showTutorial = true
                } else if dailyReward.isAvailable {
                    showDailyReward = true
                }
            }
        }
        .task(id: tutorialSeen) {
            // Wait for the splash and the first-launch tutorial, so the consent form (if any) doesn't cover them.
            guard tutorialSeen else { return }
            try? await Task.sleep(for: .seconds(2))
            await ads.start()
        }
        .fullScreenCover(isPresented: $showTutorial, onDismiss: {
            tutorialSeen = true
            if dailyReward.isAvailable { showDailyReward = true }
        }) {
            TutorialView { showTutorial = false }
                .fontDesign(.rounded)
                .environment(dailyPuzzle)
        }
        .sheet(isPresented: $showDailyReward) {
            DailyRewardView()
                .fontDesign(.rounded)
                .environment(dailyReward)
                .environment(wallet)
                .environment(ads)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showOnline, onDismiss: { gameCenter.pendingInvite = nil }) {
            OnlinePlayView(invite: gameCenter.pendingInvite, difficulty: difficulty) {
                showOnline = false
            }
            .fontDesign(.rounded)
            .environment(wallet)
        }
        .onChange(of: gameCenter.pendingInvite) { _, invite in
            if invite != nil { showOnline = true }
        }
        .sheet(isPresented: $showShop) {
            ShopView()
                .fontDesign(.rounded)
                .environment(wallet)
                .environment(store)
                .environment(ads)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .fontDesign(.rounded)
                .environment(library)
                .environment(ads)
                .environment(dailyPuzzle)
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button { showShop = true } label: {
                    HStack(spacing: 6) {
                        CoinLabel(amount: wallet.coins, size: 18)
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Theme.correct)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.black.opacity(0.2)))
                }
                .accessibilityLabel("\(wallet.coins) coins. Get more coins")
                Spacer(minLength: 0)
                if dailyReward.isAvailable {
                    Button { showDailyReward = true } label: {
                        Text("🎁").font(.system(size: 22))
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Category.artist.color, foreground: Theme.ink, depth: 4, cornerRadius: 14, horizontalPadding: 10))
                    .accessibilityLabel("Daily reward")
                }
                Button {
                    if gameCenter.isSignedIn {
                        GKAccessPoint.shared.trigger(state: .dashboard) {}
                    } else {
                        showSignInForTrophies = true
                    }
                } label: {
                    Image(systemName: "trophy.fill").font(.system(size: 18, weight: .black))
                }
                .buttonStyle(ChunkyButtonStyle(color: Category.artist.color, foreground: Theme.ink, depth: 4, cornerRadius: 14, horizontalPadding: 12))
                .accessibilityLabel("Leaderboards and achievements")
                .alert("Sign in to Game Center", isPresented: $showSignInForTrophies) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Leaderboards and achievements use Game Center. Sign in under Settings → Game Center; your progress so far will be sent when you do.")
                }
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 18, weight: .black))
                }
                .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 4, cornerRadius: 14, horizontalPadding: 12))
                .accessibilityLabel("Settings")
            }

            HStack(spacing: 6) {
                ForEach(Theme.title.indices, id: \.self) { i in
                    LetterTile.title(i)
                        .offset(y: bounce ? -8 : 0)
                        .animation(.easeInOut(duration: 0.7).repeatForever().delay(Double(i) * 0.12), value: bounce)
                }
            }
            .opacity(titleHidden ? 0 : 1)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                // Only SplashView needs this, so stop reporting once it's gone.
                if titleHidden { onTitleFrame(frame) }
            }
            .padding(.top, 4)

            Text("Guess it without the vowels!")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    @ViewBuilder
    private var dailyCard: some View {
        let label = HStack(spacing: 14) {
            Image(systemName: dailyPuzzle.isPlayedToday ? "checkmark.seal.fill" : "calendar")
                .font(.system(size: 30, weight: .black))
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily #\(dailyPuzzle.todayNumber)")
                    .font(.system(.title2, design: .rounded, weight: .black))
                Text(dailyPuzzle.isPlayedToday
                     ? dailyPuzzle.results.map(\.emoji).joined()
                     : "Today's 5 clues")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
            if dailyPuzzle.isPlayedToday {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .black))
                    .accessibilityLabel("Share")
            }
            if dailyPuzzle.currentStreak > 0 {
                Text("🔥\(dailyPuzzle.currentStreak)")
                    .font(.system(.title3, design: .rounded, weight: .black))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        let style = ChunkyButtonStyle(color: Category.book.color, depth: 8, cornerRadius: 24)

        if dailyPuzzle.isPlayedToday {
            Button { showDailyResult = true } label: { label }
                .buttonStyle(style)
                .sheet(isPresented: $showDailyResult) {
                    DailyResultView()
                        .environment(dailyPuzzle)
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PlayfulBackground())
                        .fontDesign(.rounded)
                        .presentationDetents([.medium])
                }
        } else {
            NavigationLink {
                DailyGameView(daily: dailyPuzzle, wallet: wallet)
            } label: { label }
            .buttonStyle(style)
        }
    }

    private func modeButton(_ mode: PlayMode) -> some View {
        NavigationLink {
            CategoryPickerView(mode: mode)
        } label: {
            HStack(spacing: 18) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 40, weight: .black))
                    .shadow(color: .black.opacity(0.15), radius: 0, y: 3)
                    .frame(width: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                    Text(mode.subtitle)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .opacity(0.85)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        }
        .buttonStyle(ChunkyButtonStyle(color: mode.color, depth: 9, cornerRadius: 28))
    }
}

#Preview {
    HomeView()
        .fontDesign(.rounded)
        .environment(MusicLibrary())
        .environment(Wallet())
        .environment(Store(wallet: Wallet()))
        .environment(GameCenter())
        .environment(RewardedAds())
        .environment(DailyReward())
        .environment(DailyPuzzle())
        .environment(PlayerProgress())
}
