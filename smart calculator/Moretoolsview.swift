import SwiftUI
import Combine

// MARK: - More Screen Ad Coordinator
class MoreAdCoordinator: ObservableObject {
    static let shared = MoreAdCoordinator()
    let interManager = InterstitialAdManager.more

    private let cooldownSeconds: TimeInterval = 30
    private var lastAdShownDate: Date? = nil
    private init() {}

    func preload() {
        let rc = RemoteConfigManager.shared
        interManager.updateIDs(
            primaryID: rc.floorInterId,
            fallbackID: rc.moreInterId
        )
        if rc.moreInterAdsFlag != 0 {
            interManager.loadAd()
        }
    }

    func handleBack(screenType: SeparateMoreScreenType, dismiss: DismissAction) {
        let rc = RemoteConfigManager.shared

        let separateFlag = rc.shouldShowSeparateMoreInterAd(for: screenType)
        print("🔍 [More Ad] Gate1 separate_more[\(screenType)] = \(separateFlag ? "PASS (flag=1)" : "BLOCK (flag=0)")")
        guard separateFlag else { dismiss(); return }

        print("🔍 [More Ad] Gate2 moreInterAdsFlag = \(rc.moreInterAdsFlag)")
        guard rc.moreInterAdsFlag != 0 else { dismiss(); return }

        if let last = lastAdShownDate {
            let elapsed = Date().timeIntervalSince(last)
            print("🔍 [More Ad] Gate3 cooldown elapsed=\(Int(elapsed))s / \(Int(cooldownSeconds))s")
            if elapsed < cooldownSeconds {
                print("⏳ More inter ad on cooldown, skipping")
                dismiss()
                return
            }
        }

        let freqCheck = rc.shouldShowMoreInterAd()
        print("🔍 [More Ad] Gate4 frequency check = \(freqCheck ? "PASS" : "BLOCK")")
        guard freqCheck else { dismiss(); return }

        print("🔍 [More Ad] Gate5 isAdLoaded = \(interManager.isAdLoaded)")
        guard interManager.isAdLoaded else {
            print("⚠️ More inter ad not loaded yet, skipping")
            dismiss()
            return
        }

        print("✅ [More Ad] All gates passed — showing ad")
        lastAdShownDate = Date()
        interManager.showAdIfReady { dismiss() }
    }

    func resetCooldown() {
        lastAdShownDate = nil
    }
}

// MARK: - MoreToolsView
struct MoreToolsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var currencyManager: CurrencyManager
    @State private var showCurrencyPicker = false

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                List {
                    Section {
                        Button(action: { showCurrencyPicker = true }) {
                            HStack(spacing: 15) {
                                Image(currencyManager.selectedCurrency.flagImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("currency".localized(localizationManager))
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Text(currencyManager.selectedCurrency.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(rowBackground)

                        NavigationLink(destination: TipCalculatorView()) {
                            ToolRow(icon: "dollarsign.circle.fill",
                                    title: "tip.calculator".localized(localizationManager),
                                    color: .green)
                        }.listRowBackground(rowBackground)

                        NavigationLink(destination: AgeCalculatorView()) {
                            ToolRow(icon: "calendar.circle.fill",
                                    title: "age.calculator".localized(localizationManager),
                                    color: .blue)
                        }.listRowBackground(rowBackground)

                        NavigationLink(destination: DiscountCalculatorView()) {
                            ToolRow(icon: "heart.circle.fill",
                                    title: "discount.calculator".localized(localizationManager),
                                    color: .orange)
                        }.listRowBackground(rowBackground)

                        // ← LoanCalculatorView is defined in LoanPDFFeature.swift
                        NavigationLink(destination: LoanCalculatorView()) {
                            ToolRow(icon: "banknote.fill",
                                    title: "loan.calculator".localized(localizationManager),
                                    color: .purple)
                        }.listRowBackground(rowBackground)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("moretools".localized(localizationManager))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView()
                    .environmentObject(currencyManager)
                    .environmentObject(themeManager)
            }
        }
        .onAppear {
            MoreAdCoordinator.shared.preload()
        }
    }

    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var rowBackground: Color   { themeManager.isDarkMode ? Color(white: 0.1) : .white }
}

// MARK: - ToolRow
struct ToolRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 18, weight: .medium))
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Shared More Screen Nav Modifier
struct MoreNavModifier: ViewModifier {
    let title: String
    let onBack: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).font(.system(size: 20, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left").foregroundColor(.primary)
                    }
                }
            }
    }
}

// MARK: - More Native Ad View
struct MoreNativeAd: View {
    @Binding var isKeyboardVisible: Bool
    @ObservedObject private var rc = RemoteConfigManager.shared

    var body: some View {
        if !isKeyboardVisible && rc.moreNativeAdsFlag == 1 {
            if !SubscriptionManager.shared.isPremium {
                NativeAdViewWrapper(
                    adUnitID: rc.moreNativeAdsId,
                    isKeyboardVisible: $isKeyboardVisible
                )
                .frame(width: 320, height: 50)
            }
        }
    }
}

// MARK: - Tip Calculator
struct TipCalculatorView: View {
    @State private var billAmount = ""
    @State private var tipPercentage = 15.0
    @State private var numberOfPeople = 1
    @State private var isKeyboardVisible = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var currencyManager: CurrencyManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var tipAmount:   Double { (Double(billAmount) ?? 0) * tipPercentage / 100 }
    var totalAmount: Double { (Double(billAmount) ?? 0) + tipAmount }
    var perPerson:   Double { totalAmount / Double(numberOfPeople) }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 25) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("bill.amount".localized(localizationManager))
                            .font(.headline).foregroundColor(.secondary)
                        HStack {
                            Text(currencyManager.selectedCurrency.symbol)
                                .font(.system(size: 28, weight: .semibold))
                            TextField("0.00", text: $billAmount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 32, weight: .semibold))
                        }
                        .padding().background(cardBackground).cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("tip.percentage".localized(localizationManager))
                                .font(.headline).foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(tipPercentage))%")
                                .font(.title2).fontWeight(.bold).foregroundColor(.orange)
                        }
                        Slider(value: $tipPercentage, in: 0...50, step: 1).accentColor(.orange)
                        HStack {
                            ForEach([10, 15, 18, 20], id: \.self) { pct in
                                Button { tipPercentage = Double(pct) } label: {
                                    Text("\(pct)%")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(tipPercentage == Double(pct) ? .white : .orange)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(tipPercentage == Double(pct) ? Color.orange : cardBackground)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                    .padding().background(cardBackground).cornerRadius(12)

                    MoreNativeAd(isKeyboardVisible: $isKeyboardVisible)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("split.between".localized(localizationManager))
                            .font(.headline).foregroundColor(.secondary)
                        Stepper(value: $numberOfPeople, in: 1...20) {
                            HStack {
                                Image(systemName: "person.2.fill").foregroundColor(.orange)
                                let label = numberOfPeople == 1
                                    ? "person".localized(localizationManager)
                                    : "people".localized(localizationManager)
                                Text("\(numberOfPeople) \(label)")
                                    .font(.title3).fontWeight(.semibold)
                            }
                        }
                        .padding().background(cardBackground).cornerRadius(12)
                    }

                    VStack(spacing: 15) {
                        CurrencyResultRow(title: "tip.amount".localized(localizationManager),
                                          amount: tipAmount,
                                          currency: currencyManager.selectedCurrency.symbol,
                                          color: .orange)
                        CurrencyResultRow(title: "total.amount".localized(localizationManager),
                                          amount: totalAmount,
                                          currency: currencyManager.selectedCurrency.symbol,
                                          color: .green)
                        CurrencyResultRow(title: "per.person".localized(localizationManager),
                                          amount: perPerson,
                                          currency: currencyManager.selectedCurrency.symbol,
                                          color: .blue)
                    }
                    .padding().background(cardBackground).cornerRadius(12)

                    Spacer().frame(height: 100)
                }
                .padding()
            }
            .onTapGesture { hideKeyboard() }
        }
        .modifier(MoreNavModifier(title: "tip.calculator".localized(localizationManager)) {
            MoreAdCoordinator.shared.handleBack(screenType: .tip, dismiss: dismiss)
        })
        .onKeyboardChange { isKeyboardVisible = $0 }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var cardBackground:  Color { themeManager.isDarkMode ? Color(white: 0.15) : .white }
}

// MARK: - Age Calculator
struct AgeCalculatorView: View {
    @State private var birthDate = Date()
    @State private var isKeyboardVisible = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var ageComponents: DateComponents {
        Calendar.current.dateComponents([.year, .month, .day], from: birthDate, to: Date())
    }
    var totalDays:   Int { Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0 }
    var totalWeeks:  Int { totalDays / 7 }
    var totalMonths: Int { (ageComponents.year ?? 0) * 12 + (ageComponents.month ?? 0) }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 25) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("select.dob".localized(localizationManager))
                            .font(.headline).foregroundColor(.secondary)
                        DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .padding().background(cardBackground).cornerRadius(12)
                    }

                    MoreNativeAd(isKeyboardVisible: $isKeyboardVisible)

                    VStack(spacing: 20) {
                        HStack(spacing: 20) {
                            AgeBox(value: "\(ageComponents.year ?? 0)",
                                   label: "years".localized(localizationManager),
                                   color: .blue)
                            AgeBox(value: "\(ageComponents.month ?? 0)",
                                   label: "months".localized(localizationManager),
                                   color: .green)
                            AgeBox(value: "\(ageComponents.day ?? 0)",
                                   label: "days".localized(localizationManager),
                                   color: .orange)
                        }
                        VStack(spacing: 12) {
                            InfoRow(icon: "calendar",
                                    title: "total.months".localized(localizationManager),
                                    value: "\(totalMonths)", color: .purple)
                            InfoRow(icon: "calendar.circle",
                                    title: "total.weeks".localized(localizationManager),
                                    value: "\(totalWeeks)", color: .pink)
                            InfoRow(icon: "sun.max",
                                    title: "total.days".localized(localizationManager),
                                    value: "\(totalDays)", color: .red)
                        }
                        .padding().background(cardBackground).cornerRadius(12)
                    }

                    Spacer().frame(height: 100)
                }
                .padding()
            }
        }
        .modifier(MoreNavModifier(title: "age.calculator".localized(localizationManager)) {
            MoreAdCoordinator.shared.handleBack(screenType: .age, dismiss: dismiss)
        })
        .onKeyboardChange { isKeyboardVisible = $0 }
    }

    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var cardBackground:  Color { themeManager.isDarkMode ? Color(white: 0.15) : .white }
}

// MARK: - Discount Calculator
struct DiscountCalculatorView: View {
    @State private var originalPrice = ""
    @State private var discountPercent = 20.0
    @State private var isKeyboardVisible = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var currencyManager: CurrencyManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var discountAmount: Double { (Double(originalPrice) ?? 0) * discountPercent / 100 }
    var finalPrice:     Double { (Double(originalPrice) ?? 0) - discountAmount }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 25) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("original.price".localized(localizationManager))
                            .font(.headline).foregroundColor(.secondary)
                        HStack {
                            Text(currencyManager.selectedCurrency.symbol)
                                .font(.system(size: 28, weight: .semibold))
                            TextField("0.00", text: $originalPrice)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 32, weight: .semibold))
                        }
                        .padding().background(cardBackground).cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("discount".localized(localizationManager))
                                .font(.headline).foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(discountPercent))%")
                                .font(.title2).fontWeight(.bold).foregroundColor(.orange)
                        }
                        Slider(value: $discountPercent, in: 0...100, step: 1).accentColor(.orange)
                    }
                    .padding().background(cardBackground).cornerRadius(12)

                    MoreNativeAd(isKeyboardVisible: $isKeyboardVisible)

                    VStack(spacing: 15) {
                        CurrencyResultRow(title: "discount.amount".localized(localizationManager),
                                          amount: discountAmount,
                                          currency: currencyManager.selectedCurrency.symbol,
                                          color: .orange)
                        Divider()
                        CurrencyResultRow(title: "final.price".localized(localizationManager),
                                          amount: finalPrice,
                                          currency: currencyManager.selectedCurrency.symbol,
                                          color: .green)
                    }
                    .padding().background(cardBackground).cornerRadius(12)

                    Spacer().frame(height: 100)
                }
                .padding()
            }
            .onTapGesture { hideKeyboard() }
        }
        .modifier(MoreNavModifier(title: "discount.calculator".localized(localizationManager)) {
            MoreAdCoordinator.shared.handleBack(screenType: .discount, dismiss: dismiss)
        })
        .onKeyboardChange { isKeyboardVisible = $0 }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var cardBackground:  Color { themeManager.isDarkMode ? Color(white: 0.15) : .white }
}

// MARK: - Shared Result / Info Components
struct CurrencyResultRow: View {
    let title: String
    let amount: Double
    let currency: String
    let color: Color

    var body: some View {
        HStack {
            Text(title).font(.headline).foregroundColor(.secondary)
            Spacer()
            Text("\(currency)\(amount, specifier: "%.2f")")
                .font(.title2).fontWeight(.bold).foregroundColor(color)
        }
        .padding(.vertical, 8)
    }
}

struct AgeBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value).font(.system(size: 36, weight: .bold)).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).font(.title3)
            Text(title).font(.headline)
            Spacer()
            Text(value).font(.title3).fontWeight(.bold).foregroundColor(color)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var rc = RemoteConfigManager.shared

    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle(isOn: $themeManager.isDarkMode) {
                        HStack {
                            Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                                .foregroundColor(.orange)
                            Text("Dark Mode")
                        }
                    }
                }

                if rc.shouldShowSettingBanner {
                    BannerAdContainer(screen: .setting).padding(.top, 8)
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("MegaCalc - Calculator").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    MoreToolsView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
        .environmentObject(CurrencyManager())
}
