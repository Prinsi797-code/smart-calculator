import SwiftUI
import GoogleMobileAds

// MARK: - Custom Native Ad Container View (Banner Style)
class CustomNativeAdView: UIView {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 4
        imageView.backgroundColor = .tertiarySystemBackground
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let adBadge: UILabel = {
        let label = UILabel()
        label.text = "Ad"
        label.font = .systemFont(ofSize: 8, weight: .medium)
        label.textColor = .secondaryLabel
        label.backgroundColor = .tertiarySystemBackground
        label.textAlignment = .center
        label.layer.cornerRadius = 2
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let callToActionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 4
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var nativeAdView: NativeAdView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(headlineLabel)
        containerView.addSubview(callToActionButton)
        containerView.addSubview(adBadge)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 60),
            
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 30),
            iconImageView.heightAnchor.constraint(equalToConstant: 30),
            
            adBadge.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 6),
            adBadge.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            adBadge.widthAnchor.constraint(equalToConstant: 20),
            adBadge.heightAnchor.constraint(equalToConstant: 14),
            
            headlineLabel.leadingAnchor.constraint(equalTo: adBadge.trailingAnchor, constant: 6),
            headlineLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            headlineLabel.trailingAnchor.constraint(equalTo: callToActionButton.leadingAnchor, constant: -8),
            
            callToActionButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            callToActionButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            callToActionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            callToActionButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    func configure(with nativeAd: NativeAd) {
        print("🎨 Configuring banner-style native ad")
        
        let gadNativeAdView = NativeAdView()
        gadNativeAdView.nativeAd = nativeAd
        gadNativeAdView.headlineView = headlineLabel
        gadNativeAdView.iconView = iconImageView
        gadNativeAdView.callToActionView = callToActionButton
        
        headlineLabel.text = nativeAd.headline
        callToActionButton.setTitle(nativeAd.callToAction ?? "Install", for: .normal)
        
        if let icon = nativeAd.icon?.image {
            iconImageView.image = icon
        } else {
            iconImageView.image = UIImage(systemName: "app.fill")
            iconImageView.tintColor = .systemGray
        }
        
        self.nativeAdView = gadNativeAdView
        containerView.alpha = 1.0
        containerView.isHidden = false
        
        print("✅ Banner-style native ad configured")
    }
}

// MARK: - SwiftUI Wrapper
// Native ads are shown on more_screen only.
// Native ad ID is not part of the new Remote Config structure shown,
// so this uses a static/passed-in adUnitID.
struct NativeAdViewWrapper: UIViewRepresentable {
    let adUnitID: String
    @Binding var isKeyboardVisible: Bool
    
    func makeUIView(context: Context) -> CustomNativeAdView {
        let nativeAdView = CustomNativeAdView()
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.loadAd(adUnitID: adUnitID, nativeAdView: nativeAdView)
        return nativeAdView
    }
    
    func updateUIView(_ uiView: CustomNativeAdView, context: Context) {
        uiView.isHidden = isKeyboardVisible
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator: NSObject, NativeAdLoaderDelegate {
        var adLoader: AdLoader?
        weak var nativeAdView: CustomNativeAdView?
        
        func loadAd(adUnitID: String, nativeAdView: CustomNativeAdView) {
            self.nativeAdView = nativeAdView
            let testID = "ca-app-pub-3940256099942544/3986624511"
            let finalID = adUnitID.isEmpty ? testID : adUnitID
            
            guard let rootViewController = getRootViewController() else {
                print("❌ Root view controller not found")
                return
            }
            
            print("🎯 Loading native ad with ID: \(finalID)")
            let multipleAdsOptions = MultipleAdsAdLoaderOptions()
            multipleAdsOptions.numberOfAds = 1
            
            adLoader = AdLoader(
                adUnitID: finalID,
                rootViewController: rootViewController,
                adTypes: [.native],
                options: [multipleAdsOptions]
            )
            adLoader?.delegate = self
            adLoader?.load(Request())
        }
        
        func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
            print("✅ Native ad received")
            DispatchQueue.main.async { [weak self] in
                self?.nativeAdView?.configure(with: nativeAd)
            }
        }
        
        func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
            print("❌ Native ad failed: \(error.localizedDescription)")
        }
        
        func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
            print("📊 Native ad loader finished")
        }
        
        private func getRootViewController() -> UIViewController? {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else { return nil }
            return rootVC
        }
    }
}

// MARK: - Keyboard Visibility Helper
extension View {
    func onKeyboardChange(perform action: @escaping (Bool) -> Void) -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in action(true) }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in action(false) }
    }
}
