import Foundation

/// The coin packs sold in the shop. The IDs must match the in-app purchases in
/// App Store Connect and in Products.storekit (used when running from Xcode).
enum CoinPack: String, CaseIterable, Identifiable {
    case small = "club.gogoslab.Vowelless.coins500"
    case medium = "club.gogoslab.Vowelless.coins1500"
    case large = "club.gogoslab.Vowelless.coins5000"

    var id: String { rawValue }

    var coins: Int {
        switch self {
        case .small: 500
        case .medium: 1_500
        case .large: 5_000
        }
    }

    var title: String {
        switch self {
        case .small: "Handful"
        case .medium: "Bag of coins"
        case .large: "Treasure chest"
        }
    }

    var badge: String? {
        switch self {
        case .small: nil
        case .medium: "Popular"
        case .large: "Best value"
        }
    }

    /// How many coins to draw in the stack on the shop card.
    var stackHeight: Int {
        switch self {
        case .small: 1
        case .medium: 2
        case .large: 3
        }
    }
}
