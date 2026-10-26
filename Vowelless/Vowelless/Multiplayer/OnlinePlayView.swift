import GameKit
import SwiftUI

/// Play Online: finds a random player (or opens a friend's invite), and races a bot if nobody turns up.
struct OnlinePlayView: View {
    var invite: GKInvite?
    /// The category picked on this phone; an accepted invite uses the inviter's instead.
    var category: Category?
    let difficulty: Difficulty
    let onClose: () -> Void

    @Environment(GameCenter.self) private var gameCenter
    @Environment(PlayerProgress.self) private var progress
    @State private var search = MatchSearch()
    @State private var race: ActiveRace?
    @State private var showFriendPicker = false
    @State private var opponentFound = false
    @State private var bounce = false

    var body: some View {
        Group {
            if let race {
                RaceView(race: race, onExit: onClose)
                    .environment(progress)
            } else {
                searching
            }
        }
        .task { await start() }
        .fullScreenCover(isPresented: $showFriendPicker) {
            MatchmakerView(invite: invite, category: raceCategory) { match in
                showFriendPicker = false
                startOnline(match)
            } onCancel: {
                showFriendPicker = false
                // Declined an invite: back home. Backed out of inviting: keep looking for a random player.
                if invite != nil { onClose() } else { Task { await start() } }
            }
            .ignoresSafeArea()
        }
    }

    private var raceCategory: Category? {
        if let invite { return RaceCategory.category(forPlayerGroup: invite.playerGroup) }
        return category
    }

    // MARK: - Flow

    private func start() async {
        if invite != nil {
            showFriendPicker = true
            return
        }
        guard gameCenter.isSignedIn else {
            // Without Game Center there's no one to find; a shorter wait still feels like a search.
            try? await Task.sleep(for: .seconds(Double.random(in: 4...9)))
            await startBot()
            return
        }
        switch await search.find(category: raceCategory) {
        case .match(let match):
            withAnimation(.spring(bounce: 0.4)) { opponentFound = true }
            startOnline(match)
        case .noOneAvailable:
            // The player may have opened the friend picker meanwhile; leave them there.
            guard !showFriendPicker, race == nil else { return }
            await startBot()
        }
    }

    private func startOnline(_ match: GKMatch) {
        guard race == nil else {
            match.disconnect()
            return
        }
        search.cancel()
        race = .online(OnlineRace(match: match, pool: RaceCategory.pool(for: raceCategory), difficulty: difficulty))
    }

    /// Nobody turned up: a bot steps in, presented exactly like a real opponent.
    private func startBot() async {
        guard race == nil, !Task.isCancelled else { return }
        withAnimation(.spring(bounce: 0.4)) { opponentFound = true }
        try? await Task.sleep(for: .seconds(1))
        guard race == nil, !Task.isCancelled else { return }
        race = .bot(BotRace(level: .randomStandIn(), pool: RaceCategory.pool(for: raceCategory), difficulty: difficulty))
    }

    // MARK: - Searching screen

    private var searching: some View {
        VStack(spacing: 24) {
            HStack {
                Button {
                    search.cancel()
                    onClose()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .black))
                }
                .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 4, cornerRadius: 14, horizontalPadding: 14))
                .accessibilityLabel("Cancel")
                Spacer()
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(Array("RACE".enumerated()), id: \.offset) { i, letter in
                    LetterTile(letter: letter, size: 58, face: Theme.palette[i], ink: .white, tilt: Theme.tilt(i))
                        .offset(y: bounce ? -10 : 0)
                        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.12), value: bounce)
                }
            }
            .onAppear { bounce = true }

            Group {
                if opponentFound {
                    Text("Player found!")
                        .font(.system(.title2, design: .rounded, weight: .black))
                } else {
                    VStack(spacing: 10) {
                        Text("Looking for a player…")
                            .font(.system(.title2, design: .rounded, weight: .black))
                        ProgressView().tint(.white).controlSize(.large)
                    }
                }
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .transition(.scale.combined(with: .opacity))

            Spacer()

            if !opponentFound, gameCenter.isSignedIn {
                Button {
                    search.cancel()
                    showFriendPicker = true
                } label: {
                    Label("Invite a friend instead", systemImage: "person.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChunkyButtonStyle(color: Category.song.color, depth: 7))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PlayfulBackground())
    }
}
