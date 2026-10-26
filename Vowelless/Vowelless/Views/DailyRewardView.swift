import SwiftUI

/// The once-a-day gift: a week of growing rewards, with the option to double today's with an ad.
struct DailyRewardView: View {
    @Environment(DailyReward.self) private var reward
    @Environment(Wallet.self) private var wallet
    @Environment(RewardedAds.self) private var ads
    @Environment(\.dismiss) private var dismiss

    @State private var claimed: Int?
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 22) {
            Text("🎁")
                .font(.system(size: 72))
                .scaleEffect(bounce ? 1.08 : 0.96)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: bounce)
                .onAppear { bounce = true }

            VStack(spacing: 6) {
                Text(claimed == nil ? "Daily reward" : "Nice! See you tomorrow")
                    .font(.system(.title, design: .rounded, weight: .black))
                Text(subtitle)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)

            week

            if let claimed {
                CoinLabel(amount: claimed, size: 34)
                    .transition(.scale.combined(with: .opacity))
                Button("Done") { dismiss() }
                    .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 6))
            } else {
                VStack(spacing: 12) {
                    if ads.isReady {
                        Button {
                            ads.show(counted: false) { claim(multiplier: 2) }
                        } label: {
                            Label("Watch an ad to get \(reward.nextAmount * 2)", systemImage: "play.rectangle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Category.artist.color, foreground: Theme.ink, depth: 7))
                    }
                    Button { claim(multiplier: 1) } label: {
                        HStack(spacing: 8) {
                            Text("Claim")
                            CoinLabel(amount: reward.nextAmount, size: 22)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.correct, depth: 7))
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PlayfulBackground())
        .sensoryFeedback(.success, trigger: claimed)
        .interactiveDismissDisabled(claimed == nil)
    }

    private var subtitle: String {
        let day = claimed == nil ? reward.nextDay : reward.streak
        return day > 1 ? "Day \(day) in a row 🔥" : "Come back every day for bigger rewards"
    }

    private var week: some View {
        let day = claimed == nil ? reward.nextDay : reward.streak
        let today = DailyReward.slot(forDay: day)
        return HStack(spacing: 6) {
            ForEach(DailyReward.schedule.indices, id: \.self) { i in
                let done = i < today || (i == today && claimed != nil)
                VStack(spacing: 4) {
                    Text("D\(i + 1)")
                        .font(.system(.caption, design: .rounded, weight: .black))
                    Image(systemName: done ? "checkmark.circle.fill" : "circle.dotted")
                        .font(.system(size: 14, weight: .black))
                    Text("\(DailyReward.schedule[i])")
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .monospacedDigit()
                }
                .foregroundStyle(i == today ? Theme.ink : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(i == today ? Category.artist.color : .black.opacity(done ? 0.35 : 0.2)))
            }
        }
    }

    private func claim(multiplier: Int) {
        guard let amount = reward.claim(into: wallet, multiplier: multiplier) else { return }
        withAnimation(.spring(bounce: 0.5)) { claimed = amount }
    }
}
