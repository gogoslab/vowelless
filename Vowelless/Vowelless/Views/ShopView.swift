import StoreKit
import SwiftUI

/// "Get coins": the three coin packs as chunky cards.
struct ShopView: View {
    @Environment(Store.self) private var store
    @Environment(Wallet.self) private var wallet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase

    @State private var buying: CoinPack?
    @State private var message: Message?

    private struct Message: Equatable {
        let text: String
        let isError: Bool
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                ForEach(CoinPack.allCases) { pack in
                    packCard(pack)
                }

                if let message {
                    Text(message.text)
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .foregroundStyle(message.isError ? Theme.orange : Theme.correct)
                        .multilineTextAlignment(.center)
                        .transition(.scale.combined(with: .opacity))
                }

                Text("Coins are used for hints and vowels. Purchases are handled by the App Store.")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                if store.loadState == .failed {
                    Button("Couldn't reach the store. Try again") {
                        Task { await store.loadProducts() }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 4, cornerRadius: 16))
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(PlayfulBackground())
        .task {
            if store.loadState != .loaded { await store.loadProducts() }
        }
        .sensoryFeedback(.success, trigger: wallet.coins)
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Get coins")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .black))
                }
                .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 4, cornerRadius: 14))
                .accessibilityLabel("Close")
            }

            HStack(spacing: 8) {
                Text("You have")
                CoinLabel(amount: wallet.coins, size: 22)
                    .animation(.spring(bounce: 0.4), value: wallet.coins)
            }
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func packCard(_ pack: CoinPack) -> some View {
        let product = store.products[pack]
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return HStack(spacing: 16) {
            CoinStack(count: pack.stackHeight)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                if let badge = pack.badge {
                    Text(badge.uppercased())
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(pack == .large ? Theme.correct : Category.song.color))
                }
                Text(pack.coins.formatted())
                    .font(.system(.title, design: .rounded, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text(pack.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await buy(pack) }
            } label: {
                Group {
                    if buying == pack {
                        ProgressView().tint(.white)
                    } else {
                        Text(product?.displayPrice ?? "–")
                    }
                }
                .frame(minWidth: 64)
            }
            .buttonStyle(ChunkyButtonStyle(color: Category.character.color, depth: 5, cornerRadius: 16, horizontalPadding: 14))
            .disabled(product == nil || buying != nil)
            .opacity(product == nil ? 0.5 : 1)
            .accessibilityLabel(product.map { "Buy \(pack.coins) coins for \($0.displayPrice)" } ?? "\(pack.coins) coins, unavailable")
        }
        .padding(16)
        .background(shape.fill(Theme.tileFace))
        .background(shape.fill(Theme.tileFace.darker()).offset(y: 6))
        .padding(.bottom, 6)
    }

    private func buy(_ pack: CoinPack) async {
        guard let product = store.products[pack] else { return }
        buying = pack
        defer { buying = nil }
        do {
            let outcome = await store.handle(try await purchase(product))
            withAnimation(.spring(bounce: 0.5)) {
                switch outcome {
                case .purchased(let coins):
                    message = Message(text: "+\(coins.formatted()) coins added! 🎉", isError: false)
                case .pending:
                    message = Message(text: "Waiting for approval…", isError: false)
                case .cancelled:
                    message = nil
                case .failed:
                    message = Message(text: "That didn't work. Please try again.", isError: true)
                }
            }
        } catch {
            withAnimation { message = Message(text: "That didn't work. Please try again.", isError: true) }
        }
    }
}

/// A little pile of gold coins for the shop cards.
private struct CoinStack: View {
    let count: Int

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                CoinIcon(size: 44)
                    .offset(x: CGFloat(i - (count - 1) / 2) * 10 - (count == 2 ? 5 : 0), y: CGFloat(-i) * 8)
            }
        }
    }
}

#Preview {
    let wallet = Wallet()
    ShopView()
        .environment(wallet)
        .environment(Store(wallet: wallet))
}
