import SwiftUI

/// "Watch a video, get coins": shown in the shop, and when the player can't afford a helper.
struct FreeCoinsCard: View {
    var compact = false

    @Environment(RewardedAds.self) private var ads
    @Environment(Wallet.self) private var wallet
    @State private var earned = 0

    var body: some View {
        if compact {
            if canWatch {
                Button(action: watch) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.rectangle.fill")
                        Text("Watch ad")
                        CoinLabel(amount: RewardedAds.coinReward, size: 16, color: Theme.ink)
                    }
                    .font(.system(.headline, design: .rounded, weight: .black))
                }
                .buttonStyle(ChunkyButtonStyle(color: Category.artist.color, foreground: Theme.ink, depth: 5, cornerRadius: 16))
            }
        } else {
            card
        }
    }

    private var canWatch: Bool { ads.isReady && ads.watchesLeftToday > 0 }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return HStack(spacing: 16) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(Category.song.color)
                .frame(width: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text("FREE")
                    .font(.system(.caption, design: .rounded, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Category.song.color))
                Text("Watch a short video")
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text(status)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: watch) {
                CoinLabel(amount: RewardedAds.coinReward, size: 18)
                    .frame(minWidth: 64)
            }
            .buttonStyle(ChunkyButtonStyle(color: Category.song.color, depth: 5, cornerRadius: 16, horizontalPadding: 14))
            .disabled(!canWatch)
            .opacity(canWatch ? 1 : 0.5)
            .accessibilityLabel("Watch a video for \(RewardedAds.coinReward) coins")
        }
        .padding(16)
        .background(shape.fill(Theme.tileFace))
        .background(shape.fill(Theme.tileFace.darker()).offset(y: 6))
        .padding(.bottom, 6)
    }

    private var status: String {
        if ads.watchesLeftToday == 0 { return "Come back tomorrow for more" }
        switch ads.state {
        case .ready: return "\(ads.watchesLeftToday) left today"
        case .loading, .idle: return "Loading a video…"
        case .unavailable: return "No videos right now, try later"
        }
    }

    private func watch() {
        ads.show {
            wallet.earn(RewardedAds.coinReward)
            Sounds.play(.coin)
        }
    }
}
