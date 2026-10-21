import SwiftUI

/// A small gold coin with a raised rim, drawn to match the chunky tiles.
struct CoinIcon: View {
    var size: CGFloat = 20

    var body: some View {
        let gold = Color(red: 1.0, green: 0.80, blue: 0.20)
        ZStack {
            Circle().fill(gold.darker(0.35)).offset(y: size * 0.08)
            Circle().fill(LinearGradient(colors: [gold.mix(with: .white, by: 0.35), gold], startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(gold.darker(0.2), lineWidth: size * 0.09).padding(size * 0.14)
            Text("V")
                .font(.system(size: size * 0.48, weight: .black, design: .rounded))
                .foregroundStyle(gold.darker(0.4))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A coin and an amount, e.g. the wallet balance or a price.
struct CoinLabel: View {
    let amount: Int
    var size: CGFloat = 18
    var color: Color = .white

    var body: some View {
        HStack(spacing: 5) {
            CoinIcon(size: size)
            Text("\(amount)")
                .font(.system(size: size * 0.95, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) coins")
    }
}

#Preview {
    VStack(spacing: 20) {
        CoinIcon(size: 60)
        CoinLabel(amount: 120)
    }
    .padding()
    .background(PlayfulBackground())
}
