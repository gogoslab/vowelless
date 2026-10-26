import SwiftUI

/// Today's daily puzzle result: colored squares, score, streak, share button and a countdown.
struct DailyResultView: View {
    @Environment(DailyPuzzle.self) private var daily
    var coinsEarned: Int? = nil

    var body: some View {
        VStack(spacing: 18) {
            Text("Daily #\(daily.playedNumber)")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                ForEach(Array(daily.results.enumerated()), id: \.offset) { _, result in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color(result))
                        .frame(width: 48, height: 48)
                        .overlay(Image(systemName: symbol(result)).font(.system(size: 20, weight: .black)).foregroundStyle(.white))
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color(result).darker()).offset(y: 4))
                }
            }
            .accessibilityLabel(daily.results.map(\.rawValue).joined(separator: ", "))

            HStack(spacing: 18) {
                stat("⭐", "\(daily.score)/\(daily.maxScore)")
                stat("🔥", "\(daily.currentStreak) day\(daily.currentStreak == 1 ? "" : "s")")
                if let coinsEarned { stat("", nil, coins: coinsEarned) }
            }

            ShareLink(item: daily.shareText) {
                Label("Share result", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChunkyButtonStyle(color: Category.song.color, depth: 7))

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text("Next puzzle in \(Self.format(daily.timeUntilNext))")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func stat(_ icon: String, _ text: String?, coins: Int? = nil) -> some View {
        Group {
            if let coins {
                CoinLabel(amount: coins, size: 20)
            } else {
                Text("\(icon) \(text ?? "")")
            }
        }
        .font(.system(.title3, design: .rounded, weight: .black))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.2)))
    }

    private func color(_ result: ClueResult) -> Color {
        switch result {
        case .clean: Theme.correct
        case .helped: Category.artist.color
        case .missed: Theme.wrong
        }
    }

    private func symbol(_ result: ClueResult) -> String {
        switch result {
        case .clean: "checkmark"
        case .helped: "lightbulb.fill"
        case .missed: "xmark"
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
    }
}
