//
//  smart_calculatorApp.swift
//  smart calculator
//
//  Created by Hevin Technoweb on 30/01/26.
//

import SwiftUI
import Firebase
import GoogleMobileAds

@main
struct smart_calculatorApp: App {
    
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var localizationManager = LocalizationManager()
    @StateObject private var currencyManager = CurrencyManager()
    
    init() {
        // Firebase configure
        FirebaseApp.configure()
        GoogleMobileAds.MobileAds.shared.start { _ in
            print("✅ Google Mobile Ads initialized")
        }
    }
        
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(themeManager)
                .environmentObject(localizationManager)
                .environmentObject(currencyManager)
        }
    }
}
