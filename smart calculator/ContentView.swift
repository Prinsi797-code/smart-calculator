import SwiftUI
import Combine

struct ContentView: View {

    init() {
        let appearance = UITabBarAppearance()

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemOrange
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemOrange
        ]

        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    @StateObject private var themeManager = ThemeManager()
    @StateObject private var calculationHistory = CalculationHistory()
    @StateObject private var localizationManager = LocalizationManager()
    @ObservedObject private var remoteConfig = RemoteConfigManager.shared
    @State private var selectedTab = 0
    
    // MARK: - Foreground Ad
    @Environment(\.scenePhase) private var scenePhase
    @State private var isFirstActivation = true  // Splash ke baad pehla activation skip karne ke liye
    private let mainFgAdManager = InterstitialAdManager.mainForeground

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    TabView(selection: $selectedTab) {
                        
                        BasicCalculatorView()
                            .tabItem {
                                Label("tab.basic".localized(localizationManager), systemImage: "plusminus.circle.fill")
                            }
                            .tag(0)
                        
                        ScientificCalculatorView()
                            .tabItem {
                                Label("tab.scientific".localized(localizationManager), systemImage: "function")
                            }
                            .tag(1)
                        
                        HistoryView()
                            .tabItem {
                                Label("tab.history".localized(localizationManager), systemImage: "clock.fill")
                            }
                            .tag(2)
                        
                        ConvertersView()
                            .tabItem {
                                Label("tab.convert".localized(localizationManager), systemImage: "arrow.left.arrow.right.circle.fill")
                            }
                            .tag(3)
                        
                        MoreToolsView()
                            .tabItem {
                                Label("tab.more".localized(localizationManager), systemImage: "ellipsis.circle.fill")
                            }
                            .tag(4)
                    }
                    
                    BannerAdContainer(screen: .main)
                }
            }
        }
        .environmentObject(themeManager)
        .environmentObject(calculationHistory)
        .environmentObject(localizationManager)
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onAppear {
            // Pehla .active event (splash ke baad) skip karne ke liye
            // Thodi delay baad flag false karo
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isFirstActivation = false
                // Pehli baar ad preload kar lo
                preloadMainForegroundAd()
            }
        }
    }

    // MARK: - Scene Phase Handler
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // Pehla activation skip karo (ContentView appear hone ke baad ka)
            guard !isFirstActivation else { return }
            
            print("📱 App came to foreground - checking main inter ad...")
            showForegroundAdIfNeeded()
            
        case .background:
            print("📱 App went to background")
            
        case .inactive:
            break
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Preload Ad
    private func preloadMainForegroundAd() {
        guard !SubscriptionManager.shared.isPremium else { return }
        guard remoteConfig.mainInterAdFlag == 1 else { return }
        
        mainFgAdManager.updateIDs(
            primaryID: remoteConfig.floorInterId,
            fallbackID: remoteConfig.mainInterId
        )
        mainFgAdManager.loadAd()
        print("🔄 Main foreground ad preloaded")
    }
    
    // MARK: - Show Ad When App Comes to Foreground
    private func showForegroundAdIfNeeded() {
        guard !SubscriptionManager.shared.isPremium else { return }
        
        // Flag check
        guard remoteConfig.mainInterAdFlag == 1 else {
            print("⏭️ Main inter ad disabled (flag=0)")
            return
        }
        
        // IDs update karo (RemoteConfig already fetch ho chuka hoga)
        mainFgAdManager.updateIDs(
            primaryID: remoteConfig.floorInterId,
            fallbackID: remoteConfig.mainInterId
        )
        
        // Agar ad already loaded hai to seedha dikhao
        if mainFgAdManager.isAdLoaded {
            print("✅ Showing preloaded foreground ad")
            mainFgAdManager.showAdIfReady {
                // Ad dismiss ke baad next ad preload karo
                preloadMainForegroundAd()
            }
            return
        }
        
        // Ad loaded nahi hai to load karo aur wait karo
        mainFgAdManager.loadAd()
        
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
            attempts += 1
            
            if mainFgAdManager.isAdLoaded {
                timer.invalidate()
                print("✅ Foreground ad loaded, showing...")
                mainFgAdManager.showAdIfReady {
                    preloadMainForegroundAd()
                }
            } else if attempts >= 15 { // ~4.5 sec max wait
                timer.invalidate()
                print("⏱️ Foreground ad load timeout, skipping")
            }
        }
    }

    var backgroundColor: Color {
        themeManager.isDarkMode ? Color.black : Color(UIColor.systemGroupedBackground)
    }
}

#Preview {
    ContentView()
}
