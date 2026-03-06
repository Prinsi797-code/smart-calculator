import Foundation
import FirebaseRemoteConfig
import Combine

class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()
    
    private let remoteConfig = RemoteConfig.remoteConfig()
    
    // MARK: - Splash Screen
    @Published var splashInterAdsFlag: Int = 3      // splash_screen > spash_inter_ads_flag (1=once lifetime, 2=once day, 3=every time)
    @Published var splashInterId: String = ""        // splash_screen > splash_inter_id
    
    // MARK: - Floor Interstitial (loads first, fallback for all screens)
    @Published var floorInterAdsFlag: Int = 0        // floor_inter > inter_ads_flag (0=disabled, 1=enabled)
    @Published var floorInterId: String = ""         // floor_inter > floor_inter_id
    
    // MARK: - Main Screen
    @Published var mainAdFlag: Int = 1               // main_screen > ad_flag (0=no ads, 1=load ads)
    @Published var mainBanerId: String = ""          // main_screen > baner_id
    
    // MARK: - More Screen
    @Published var moreInterAdsFlag: Int = 3         // more_screen > more_inter_ads_flag
    @Published var moreInterId: String = ""          // more_screen > more_inter_id
    @Published var moreBanerFlag: Int = 1            // more_screen > more_baner_flag
    @Published var moreBanerId: String = ""          // more_screen > more_baner_id
    @Published var moreNativeAdsFlag: Int = 1        // more_screen > more_native_ads_flag
    @Published var moreNativeAdsId: String = ""      // more_screen > more_native_ads

    // MARK: - Converter Screen
    @Published var converterBanerFlag: Int = 1       // converter_screen > converter_baner_flag
    @Published var converterBanerId: String = ""     // converter_screen > converter_baner_id
    @Published var converterInterAdsFlag: Int = 3    // converter_screen > converter_inter_ads_flag
    @Published var converterInterId: String = ""     // converter_screen > converter_inter_id
    @Published var converterNativeAdsFlag: Int = 1   // converter_screen > native_ads_flag
    @Published var converterNativeAdsId: String = "" // converter_screen > native_ads_id
    
    // MARK: - Setting Screen
    @Published var settingBanerAdFlag: Int = 1       // setting_screen > baner_ad_flag
    @Published var settingBanerId: String = ""       // setting_screen > setting_baner_id
    @Published var settingInterAdsFlag: Int = 3      // setting_screen > setting_inter_ads_flag
    @Published var settingInterId: String = ""       // setting_screen > inter_id
    
    // MARK: - Separate More (back button / inter flags for sub-screens)
    @Published var ageFlag: Int = 1                  // separate_more > age_flag
    @Published var discountFlag: Int = 1             // separate_more > discount_flag
    @Published var loanFlag: Int = 1                 // separate_more > loan_flag
    @Published var tipFlag: Int = 1                  // separate_more > tip_flag
    
    
    @Published var mainInterAdFlag: Int = 1      // main_screen_ad > main_ad_flag
    @Published var mainInterId: String = ""      // main_screen_ad > inter_ads_id

    
    // MARK: - Frequency Counters (per screen)
    private var splashCounter: Int = 0
    private var moreInterCounter: Int = 0
    private var converterInterCounter: Int = 0
    private var settingInterCounter: Int = 0
    
    // Track once-per-day ad shown dates
    private var splashLastShownDate: Date?
    private var moreLastShownDate: Date?
    private var converterLastShownDate: Date?
    private var settingLastShownDate: Date?
    
    // Track once-per-lifetime flags
    private let splashLifetimeKey = "splashAdShownLifetime"
    private let moreLifetimeKey = "moreAdShownLifetime"
    private let converterLifetimeKey = "converterAdShownLifetime"
    private let settingLifetimeKey = "settingAdShownLifetime"
    
    
    private init() {
        setupRemoteConfig()
        fetchRemoteConfig()
    }
    
    // MARK: - Setup
    private func setupRemoteConfig() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600
        remoteConfig.configSettings = settings
        
        let defaults: [String: NSObject] = [
            // Splash Screen
            "spash_inter_ads_flag": 3 as NSObject,
            "splash_inter_id": "" as NSObject,
            
            // Floor Interstitial
            "inter_ads_flag": 0 as NSObject,
            "floor_inter_id": "" as NSObject,
            
            // Main Screen
            "ad_flag": 1 as NSObject,
            "baner_id": "" as NSObject,
            
            // More Screen
            "more_inter_ads_flag": 3 as NSObject,
            "more_inter_id": "" as NSObject,
            "more_baner_flag": 1 as NSObject,
            "more_baner_id": "" as NSObject,
            "more_native_ads_flag": 1 as NSObject,
            "more_native_ads": "" as NSObject,
            
            // Converter Screen
            "converter_baner_flag": 1 as NSObject,
            "converter_baner_id": "" as NSObject,
            "converter_inter_ads_flag": 3 as NSObject,
            "converter_inter_id": "" as NSObject,
            "native_ads_flag": 1 as NSObject,
            "native_ads_id": "" as NSObject,
            
            // Setting Screen
            "baner_ad_flag": 1 as NSObject,
            "setting_baner_id": "" as NSObject,
            "setting_inter_ads_flag": 3 as NSObject,
            "inter_id": "" as NSObject,
            
            // Separate More
            "age_flag": 1 as NSObject,
            "discount_flag": 1 as NSObject,
            "loan_flag": 1 as NSObject,
            "tip_flag": 1 as NSObject,
            
            "main_ad_flag": 1 as NSObject,
            "inter_ads_id": "" as NSObject,
        ]
        remoteConfig.setDefaults(defaults)
    }
    
//    func fetchRemoteConfig() {
//        remoteConfig.fetch { [weak self] status, error in
//            guard let self = self else { return }
//            if status == .success {
//                self.remoteConfig.activate { _, _ in
//                    DispatchQueue.main.async { self.updateValues() }
//                }
//            } else {
//                print("❌ Remote Config fetch failed: \(error?.localizedDescription ?? "Unknown")")
//                DispatchQueue.main.async { self.updateValues() }
//            }
//        }
//    }
    
    func fetchRemoteConfig(completion: (() -> Void)? = nil) {
        remoteConfig.fetch { [weak self] status, error in
            guard let self = self else { return }
            if status == .success {
                self.remoteConfig.activate { _, _ in
                    DispatchQueue.main.async {
                        self.updateValues()
                        completion?()
                    }
                }
            } else {
                print("Remote Config fetch failed: \(error?.localizedDescription ?? "Unknown")")
                DispatchQueue.main.async {
                    self.updateValues()
                    completion?()
                }
            }
        }
    }
    
    private func updateValues() {
        // Splash Screen
        splashInterAdsFlag = remoteConfig["spash_inter_ads_flag"].numberValue.intValue
        splashInterId = remoteConfig["splash_inter_id"].stringValue ?? ""
        
        // Floor Interstitial
        floorInterAdsFlag = remoteConfig["inter_ads_flag"].numberValue.intValue
        floorInterId = remoteConfig["floor_inter_id"].stringValue ?? ""
        
        // Main Screen
        mainAdFlag = remoteConfig["ad_flag"].numberValue.intValue
        mainBanerId = remoteConfig["baner_id"].stringValue ?? ""
        
        // Main Screen Inter
        mainInterAdFlag = remoteConfig["main_ad_flag"].numberValue.intValue
        mainInterId = remoteConfig["inter_ads_id"].stringValue ?? ""
        
        // More Screen
        moreInterAdsFlag = remoteConfig["more_inter_ads_flag"].numberValue.intValue
        moreInterId = remoteConfig["more_inter_id"].stringValue ?? ""
        moreBanerFlag = remoteConfig["more_baner_flag"].numberValue.intValue
        moreBanerId = remoteConfig["more_baner_id"].stringValue ?? ""
        moreNativeAdsFlag = remoteConfig["more_native_ads_flag"].numberValue.intValue
        moreNativeAdsId = remoteConfig["more_native_ads"].stringValue ?? ""
        
        // Converter Screen
        converterBanerFlag = remoteConfig["converter_baner_flag"].numberValue.intValue
        converterBanerId = remoteConfig["converter_baner_id"].stringValue ?? ""
        converterInterAdsFlag = remoteConfig["converter_inter_ads_flag"].numberValue.intValue
        converterInterId = remoteConfig["converter_inter_id"].stringValue ?? ""
        converterNativeAdsFlag = remoteConfig["native_ads_flag"].numberValue.intValue
        converterNativeAdsId = remoteConfig["native_ads_id"].stringValue ?? ""
        
        // Setting Screen
        settingBanerAdFlag = remoteConfig["baner_ad_flag"].numberValue.intValue
        settingBanerId = remoteConfig["setting_baner_id"].stringValue ?? ""
        settingInterAdsFlag = remoteConfig["setting_inter_ads_flag"].numberValue.intValue
        settingInterId = remoteConfig["inter_id"].stringValue ?? ""
        
        // Separate More
        ageFlag = remoteConfig["age_flag"].numberValue.intValue
        discountFlag = remoteConfig["discount_flag"].numberValue.intValue
        loanFlag = remoteConfig["loan_flag"].numberValue.intValue
        tipFlag = remoteConfig["tip_flag"].numberValue.intValue
        
        print("✅ Remote Config Updated")
        print("   Splash Flag: \(splashInterAdsFlag), ID: \(splashInterId)")
        print("   Floor Inter Flag: \(floorInterAdsFlag), ID: \(floorInterId)")
        print("   Main Banner Flag: \(mainAdFlag), ID: \(mainBanerId)")
        print("   More Inter Flag: \(moreInterAdsFlag), Inter ID: \(moreInterId)")
        print("   Converter Inter Flag: \(converterInterAdsFlag), Inter ID: \(converterInterId)")
        print("   Setting Inter Flag: \(settingInterAdsFlag), Inter ID: \(settingInterId)")
    }
    
    // MARK: - Banner Helpers
    
    var shouldShowMainBanner: Bool { mainAdFlag == 1 }
    var shouldShowMoreBanner: Bool { moreBanerFlag == 1 }
    var shouldShowConverterBanner: Bool { converterBanerFlag == 1 }
    var shouldShowSettingBanner: Bool { settingBanerAdFlag == 1 }
    var shouldShowMainInterAd: Bool { mainInterAdFlag == 1 }
    
    // MARK: - Interstitial ID Resolution
    // Floor inter loads first. If floor ad fails, fallback to screen-specific ID.
    
    var effectiveSplashInterId: String {
        return floorInterAdsFlag == 1 ? floorInterId : splashInterId
    }
    
    var effectiveMoreInterId: String {
        return floorInterAdsFlag == 1 ? floorInterId : moreInterId
    }
    
    var effectiveConverterInterId: String {
        return floorInterAdsFlag == 1 ? floorInterId : converterInterId
    }
    
    var effectiveSettingInterId: String {
        return floorInterAdsFlag == 1 ? floorInterId : settingInterId
    }
    
    // MARK: - Inter Ad Show Logic
    // Flag 1 = once in a lifetime, 2 = once per day, 3 = every time
    
    func shouldShowSplashAd() -> Bool {
        return shouldShow(
            flag: splashInterAdsFlag,
            lifetimeKey: splashLifetimeKey,
            lastShownDate: &splashLastShownDate,
            counter: &splashCounter
        )
    }
    
    func shouldShowMoreInterAd() -> Bool {
        return shouldShow(
            flag: moreInterAdsFlag,
            lifetimeKey: moreLifetimeKey,
            lastShownDate: &moreLastShownDate,
            counter: &moreInterCounter
        )
    }
    
    func shouldShowConverterInterAd() -> Bool {
        return shouldShow(
            flag: converterInterAdsFlag,
            lifetimeKey: converterLifetimeKey,
            lastShownDate: &converterLastShownDate,
            counter: &converterInterCounter
        )
    }
    
    func shouldShowSettingInterAd() -> Bool {
        return shouldShow(
            flag: settingInterAdsFlag,
            lifetimeKey: settingLifetimeKey,
            lastShownDate: &settingLastShownDate,
            counter: &settingInterCounter
        )
    }
    
    /// Returns true for back-button/inter ad on sub-screen based on separate_more flags
    func shouldShowSeparateMoreInterAd(for screenType: SeparateMoreScreenType) -> Bool {
        let flag: Int
        switch screenType {
        case .age:      flag = ageFlag
        case .discount: flag = discountFlag
        case .loan:     flag = loanFlag
        case .tip:      flag = tipFlag
        }
        // flag 0 = no ad, flag 1 = show ad; inter id comes from more_screen's more_inter_id
        return flag == 1
    }
    
    // MARK: - Private Helper
    private func shouldShow(
        flag: Int,
        lifetimeKey: String,
        lastShownDate: inout Date?,
        counter: inout Int
    ) -> Bool {
        switch flag {
        case 1: // Once in a lifetime
            let shown = UserDefaults.standard.bool(forKey: lifetimeKey)
            if shown { return false }
            UserDefaults.standard.set(true, forKey: lifetimeKey)
            return true
            
        case 2: // Once per day
            if let last = lastShownDate, Calendar.current.isDateInToday(last) {
                return false
            }
            lastShownDate = Date()
            return true
            
        case 3: // Every time
            return true
            
        default:
            return false
        }
    }
    
    func resetLifetimeFlags() {
        UserDefaults.standard.removeObject(forKey: splashLifetimeKey)
        UserDefaults.standard.removeObject(forKey: moreLifetimeKey)
        UserDefaults.standard.removeObject(forKey: converterLifetimeKey)
        UserDefaults.standard.removeObject(forKey: settingLifetimeKey)
    }
}

// MARK: - Screen Type Enum for Separate More screens
enum SeparateMoreScreenType {
    case age, discount, loan, tip
}
