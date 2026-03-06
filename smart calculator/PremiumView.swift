import SwiftUI
import StoreKit



// MARK: - Brand Color
extension Color {
    static let brand     = Color(hex: "#f0ad29")
    static let brandDark = Color(hex: "#d4941a")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        self.init(
            red:   Double((n >> 16) & 0xFF) / 255,
            green: Double((n >>  8) & 0xFF) / 255,
            blue:  Double( n        & 0xFF) / 255
        )
    }
}


// MARK: - PremiumView
struct PremiumView: View {
    // ✅ FIX: @ObservedObject for singleton — NOT @StateObject
    // @StateObject creates its own instance; singleton changes won't reflect
    @ObservedObject private var manager = SubscriptionManager.shared
    @Environment(\.dismiss)     private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var localizationManager: LocalizationManager

    @State private var selectedProductID: String = SubscriptionProductID.yearly.rawValue
    @State private var showSuccess = false

    private var activeProductID: String? { manager.activeProductID }
    private var isDark: Bool { colorScheme == .dark }

    private var bgColor: Color {
        isDark ? Color(white: 0.08) : Color(red: 0.87, green: 0.95, blue: 0.98)
    }
    private var cardBg: Color {
        isDark ? Color(white: 0.14) : .white
    }
    private var cardBorder: Color {
        isDark ? Color(white: 0.25) : Color.gray.opacity(0.2)
    }

    var body: some View {
        if showSuccess {
            PremiumSuccessView(isDark: isDark) { dismiss() }
        } else {
            mainView
        }
    }

    // MARK: - Main Layout
    private var mainView: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                bgColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Fixed Hero (does NOT scroll) ──────────────────────────
                    heroImage(totalWidth: geo.size.width)
                        .frame(width: geo.size.width)
                        .frame(height: heroHeight(geo))

                    // ── Scrollable content below ──────────────────────────────
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            planCards
                                .padding(.horizontal, 16)
                                .padding(.top, 16)

                            if let err = manager.purchaseError {
                                Text(err)
                                    .font(.caption).foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24).padding(.top, 8)
                            }

                            subscribeButton
                                .padding(.horizontal, 16)
                                .padding(.top, 18)

                            restoreAndLegal
                                .padding(.top, 6)
                                .padding(.bottom, 30)
                        }
                    }
                    .background(bgColor)
                }
                .ignoresSafeArea(edges: .top)

                // ── Floating close button ─────────────────────────────────────
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .padding(.top, 10)
                .padding(.leading, 16)
            }
        }
        .task { await manager.loadAndVerify() }
        .onChange(of: manager.isPremium) { newValue in
            if newValue { showSuccess = true }
        }
        .onChange(of: manager.activeProductID) { newValue in
            if newValue != nil && manager.isPremium { showSuccess = true }
        }
    }

    // MARK: - Hero height
    private func heroHeight(_ geo: GeometryProxy) -> CGFloat {
        min(max(geo.size.height * 0.40, 220), 300)
    }

    // MARK: - Hero Image (fixed, not scrollable)
    @ViewBuilder
    private func heroImage(totalWidth: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Image(isDark ? "premiumdark" : "premium")
                .resizable()
                .scaledToFill()
                .frame(width: totalWidth)
                .clipped()

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(isDark ? 0.65 : 0.50)],
                startPoint: .center, endPoint: .bottom
            )

            Text("remove.ads".localized(localizationManager))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
    }

    // MARK: - Plan Cards
    private var planCards: some View {
        VStack(spacing: 10) {
            ForEach(planOrder, id: \.self) { pid in
                if let product = manager.products.first(where: { $0.id == pid }),
                   let planEnum = SubscriptionProductID(rawValue: pid) {
                    PlanCard(
                        product: product,
                        plan: planEnum,
                        isSelected: selectedProductID == pid,
                        isActivated: activeProductID == pid,
                        userHasActivePlan: manager.isPremium,
                        cardBg: cardBg,
                        cardBorder: cardBorder
                    ) { selectedProductID = pid }
                } else {
                    PlanCardSkeleton(isDark: isDark)
                }
            }
        }
        // When user already has a plan, auto-select the active card
        .onAppear {
            if let active = activeProductID {
                selectedProductID = active
            }
        }
    }

    // MARK: - Subscribe Button
    private var subscribeButton: some View {
        Button(action: handleSubscribe) {
            HStack(spacing: 8) {
                if manager.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "diamond.fill").font(.system(size: 15))
                    Text(manager.isPremium ? "manage.subscription".localized(localizationManager) : "subscribe.now".localized(localizationManager))
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(colors: [.brand, .brandDark],
                               startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(25)
            .shadow(color: Color.brand.opacity(0.4), radius: 10, y: 4)
        }
        .disabled(manager.isLoading || manager.products.isEmpty)
    }

    // MARK: - Restore + Legal
    private var restoreAndLegal: some View {
        VStack(spacing: 8) {
            Button(action: handleRestore) {
                Text("restore.purchase".localized(localizationManager))
                    .font(.system(size: 13))
                    .foregroundColor(isDark ? .gray : .secondary)
            }

            HStack(spacing: 15) {
                Link("privacy.policy".localized(localizationManager),
                     destination: URL(string: "https://megacalccalculator.blogspot.com/")!)
                Text("|").foregroundColor(.secondary)
                Link("terms.of.use".localized(localizationManager),
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.system(size: 12))
            .foregroundColor(isDark ? .gray : .secondary)
            .padding(.vertical, 20)
        }
            .padding(.vertical, 20)
    }

    // MARK: - Helpers
    private var planOrder: [String] {
        [SubscriptionProductID.yearly.rawValue,
         SubscriptionProductID.monthly.rawValue,
         SubscriptionProductID.weekly.rawValue]
    }

    private func handleSubscribe() {
        guard let product = manager.products.first(where: { $0.id == selectedProductID }) else { return }
        Task { await manager.purchase(product) }
    }

    private func handleRestore() { Task { await manager.restore() } }
}

// MARK: - Plan Card
private struct PlanCard: View {
    let product: Product
    let plan: SubscriptionProductID
    let isSelected: Bool
    let isActivated: Bool
    let userHasActivePlan: Bool
    let cardBg: Color
    let cardBorder: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                (isSelected || isActivated) ? Color.brand : cardBorder,
                                lineWidth: (isSelected || isActivated) ? 2 : 1
                            )
                    )
                    .shadow(
                        color: (isSelected || isActivated)
                            ? Color.brand.opacity(0.2) : Color.black.opacity(0.05),
                        radius: (isSelected || isActivated) ? 6 : 3, y: 2
                    )

                HStack(spacing: 12) {
                    // Radio button
                    ZStack {
                        Circle()
                            .stroke(
                                (isSelected || isActivated) ? Color.brand : Color.gray.opacity(0.4),
                                lineWidth: 2
                            )
                            .frame(width: 22, height: 22)
                        if isSelected || isActivated {
                            Circle().fill(Color.brand).frame(width: 12, height: 12)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(plan.displayName) : \(product.displayPrice)")
                            .font(.system(size: 15, weight: .semibold))
                        Text(plan.tagline)
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }

                    Spacer()

                    // Right badge
                    if isActivated {
                        Text("Activated")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.brand).cornerRadius(18)
                    } else if isSelected {
                        Text(plan.discountBadge)
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.brand).cornerRadius(18)
                    } else {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(plan.discountBadge)
                                .font(.system(size: 13, weight: .bold))
                            Text(plan == .monthly ? "Recommend"
                                 : plan == .weekly ? "Most Popular" : "")
                                .font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)

                // Top-edge badge
                if isActivated {
                    Text("Activated ✓")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.brand).cornerRadius(8)
                        .offset(x: 14, y: -10)
                } else if let badge = plan.badge, !userHasActivePlan {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.brand).cornerRadius(8)
                        .offset(x: 14, y: -10)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Skeleton
private struct PlanCardSkeleton: View {
    let isDark: Bool
    @State private var shimmer = false
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(isDark ? Color(white: 0.2) : Color(.systemFill))
            .frame(height: 62)
            .opacity(shimmer ? 0.4 : 0.8)
            .animation(.easeInOut(duration: 0.9).repeatForever(), value: shimmer)
            .onAppear { shimmer = true }
    }
}

// MARK: - Success View
struct PremiumSuccessView: View {
    let isDark: Bool
    let onContinue: () -> Void

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    @State private var checkOpacity: Double = 0
    @State private var confettiVisible = false

    private var bgColor: Color {
        isDark ? Color(white: 0.08) : Color(red: 0.87, green: 0.95, blue: 0.98)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            if confettiVisible {
                ForEach(0..<24, id: \.self) { i in ConfettiDot(index: i) }
            }
            VStack(spacing: 24) {
                Spacer()
//                ZStack {
//                    Circle().fill(Color.brand.opacity(0.15)).frame(width: 130, height: 130)
//                    Circle().fill(Color.brand.opacity(0.25)).frame(width: 100, height: 100)
//                    Image(systemName: "crown.fill").font(.system(size: 56)).foregroundColor(.brand)
//                }
//                .scaleEffect(scale).opacity(opacity)

                VStack(spacing: 10) {
//                    HStack(spacing: 8) {
//                        Image(systemName: "checkmark.circle.fill")
//                            .font(.system(size: 26)).foregroundColor(.green)
//                        Text("Purchase Successful!").font(.system(size: 22, weight: .bold))
//                    }
                    VStack(spacing: 8) {
                        Image("right")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                        Text("Purchase Successful!").font(.system(size: 22, weight: .bold))
                    }
                    Text("Welcome to Premium!\nAll ads have been removed.")
                        .font(.system(size: 15)).foregroundColor(.secondary)
                        .multilineTextAlignment(.center).lineSpacing(4)
                }
                .opacity(checkOpacity)
                Spacer()

                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                        Text("Go to Home").font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(LinearGradient(colors: [.brand, .brandDark],
                                               startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(25)
                    .shadow(color: Color.brand.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.horizontal, 24).opacity(checkOpacity).padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { scale = 1; opacity = 1 }
            withAnimation(.easeIn(duration: 0.4).delay(0.4)) { checkOpacity = 1 }
            withAnimation(.easeIn(duration: 0.1).delay(0.2)) { confettiVisible = true }
        }
    }
}

// MARK: - Confetti
private struct ConfettiDot: View {
    let index: Int
    @State private var y: CGFloat = 0
    @State private var x: CGFloat = 0
    @State private var opacity: Double = 1
    let colors: [Color] = [.brand, .orange, .yellow, .green, .blue, .purple, .pink]
    var body: some View {
        Circle()
            .fill(colors[index % colors.count])
            .frame(width: CGFloat.random(in: 6...12), height: CGFloat.random(in: 6...12))
            .offset(x: x, y: y).opacity(opacity)
            .onAppear {
                let sx = CGFloat.random(in: -160...160)
                x = sx; y = CGFloat.random(in: -100...100)
                withAnimation(.easeOut(duration: Double.random(in: 1.2...2.0))
                    .delay(Double(index) * 0.04)) {
                    y = CGFloat.random(in: 300...600)
                    x = sx + CGFloat.random(in: -60...60)
                    opacity = 0
                }
            }
    }
}

// MARK: - Premium Icon Button
struct PremiumIconButton: View {
    @ObservedObject private var manager = SubscriptionManager.shared
    @State private var showPremium = false
    var body: some View {
        Button(action: { showPremium = true }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: manager.isPremium ? "crown.fill" : "crown")
                    .font(.system(size: 22))
                    .foregroundColor(manager.isPremium ? .brand : .gray)
                if manager.isPremium {
                    Circle().fill(Color.green).frame(width: 8, height: 8).offset(x: 3, y: -3)
                }
            }
            .padding(.trailing, 4)
        }
        .fullScreenCover(isPresented: $showPremium) { PremiumView() }
    }
}

#Preview { PremiumView() }
