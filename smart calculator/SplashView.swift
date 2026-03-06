import SwiftUI
import Combine

struct SplashView: View {
    @State private var isActive = false
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var calculationHistory = CalculationHistory()
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared // ✅ Add karo
    @ObservedObject private var remoteConfig = RemoteConfigManager.shared
    
    // Use the shared splash interstitial manager
    private let splashAdManager = InterstitialAdManager.splash
    
    var body: some View {
        if isActive {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(calculationHistory)
        } else {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
            .onAppear {
                remoteConfig.fetchRemoteConfig()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    handleSplashAd()
                }
            }
        }
    }
    
    // MARK: - Splash Ad Logic
    private func handleSplashAd() {
        print("🔍 Checking splash ad...")
        // ✅ Premium user hai tो ad skip karo
        guard !subscriptionManager.isPremium else {
            print("⏭️ Premium user - skipping splash ad")
            navigateToMain()
            return
        }
        
        print("   splashInterAdsFlag: \(remoteConfig.splashInterAdsFlag)")
        print("   splashInterId: \(remoteConfig.splashInterId)")
        print("   floorInterAdsFlag: \(remoteConfig.floorInterAdsFlag)")
        
        // Check frequency flag - 0 means disabled entirely
        guard remoteConfig.splashInterAdsFlag != 0 else {
            print("⏭️ Splash ads disabled (flag=0)")
            navigateToMain()
            return
        }
        
        // Check once-lifetime / once-day / every-time logic
        guard remoteConfig.shouldShowSplashAd() else {
            print("⏭️ Splash ad skipped by frequency logic")
            navigateToMain()
            return
        }
        
        // Update IDs from RemoteConfig (fetched after init)
        splashAdManager.updateIDs(
            primaryID: remoteConfig.floorInterId,
            fallbackID: remoteConfig.splashInterId
        )
        splashAdManager.loadAd()
        
        print("🎯 Loading splash interstitial...")
        waitAndShowAd()
    }
    
    private func waitAndShowAd() {
        var attempts = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            attempts += 1
            
            if splashAdManager.isAdLoaded {
                timer.invalidate()
                print("✅ Splash ad loaded, showing...")
                splashAdManager.showAdIfReady {
                    navigateToMain()
                }
            } else if attempts >= 20 { // 4 seconds max wait
                timer.invalidate()
                print("⏱️ Splash ad load timeout, navigating")
                navigateToMain()
            }
        }
    }
    
    private func navigateToMain() {
        withAnimation {
            isActive = true
        }
    }
}
