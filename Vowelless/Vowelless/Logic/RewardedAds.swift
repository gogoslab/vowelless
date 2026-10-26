import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform

/// Optional "watch a video, get coins" ads, through Google AdMob.
/// Handles the privacy consent form (required in the EU/UK) before any ad is requested.
@MainActor
@Observable
final class RewardedAds: NSObject {
    enum State: Equatable {
        case idle, loading, ready, unavailable
    }

    /// Coins for watching one ad from the shop or when short of coins.
    static let coinReward = 25
    /// Ads a player can watch for coins per day (the daily-reward double doesn't count).
    static let dailyLimit = 5

    /// Google's official test IDs, used until real ones are set in Info.plist (GADApplicationIdentifier, VWLRewardedAdUnitID).
    private static let testAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    private static let watchedKey = "rewardedAds.watched"
    private static let watchedDayKey = "rewardedAds.day"

    private(set) var state: State = .idle
    private(set) var watchedToday: Int
    /// The privacy form must be offered from Settings (EU/UK players).
    private(set) var privacyOptionsRequired = false

    private let defaults: UserDefaults
    private var ad: RewardedAd?
    private var started = false
    private var pendingReward: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let sameDay = (defaults.object(forKey: Self.watchedDayKey) as? Date).map { Calendar.current.isDateInToday($0) } ?? false
        watchedToday = sameDay ? defaults.integer(forKey: Self.watchedKey) : 0
        super.init()
    }

    /// The master switch: `VWLAdsEnabled` in Info.plist. When off, the ad SDK is never started,
    /// no consent form is shown and every ad button stays hidden.
    static var isEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "VWLAdsEnabled") as? Bool ?? false
    }

    var adUnitID: String {
        Bundle.main.object(forInfoDictionaryKey: "VWLRewardedAdUnitID") as? String ?? Self.testAdUnitID
    }

    var isReady: Bool { state == .ready }
    var watchesLeftToday: Int { max(0, Self.dailyLimit - watchedTodayFresh) }

    /// Call once at launch: asks for consent where needed, starts the SDK and loads the first ad.
    func start() async {
        guard !started else { return }
        started = true
        guard Self.isEnabled else {
            state = .unavailable
            return
        }
        await updateConsent()
        guard ConsentInformation.shared.canRequestAds else {
            state = .unavailable
            return
        }
        await MobileAds.shared.start()
        await load()
    }

    /// Shows an ad; `onReward` runs only if the player watched it to the end.
    /// `counted` ads use up one of today's watches.
    func show(counted: Bool = true, onReward: @escaping () -> Void) {
        guard Self.isEnabled, let ad, isReady, !counted || watchesLeftToday > 0,
              let root = GameCenter.topViewController() else { return }
        pendingReward = { [weak self] in
            if counted { self?.recordWatch() }
            onReward()
        }
        state = .idle
        ad.present(from: root) { [weak self] in
            // Called on the main thread when the reward is earned.
            MainActor.assumeIsolated {
                self?.pendingReward?()
                self?.pendingReward = nil
            }
        }
    }

    /// Re-opens the consent form (Settings → Privacy choices).
    func showPrivacyOptions() async {
        guard let root = GameCenter.topViewController() else { return }
        try? await ConsentForm.presentPrivacyOptionsForm(from: root)
    }

    // MARK: - Private

    private func updateConsent() async {
        let parameters = RequestParameters()
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            if let root = GameCenter.topViewController() {
                try await ConsentForm.loadAndPresentIfRequired(from: root)
            }
        } catch {
            // Offline or misconfigured: ads stay off unless consent was given before.
        }
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private func load() async {
        guard state != .loading, ConsentInformation.shared.canRequestAds else { return }
        state = .loading
        do {
            let loaded = try await RewardedAd.load(with: adUnitID, request: Request())
            loaded.fullScreenContentDelegate = self
            ad = loaded
            state = .ready
        } catch {
            ad = nil
            state = .unavailable
            // Try again later; no-fill is common.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(60))
                if self?.state == .unavailable { await self?.load() }
            }
        }
    }

    private var watchedTodayFresh: Int {
        let sameDay = (defaults.object(forKey: Self.watchedDayKey) as? Date).map { Calendar.current.isDateInToday($0) } ?? false
        return sameDay ? watchedToday : 0
    }

    private func recordWatch() {
        watchedToday = watchedTodayFresh + 1
        defaults.set(watchedToday, forKey: Self.watchedKey)
        defaults.set(Date(), forKey: Self.watchedDayKey)
    }
}

extension RewardedAds: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.ad = nil
            self.pendingReward = nil
            await self.load()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.ad = nil
            self.pendingReward = nil
            await self.load()
        }
    }
}
