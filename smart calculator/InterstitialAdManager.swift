import Foundation
import GoogleMobileAds
import UIKit
import Combine

// MARK: - InterstitialAdManager
// Flow:
//  1. Always try to load floor_inter ID first (if floor flag = 1)
//  2. If floor ad fails, fall back to the screen-specific inter ID
//  3. Show ad only when shouldShow() returns true based on flag (1/2/3 logic)

class InterstitialAdManager: NSObject, ObservableObject {
    
    @Published var isAdLoaded = false
    
    private var interstitialAd: InterstitialAd?
    private var primaryAdUnitID: String    // floor_inter ID
    private var fallbackAdUnitID: String   // screen-specific ID
    private var isUsingFallback = false
    private var onAdDismissed: (() -> Void)?
    private var lastShownTime: Date?
    private let cooldownSeconds: TimeInterval = 30 // 30 sec gap

    // Test IDs
    private let testInterstitialID = "ca-app-pub-3940256099942544/4411468910"
    
    // MARK: - Init
    /// - Parameters:
    ///   - primaryID: floor_inter_id (loaded first when floor flag = 1)
    ///   - fallbackID: screen-specific inter id (used if primary fails or floor flag = 0)
    init(primaryID: String = "", fallbackID: String = "") {
        self.primaryAdUnitID = primaryID.isEmpty ? "" : primaryID
        self.fallbackAdUnitID = fallbackID.isEmpty ? "" : fallbackID
        super.init()
    }
    
    // MARK: - Update IDs at runtime (after RemoteConfig loads)
    func updateIDs(primaryID: String, fallbackID: String) {
        self.primaryAdUnitID = primaryID
        self.fallbackAdUnitID = fallbackID
    }
    
    // MARK: - Load Ad (Floor first, then fallback)
    func loadAd() {
        let remoteConfig = RemoteConfigManager.shared
        
        // Determine which ID to load first
        let idToLoad: String
        if remoteConfig.floorInterAdsFlag == 1 && !remoteConfig.floorInterId.isEmpty {
            idToLoad = remoteConfig.floorInterId
            isUsingFallback = false
        } else {
            idToLoad = fallbackAdUnitID.isEmpty ? testInterstitialID : fallbackAdUnitID
            isUsingFallback = true
        }
        
        print("🎯 Loading interstitial ad: \(idToLoad) (fallback=\(isUsingFallback))")
        loadInterstitial(with: idToLoad)
    }
    
    private func loadInterstitial(with adUnitID: String) {
        let finalID = adUnitID.isEmpty ? testInterstitialID : adUnitID
        let request = Request()
        
        InterstitialAd.load(with: finalID, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Interstitial load failed (\(finalID)): \(error.localizedDescription)")
                
                // If floor ad failed, try fallback screen-specific ID
                if !self.isUsingFallback && !self.fallbackAdUnitID.isEmpty {
                    print("🔄 Retrying with fallback ID: \(self.fallbackAdUnitID)")
                    self.isUsingFallback = true
                    self.loadInterstitial(with: self.fallbackAdUnitID)
                } else {
                    DispatchQueue.main.async { self.isAdLoaded = false }
                }
                return
            }
            
            DispatchQueue.main.async {
                print("✅ Interstitial ad loaded successfully")
                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
                self.isAdLoaded = true
            }
        }
    }
    
    // MARK: - Show Ad
    /// Call this with the appropriate shouldShow check from RemoteConfigManager
    func showAdIfReady(onDismissed: (() -> Void)? = nil) {
        
        guard !SubscriptionManager.shared.isPremium else {
            onDismissed?()
            return
        }
        
        if let last = lastShownTime, Date().timeIntervalSince(last) < cooldownSeconds {
            print("⏳ Cooldown active, skipping ad")
            onDismissed?()
            return
        }

        guard isAdLoaded, let ad = interstitialAd else {
            print("⚠️ Interstitial ad not ready")
            onDismissed?()
            return
        }
        
        guard let rootVC = getRootViewController() else {
            print("❌ Root VC not found")
            onDismissed?()
            return
        }
        
        self.onAdDismissed = onDismissed
        ad.present(from: rootVC)
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return nil }
        // Walk up the full presentation chain so ads work inside sheets/modals too.
        // Fixes: "already presenting another view controller" when settings is a sheet.
        return topMostViewController(from: rootVC)
    }

    private func topMostViewController(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return topMostViewController(from: presented)
        }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return topMostViewController(from: visible)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(from: selected)
        }
        return vc
    }
}

// MARK: - FullScreenContentDelegate
extension InterstitialAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        print("✅ Interstitial dismissed")
        lastShownTime = Date() // ✅ Track karo kab dikhaya
        interstitialAd = nil
        isAdLoaded = false
        onAdDismissed?()
        onAdDismissed = nil
        loadAd() // Preload — but show nahi hoga jaldi
    }

    
    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Interstitial failed to present: \(error.localizedDescription)")
        interstitialAd = nil
        isAdLoaded = false
        onAdDismissed?()
        onAdDismissed = nil
    }
}

// MARK: - Convenience Singleton Managers per screen

extension InterstitialAdManager {
    
    /// Splash screen interstitial manager
    static let splash: InterstitialAdManager = {
        let rc = RemoteConfigManager.shared
        return InterstitialAdManager(primaryID: rc.floorInterId, fallbackID: rc.splashInterId)
    }()
    
    /// More screen interstitial manager
    static let more: InterstitialAdManager = {
        let rc = RemoteConfigManager.shared
        return InterstitialAdManager(primaryID: rc.floorInterId, fallbackID: rc.moreInterId)
    }()
    
    /// Converter screen interstitial manager
    static let converter: InterstitialAdManager = {
        let rc = RemoteConfigManager.shared
        return InterstitialAdManager(primaryID: rc.floorInterId, fallbackID: rc.converterInterId)
    }()
    
    /// Setting screen interstitial manager
    static let setting: InterstitialAdManager = {
        let rc = RemoteConfigManager.shared
        return InterstitialAdManager(primaryID: rc.floorInterId, fallbackID: rc.settingInterId)
    }()
    
    /// Main screen foreground interstitial (background → foreground)
    static let mainForeground: InterstitialAdManager = {
        let rc = RemoteConfigManager.shared
        return InterstitialAdManager(primaryID: rc.floorInterId, fallbackID: rc.mainInterId)
    }()
}
