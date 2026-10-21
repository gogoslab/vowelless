import Foundation
import Observation
import StoreKit

/// Loads the coin packs from the App Store and adds coins to the wallet when one is bought.
@MainActor
@Observable
final class Store {
    enum LoadState: Equatable {
        case idle, loading, loaded, failed
    }

    enum Outcome: Equatable {
        case purchased(coins: Int)
        case pending
        case cancelled
        case failed
    }

    private static let creditedKey = "creditedTransactionIDs"

    private let wallet: Wallet
    private let defaults: UserDefaults
    private(set) var products: [CoinPack: Product] = [:]
    private(set) var loadState: LoadState = .idle
    private var updatesTask: Task<Void, Never>?

    init(wallet: Wallet, defaults: UserDefaults = .standard) {
        self.wallet = wallet
        self.defaults = defaults
    }

    /// Call once at launch: listens for purchases made elsewhere (Ask to Buy, interrupted
    /// purchases, other devices) and credits any that were never finished.
    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    await self?.credit(update)
                }
            }
        }
        for await unfinished in Transaction.unfinished {
            await credit(unfinished)
        }
        await loadProducts()
    }

    func loadProducts() async {
        guard loadState != .loading else { return }
        loadState = .loading
        do {
            let found = try await Product.products(for: CoinPack.allCases.map(\.rawValue))
            products = Dictionary(uniqueKeysWithValues: found.compactMap { product in
                CoinPack(rawValue: product.id).map { ($0, product) }
            })
            loadState = products.isEmpty ? .failed : .loaded
        } catch {
            loadState = .failed
        }
    }

    /// Handles the result of `Product.purchase`, crediting the coins for a successful purchase.
    func handle(_ result: Product.PurchaseResult) async -> Outcome {
        switch result {
        case .success(let verification):
            let coins = await credit(verification)
            return coins > 0 ? .purchased(coins: coins) : .failed
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .failed
        }
    }

    /// Adds the pack's coins once per transaction, then finishes it. Returns the coins added.
    @discardableResult
    private func credit(_ verification: VerificationResult<Transaction>) async -> Int {
        // Only trust transactions signed by the App Store (or by Xcode's local StoreKit file).
        guard case .verified(let transaction) = verification else { return 0 }
        guard let pack = CoinPack(rawValue: transaction.productID), transaction.revocationDate == nil else {
            await transaction.finish()
            return 0
        }

        var credited = defaults.array(forKey: Self.creditedKey) as? [String] ?? []
        let id = String(transaction.id)
        if !credited.contains(id) {
            wallet.earn(pack.coins * transaction.purchasedQuantity)
            credited.append(id)
            // Unfinished transactions are redelivered, so a short history is enough to avoid double credit.
            defaults.set(Array(credited.suffix(200)), forKey: Self.creditedKey)
        }
        await transaction.finish()
        return pack.coins * transaction.purchasedQuantity
    }
}
