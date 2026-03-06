import SwiftUI
import GoogleMobileAds

// MARK: - BannerScreen
enum BannerScreen {
    case main, more, converter, setting

    /// RemoteConfig se banner dikhana chahiye ya nahi (premium check ke bina)
    var remoteConfigAllows: Bool {
        let rc = RemoteConfigManager.shared
        switch self {
        case .main:      return rc.shouldShowMainBanner
        case .more:      return rc.shouldShowMoreBanner
        case .converter: return rc.shouldShowConverterBanner
        case .setting:   return rc.shouldShowSettingBanner
        }
    }

    var adUnitID: String {
        let rc = RemoteConfigManager.shared
        switch self {
        case .main:      return rc.mainBanerId
        case .more:      return rc.moreBanerId
        case .converter: return rc.converterBanerId
        case .setting:   return rc.settingBanerId
        }
    }

    var testID: String { "ca-app-pub-3940256099942544/2934735716" }
}

// MARK: - BannerAdView (UIViewRepresentable)
// ⚠️ Directly use mat karo — BannerAdContainer use karo jo premium check karta hai
struct BannerAdView: UIViewRepresentable {
    let screen: BannerScreen
    static let bannerHeight: CGFloat = 50

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        let adUnitID = screen.adUnitID.isEmpty ? screen.testID : screen.adUnitID
        print("📢 Loading banner for \(screen) with ID: \(adUnitID)")

        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = getRootViewController()
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.load(Request())

        container.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func getRootViewController() -> UIViewController {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return UIViewController()
        }
        return rootVC
    }
}

// MARK: - ✅ BannerAdContainer (ALWAYS YAHI USE KARO)
// Premium + RemoteConfig dono check karta hai
// @ObservedObject se automatically hide ho jayega jab user premium le
struct BannerAdContainer: View {
    let screen: BannerScreen

    // ✅ KEY FIX: isPremium observe karo taaki change hote hi ad hide ho
    @ObservedObject private var subscription = SubscriptionManager.shared

    var body: some View {
        // Premium users ko KABHI ads mat dikhao
        // RemoteConfig ne disable kiya ho to bhi mat dikhao
        if !subscription.isPremium && screen.remoteConfigAllows {
            BannerAdView(screen: screen)
                .frame(height: BannerAdView.bannerHeight)
        }
    }
}

// MARK: - Preview
struct BannerAdView_Previews: PreviewProvider {
    static var previews: some View {
        BannerAdContainer(screen: .main)
            .frame(height: 50)
    }
}
