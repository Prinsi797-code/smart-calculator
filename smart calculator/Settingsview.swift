import SwiftUI

// MARK: - Setting Screen Ad Coordinator
// Inter ID: setting_screen > inter_id (with floor_inter fallback)
// Banner ID: setting_screen > setting_baner_id (gated by baner_ad_flag)
class SettingAdCoordinator {
    static let shared = SettingAdCoordinator()
    let interManager = InterstitialAdManager.setting

    private let cooldownSeconds: TimeInterval = 30
    private var lastAdShownDate: Date? = nil

    private init() {}

    func preload() {
        let rc = RemoteConfigManager.shared
        interManager.updateIDs(
            primaryID: rc.floorInterId,
            fallbackID: rc.settingInterId
        )
        if rc.settingInterAdsFlag != 0 {
            interManager.loadAd()
        }
    }

    func handleBack(dismiss: DismissAction) {
        let rc = RemoteConfigManager.shared

        // Gate 1: flag disabled
        guard rc.settingInterAdsFlag != 0 else { dismiss(); return }

        // Gate 2: cooldown
        if let last = lastAdShownDate,
           Date().timeIntervalSince(last) < cooldownSeconds {
            print("⏳ Setting inter ad on cooldown, skipping")
            dismiss()
            return
        }

        // Gate 3: frequency logic
        guard rc.shouldShowSettingInterAd() else { dismiss(); return }

        // Gate 4: ad ready
        guard interManager.isAdLoaded else {
            print("⚠️ Setting inter ad not loaded yet, skipping")
            dismiss()
            return
        }

        lastAdShownDate = Date()
        interManager.showAdIfReady { dismiss() }
    }

    func resetCooldown() { lastAdShownDate = nil }
}

// MARK: - AppSettingsView
struct AppSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @ObservedObject private var rc = RemoteConfigManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    List {
                        // Languages Section
                        Section(header: Text("languages".localized(localizationManager))) {
                            NavigationLink(destination: LanguagesView()) {
                                HStack {
                                    Image(systemName: "globe")
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    Text("settings.language".localized(localizationManager))
                                    Spacer()
                                    Text(localizationManager.currentLanguage.displayName)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Theme Mode Section
                        Section(header: Text("settings.appearance".localized(localizationManager))) {
                            NavigationLink(destination: ThemeModeView()) {
                                HStack {
                                    Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                                        .foregroundColor(.orange)
                                        .frame(width: 30)
                                    Text("settings.theme".localized(localizationManager))
                                    Spacer()
                                    Text(themeManager.isDarkMode
                                         ? "theme.current.dark".localized(localizationManager)
                                         : "theme.current.light".localized(localizationManager))
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Bottom Banner — setting_screen > setting_baner_id
                    BannerAdContainer(screen: .setting)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("settings.title".localized(localizationManager))
                    .font(.system(size: 20, weight: .semibold))
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { SettingAdCoordinator.shared.handleBack(dismiss: dismiss) }) {
                    Image(systemName: "chevron.left").foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            SettingAdCoordinator.shared.preload()
        }
        
        var backgroundColor: Color {
            themeManager.isDarkMode ? Color.black : Color(UIColor.systemGroupedBackground)
        }
    }
}

// MARK: - LanguagesView
struct LanguagesView: View {
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var rc = RemoteConfigManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.ignoresSafeArea()
                VStack(spacing: 0) {
                    List {
                        ForEach(Language.allCases, id: \.self) { language in
                            Button(action: { localizationManager.currentLanguage = language }) {
                                HStack(spacing: 12) {
                                    Image(language.flagImageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                    
                                    Text("\(language.displayName)(\(language.nativeDisplayName))")
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if localizationManager.currentLanguage == language {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Bottom Banner — setting_screen > setting_baner_id
                    BannerAdContainer(screen: .setting)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("settings.language".localized(localizationManager))
                    .font(.system(size: 20, weight: .semibold))
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { SettingAdCoordinator.shared.handleBack(dismiss: dismiss) }) {
                    Image(systemName: "chevron.left").foregroundColor(.primary)
                }
            }
        }
        
        var backgroundColor: Color {
            themeManager.isDarkMode ? Color.black : Color(UIColor.systemGroupedBackground)
        }

    }
}

// MARK: - ThemeModeView
struct ThemeModeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @ObservedObject private var rc = RemoteConfigManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.ignoresSafeArea()
                VStack(spacing: 0) {
                    List {
                        Button(action: { themeManager.isDarkMode = false }) {
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .foregroundColor(.orange).frame(width: 30)
                                Text("theme.light".localized(localizationManager))
                                    .foregroundColor(.primary)
                                Spacer()
                                if !themeManager.isDarkMode {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                        }
                        
                        Button(action: { themeManager.isDarkMode = true }) {
                            HStack {
                                Image(systemName: "moon.fill")
                                    .foregroundColor(.indigo).frame(width: 30)
                                Text("theme.dark".localized(localizationManager))
                                    .foregroundColor(.primary)
                                Spacer()
                                if themeManager.isDarkMode {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    // Bottom Banner — setting_screen > setting_baner_id
                    BannerAdContainer(screen: .setting)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("settings.theme".localized(localizationManager))
                    .font(.system(size: 20, weight: .semibold))
            }
            // "Done" button shows inter ad then dismisses
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("settings.done".localized(localizationManager)) {
                    SettingAdCoordinator.shared.handleBack(dismiss: dismiss)
                }
            }
        }
        var backgroundColor: Color {
            themeManager.isDarkMode ? Color.black : Color(UIColor.systemGroupedBackground)
        }
    }
}

#Preview {
    NavigationView {
        AppSettingsView()
            .environmentObject(ThemeManager())
            .environmentObject(LocalizationManager())
    }
}
