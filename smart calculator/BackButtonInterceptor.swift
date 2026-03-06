import SwiftUI

// MARK: - BackButtonInterceptor
// For separate_more screens (age, discount, loan, tip):
//   - If the screen's flag == 1, show interstitial (from more_screen's inter ID) on back press
//   - If flag == 0, just dismiss without ads

struct BackButtonInterceptor: ViewModifier {
    let action: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        action()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
    }
}

extension View {
    func onBackButton(perform action: @escaping () -> Void) -> some View {
        modifier(BackButtonInterceptor(action: action))
    }
}

// MARK: - SeparateMoreBackButton
// Use this modifier for sub-screens under "separate_more" group.
// It automatically checks the flag and shows a more_screen inter ad if enabled.
//
// Usage:
//   .separateMoreBackButton(screenType: .tip)
//   .separateMoreBackButton(screenType: .age)

struct SeparateMoreBackButton: ViewModifier {
    let screenType: SeparateMoreScreenType
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowingAd = false
    
    private var interManager: InterstitialAdManager { InterstitialAdManager.more }
    private var remoteConfig: RemoteConfigManager { RemoteConfigManager.shared }
    
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: handleBackTap) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
            .onAppear {
                // Preload inter ad for this session
                if remoteConfig.shouldShowSeparateMoreInterAd(for: screenType) {
                    interManager.loadAd()
                }
            }
    }
    
    private func handleBackTap() {
        let shouldShowAd = remoteConfig.shouldShowSeparateMoreInterAd(for: screenType)
        
        if shouldShowAd && interManager.isAdLoaded {
            interManager.showAdIfReady {
                presentationMode.wrappedValue.dismiss()
            }
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

extension View {
    /// Back button with automatic inter ad for separate_more sub-screens.
    /// Inter ad ID comes from more_screen's more_inter_id (with floor_inter fallback).
    func separateMoreBackButton(screenType: SeparateMoreScreenType) -> some View {
        modifier(SeparateMoreBackButton(screenType: screenType))
    }
}
