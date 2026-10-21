import StoreKit
import StoreKitTest
import Testing
@testable import Vowelless

/// Buys coin packs against the local Products.storekit file (no App Store Connect needed).
@MainActor
@Suite(.serialized)
struct StoreTests {
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    private func makeStore() -> (Store, Wallet) {
        let defaults = UserDefaults(suiteName: "StoreTests-\(UUID().uuidString)")!
        let wallet = Wallet(defaults: defaults)
        return (Store(wallet: wallet, defaults: defaults), wallet)
    }

    /// Waits for the store to pick up a transaction from `Transaction.updates`.
    private func waitForCoins(_ wallet: Wallet, toChangeFrom before: Int) async throws {
        for _ in 0..<50 where wallet.coins == before {
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    @Test func loadsAllThreePacks() async throws {
        let session = try makeSession()
        defer { _ = session }
        let (store, _) = makeStore()

        await store.loadProducts()

        #expect(store.loadState == .loaded)
        #expect(Set(store.products.keys) == Set(CoinPack.allCases))
        #expect(store.products[.small]?.displayPrice.contains("0.99") == true)
    }

    /// `buyProduct` completes a purchase the way the App Store does and delivers it through
    /// `Transaction.updates`, the same path as Ask to Buy or a purchase interrupted by a crash.
    @Test(arguments: CoinPack.allCases)
    func buyingAPackAddsItsCoins(pack: CoinPack) async throws {
        let session = try makeSession()
        defer { _ = session }
        let (store, wallet) = makeStore()
        await store.start()
        let before = wallet.coins

        try await session.buyProduct(identifier: pack.rawValue)
        try await waitForCoins(wallet, toChangeFrom: before)

        #expect(wallet.coins == before + pack.coins)
    }
}
