import SwiftUI
import Combine

// MARK: - Shared Converter Ad Manager (singleton for all converter sub-screens)
// All Length, Weight, Temperature, Volume, Area, Speed, Time, Data tabs share
// the same InterstitialAdManager so the ad is preloaded once and reused.
class ConverterAdCoordinator: ObservableObject {
    static let shared = ConverterAdCoordinator()
    let interManager = InterstitialAdManager.converter

    private let cooldownSeconds: TimeInterval = 30
    private var lastAdShownDate: Date? = nil

    private init() {}

    func preload() {
        let rc = RemoteConfigManager.shared
        interManager.updateIDs(
            primaryID: rc.floorInterId,
            fallbackID: rc.converterInterId
        )
        if rc.converterInterAdsFlag != 0 {
            interManager.loadAd()
        }
    }

    func handleBackIfNeeded(dismiss: DismissAction) {
        let rc = RemoteConfigManager.shared

        // Gate 1: flag disabled
        guard rc.converterInterAdsFlag != 0 else { dismiss(); return }

        // Gate 2: cooldown
        if let last = lastAdShownDate,
           Date().timeIntervalSince(last) < cooldownSeconds {
            print("⏳ Converter inter ad on cooldown, skipping")
            dismiss()
            return
        }

        // Gate 3: frequency logic
        guard rc.shouldShowConverterInterAd() else { dismiss(); return }

        // Gate 4: ad ready
        guard interManager.isAdLoaded else {
            print("⚠️ Converter inter ad not loaded yet, skipping")
            dismiss()
            return
        }

        lastAdShownDate = Date()
        interManager.showAdIfReady { dismiss() }
    }

    func resetCooldown() { lastAdShownDate = nil }
}

// MARK: - ConvertersView
struct ConvertersView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    NavigationLink(destination: LengthConverterView()) {
                        ConverterRow(icon: "ruler",            title: "length".localized(localizationManager),      color: .blue)
                    }.listRowBackground(rowBackground)

                    NavigationLink(destination: WeightConverterView()) {
                        ConverterRow(icon: "scalemass",        title: "weight".localized(localizationManager),      color: .green)
                    }.listRowBackground(rowBackground)

                    NavigationLink(destination: TemperatureConverterView()) {
                        ConverterRow(icon: "thermometer",      title: "temperature".localized(localizationManager), color: .orange)
                    }.listRowBackground(rowBackground)

                    NavigationLink(destination: VolumeConverterView()) {
                        ConverterRow(icon: "drop",             title: "volume".localized(localizationManager),      color: .purple)
                    }.listRowBackground(rowBackground)

                    NavigationLink(destination: AreaConverterView()) {
                        ConverterRow(icon: "square.grid.3x3", title: "area".localized(localizationManager),        color: .red)
                    }.listRowBackground(rowBackground)

                    NavigationLink(destination: SpeedConverterView()) {
                        ConverterRow(icon: "speedometer",      title: "speed".localized(localizationManager),       color: .cyan)
                    }.listRowBackground(rowBackground)

                    NavigationLink(destination: TimeConverterView()) {
                        ConverterRow(icon: "clock",            title: "time".localized(localizationManager),        color: .indigo)
                    }.listRowBackground(rowBackground)

                    NavigationLink(destination: DataConverterView()) {
                        ConverterRow(icon: "externaldrive",    title: "data".localized(localizationManager),        color: .pink)
                    }.listRowBackground(rowBackground)
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("converters".localized(localizationManager))
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Preload converter inter ad once for all sub-screens
            ConverterAdCoordinator.shared.preload()
        }
    }

    var backgroundColor: Color {
        themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground)
    }
    var rowBackground: Color {
        themeManager.isDarkMode ? Color(white: 0.1) : .white
    }
}

// MARK: - ConverterRow
struct ConverterRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .cornerRadius(10)
            Text(title)
                .font(.system(size: 18, weight: .medium))
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Base Converter Body Helper
// All converter sub-views share the same layout — only units/title differ.
// Native ad uses converter_screen's native_ads_flag + native_ads_id.
private struct ConverterBody<Content: View>: View {
    let title: String
    @Binding var isKeyboardVisible: Bool
    @ViewBuilder let content: Content

    @ObservedObject private var rc = RemoteConfigManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                content
                
                // Native Ad — from converter_screen remote config
                if !isKeyboardVisible && rc.converterNativeAdsFlag == 1 {
                    if !SubscriptionManager.shared.isPremium {
                    NativeAdViewWrapper(
                        adUnitID: rc.converterNativeAdsId,
                        isKeyboardVisible: $isKeyboardVisible
                    )
                    .frame(width: 320, height: 50)
                    }
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, 30)
        }
        .onTapGesture { hideKeyboard() }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Shared back-button toolbar modifier
private struct ConverterNavModifier: ViewModifier {
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

// MARK: - Length Converter
struct LengthConverterView: View {
    @State private var inputValue = ""
    @State private var fromUnit = 0
    @State private var toUnit = 1
    @State private var isKeyboardVisible = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var units: [String] { [
        "meters".localized(localizationManager), "kilometers".localized(localizationManager),
        "miles".localized(localizationManager),  "feet".localized(localizationManager),
        "inches".localized(localizationManager), "centimeters".localized(localizationManager)
    ]}
    let rates: [Double] = [1, 1000, 1609.34, 0.3048, 0.0254, 0.01]

    var result: String {
        guard let v = Double(inputValue) else { return "0" }
        return String(format: "%.4f", v * rates[fromUnit] / rates[toUnit])
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ConverterBody(title: "length".localized(localizationManager), isKeyboardVisible: $isKeyboardVisible) {
                converterContent
            }
        }
        .modifier(ConverterNavModifier(title: "length".localized(localizationManager)) { handleBack() })
        .onKeyboardChange { isKeyboardVisible = $0 }
    }

    private var converterContent: some View {
        Group {
            pickerRow(label: "from".localized(localizationManager), value: $inputValue, unit: $fromUnit, isInput: true)
            swapButton
            resultRow(label: "to".localized(localizationManager), result: result, unit: $toUnit)
        }
    }

    private func handleBack() {
        ConverterAdCoordinator.shared.handleBackIfNeeded(dismiss: dismiss)
    }
    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var cardBackground: Color  { themeManager.isDarkMode ? Color(white: 0.15) : .white }

    private func pickerRow(label: String, value: Binding<String>, unit: Binding<Int>, isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.headline).foregroundColor(.secondary)
            HStack {
                if isInput {
                    TextField("enter.value".localized(localizationManager), text: value)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .semibold))
                        .padding().background(cardBackground).cornerRadius(12)
                }
                Picker("", selection: unit) {
                    ForEach(0..<units.count, id: \.self) { Text(units[$0]).tag($0) }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 100).padding().background(cardBackground).cornerRadius(12)
            }
        }.padding(.horizontal)
    }

    private func resultRow(label: String, result: String, unit: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.headline).foregroundColor(.secondary)
            HStack {
                Text(result)
                    .font(.system(size: 32, weight: .semibold))
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBackground).cornerRadius(12)
                Picker("", selection: unit) {
                    ForEach(0..<units.count, id: \.self) { Text(units[$0]).tag($0) }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 100).padding().background(cardBackground).cornerRadius(12)
            }
        }.padding(.horizontal)
    }

    private var swapButton: some View {
        Button { withAnimation { swap(&fromUnit, &toUnit) } } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                .frame(width: 60, height: 60).background(Color.orange).clipShape(Circle())
        }
    }
}

// MARK: - Weight Converter
struct WeightConverterView: View {
    @State private var inputValue = ""
    @State private var fromUnit = 0
    @State private var toUnit = 1
    @State private var isKeyboardVisible = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var units: [String] { [
        "kilograms".localized(localizationManager), "grams".localized(localizationManager),
        "pounds".localized(localizationManager),    "ounces".localized(localizationManager),
        "tons".localized(localizationManager)
    ]}
    let rates: [Double] = [1, 0.001, 0.453592, 0.0283495, 1000]
    var result: String {
        guard let v = Double(inputValue) else { return "0" }
        return String(format: "%.4f", v * rates[fromUnit] / rates[toUnit])
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ConverterBody(title: "weight".localized(localizationManager), isKeyboardVisible: $isKeyboardVisible) {
                converterFields
            }
        }
        .modifier(ConverterNavModifier(title: "weight".localized(localizationManager)) { handleBack() })
        .onKeyboardChange { isKeyboardVisible = $0 }
    }

    private var converterFields: some View {
        Group {
            unitRow(label: "from".localized(localizationManager), value: $inputValue, unit: $fromUnit, isInput: true)
            swapBtn
            unitRow(label: "to".localized(localizationManager), displayValue: result, unit: $toUnit, isInput: false)
        }
    }

    private func handleBack() { ConverterAdCoordinator.shared.handleBackIfNeeded(dismiss: dismiss) }
    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var cardBackground: Color  { themeManager.isDarkMode ? Color(white: 0.15) : .white }

    @ViewBuilder
    private func unitRow(label: String, value: Binding<String>? = nil, displayValue: String = "", unit: Binding<Int>, isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.headline).foregroundColor(.secondary)
            HStack {
                if isInput, let value = value {
                    TextField("enter.value".localized(localizationManager), text: value)
                        .keyboardType(.decimalPad).font(.system(size: 32, weight: .semibold))
                        .padding().background(cardBackground).cornerRadius(12)
                } else {
                    Text(displayValue).font(.system(size: 32, weight: .semibold))
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBackground).cornerRadius(12)
                }
                Picker("", selection: unit) {
                    ForEach(0..<units.count, id: \.self) { Text(units[$0]).tag($0) }
                }
                .pickerStyle(MenuPickerStyle()).frame(width: 100)
                .padding().background(cardBackground).cornerRadius(12)
            }
        }.padding(.horizontal)
    }

    private var swapBtn: some View {
        Button { withAnimation { swap(&fromUnit, &toUnit) } } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                .frame(width: 60, height: 60).background(Color.orange).clipShape(Circle())
        }
    }
}

// MARK: - Temperature Converter
struct TemperatureConverterView: View {
    @State private var inputValue = ""
    @State private var fromUnit = 0
    @State private var toUnit = 1
    @State private var isKeyboardVisible = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var units: [String] { [
        "celsius".localized(localizationManager),
        "fahrenheit".localized(localizationManager),
        "kelvin".localized(localizationManager)
    ]}

    var result: String {
        guard let v = Double(inputValue) else { return "0" }
        let c: Double
        switch fromUnit {
        case 1: c = (v - 32) * 5 / 9
        case 2: c = v - 273.15
        default: c = v
        }
        let r: Double
        switch toUnit {
        case 1: r = c * 9 / 5 + 32
        case 2: r = c + 273.15
        default: r = c
        }
        return String(format: "%.2f", r)
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ConverterBody(title: "temperature".localized(localizationManager), isKeyboardVisible: $isKeyboardVisible) {
                converterFields
            }
        }
        .modifier(ConverterNavModifier(title: "temperature".localized(localizationManager)) { handleBack() })
        .onKeyboardChange { isKeyboardVisible = $0 }
    }

    private var converterFields: some View {
        Group {
            unitRow(label: "from".localized(localizationManager), value: $inputValue, unit: $fromUnit, isInput: true)
            swapBtn
            unitRow(label: "to".localized(localizationManager), displayValue: result, unit: $toUnit, isInput: false)
        }
    }

    private func handleBack() { ConverterAdCoordinator.shared.handleBackIfNeeded(dismiss: dismiss) }
    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var cardBackground: Color  { themeManager.isDarkMode ? Color(white: 0.15) : .white }

    @ViewBuilder
    private func unitRow(label: String, value: Binding<String>? = nil, displayValue: String = "", unit: Binding<Int>, isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.headline).foregroundColor(.secondary)
            HStack {
                if isInput, let value = value {
                    TextField("enter.value".localized(localizationManager), text: value)
                        .keyboardType(.decimalPad).font(.system(size: 32, weight: .semibold))
                        .padding().background(cardBackground).cornerRadius(12)
                } else {
                    Text(displayValue).font(.system(size: 32, weight: .semibold))
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBackground).cornerRadius(12)
                }
                Picker("", selection: unit) {
                    ForEach(0..<units.count, id: \.self) { Text(units[$0]).tag($0) }
                }
                .pickerStyle(MenuPickerStyle()).frame(width: 120)
                .padding().background(cardBackground).cornerRadius(12)
            }
        }.padding(.horizontal)
    }

    private var swapBtn: some View {
        Button { withAnimation { swap(&fromUnit, &toUnit) } } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                .frame(width: 60, height: 60).background(Color.orange).clipShape(Circle())
        }
    }
}

// MARK: - Volume Converter
struct VolumeConverterView: View {
    @State private var inputValue = ""
    @State private var fromUnit = 0
    @State private var toUnit = 1
    @State private var isKeyboardVisible = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var units: [String] { [
        "liters".localized(localizationManager),      "milliliters".localized(localizationManager),
        "gallons".localized(localizationManager),     "cups".localized(localizationManager),
        "pints".localized(localizationManager)
    ]}
    let rates: [Double] = [1, 0.001, 3.78541, 0.236588, 0.473176]
    var result: String {
        guard let v = Double(inputValue) else { return "0" }
        return String(format: "%.4f", v * rates[fromUnit] / rates[toUnit])
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ConverterBody(title: "volume".localized(localizationManager), isKeyboardVisible: $isKeyboardVisible) {
                converterFields
            }
        }
        .modifier(ConverterNavModifier(title: "volume".localized(localizationManager)) { handleBack() })
        .onKeyboardChange { isKeyboardVisible = $0 }
    }

    private var converterFields: some View {
        Group {
            unitRow(label: "from".localized(localizationManager), value: $inputValue, unit: $fromUnit, isInput: true)
            swapBtn
            unitRow(label: "to".localized(localizationManager), displayValue: result, unit: $toUnit, isInput: false)
        }
    }

    private func handleBack() { ConverterAdCoordinator.shared.handleBackIfNeeded(dismiss: dismiss) }
    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var cardBackground: Color  { themeManager.isDarkMode ? Color(white: 0.15) : .white }

    @ViewBuilder
    private func unitRow(label: String, value: Binding<String>? = nil, displayValue: String = "", unit: Binding<Int>, isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.headline).foregroundColor(.secondary)
            HStack {
                if isInput, let value = value {
                    TextField("enter.value".localized(localizationManager), text: value)
                        .keyboardType(.decimalPad).font(.system(size: 32, weight: .semibold))
                        .padding().background(cardBackground).cornerRadius(12)
                } else {
                    Text(displayValue).font(.system(size: 32, weight: .semibold))
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBackground).cornerRadius(12)
                }
                Picker("", selection: unit) {
                    ForEach(0..<units.count, id: \.self) { Text(units[$0]).tag($0) }
                }
                .pickerStyle(MenuPickerStyle()).frame(width: 100)
                .padding().background(cardBackground).cornerRadius(12)
            }
        }.padding(.horizontal)
    }

    private var swapBtn: some View {
        Button { withAnimation { swap(&fromUnit, &toUnit) } } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                .frame(width: 60, height: 60).background(Color.orange).clipShape(Circle())
        }
    }
}

// MARK: - Area Converter
struct AreaConverterView: View {
    @State private var inputValue = ""
    @State private var fromUnit = 0
    @State private var toUnit = 1
    @State private var isKeyboardVisible = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var units: [String] { [
        "sqmeters".localized(localizationManager), "sqkm".localized(localizationManager),
        "sqmiles".localized(localizationManager),  "sqfeet".localized(localizationManager),
        "acres".localized(localizationManager)
    ]}
    let rates: [Double] = [1, 1_000_000, 2_589_988.11, 0.092903, 4046.86]
    var result: String {
        guard let v = Double(inputValue) else { return "0" }
        return String(format: "%.4f", v * rates[fromUnit] / rates[toUnit])
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ConverterBody(title: "area".localized(localizationManager), isKeyboardVisible: $isKeyboardVisible) {
                converterFields
            }
        }
        .modifier(ConverterNavModifier(title: "area".localized(localizationManager)) { handleBack() })
        .onKeyboardChange { isKeyboardVisible = $0 }
    }

    private var converterFields: some View {
        Group {
            unitRow(label: "from".localized(localizationManager), value: $inputValue, unit: $fromUnit, isInput: true)
            swapBtn
            unitRow(label: "to".localized(localizationManager), displayValue: result, unit: $toUnit, isInput: false)
        }
    }

    private func handleBack() { ConverterAdCoordinator.shared.handleBackIfNeeded(dismiss: dismiss) }
    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var cardBackground: Color  { themeManager.isDarkMode ? Color(white: 0.15) : .white }

    @ViewBuilder
    private func unitRow(label: String, value: Binding<String>? = nil, displayValue: String = "", unit: Binding<Int>, isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.headline).foregroundColor(.secondary)
            HStack {
                if isInput, let value = value {
                    TextField("enter.value".localized(localizationManager), text: value)
                        .keyboardType(.decimalPad).font(.system(size: 32, weight: .semibold))
                        .padding().background(cardBackground).cornerRadius(12)
                } else {
                    Text(displayValue).font(.system(size: 32, weight: .semibold))
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBackground).cornerRadius(12)
                }
                Picker("", selection: unit) {
                    ForEach(0..<units.count, id: \.self) { Text(units[$0]).tag($0) }
                }
                .pickerStyle(MenuPickerStyle()).frame(width: 100)
                .padding().background(cardBackground).cornerRadius(12)
            }
        }.padding(.horizontal)
    }

    private var swapBtn: some View {
        Button { withAnimation { swap(&fromUnit, &toUnit) } } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                .frame(width: 60, height: 60).background(Color.orange).clipShape(Circle())
        }
    }
}

// MARK: - Speed Converter
struct SpeedConverterView: View {
    @State private var inputValue = ""
    @State private var fromUnit = 0
    @State private var toUnit = 1
    @State private var isKeyboardVisible = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var units: [String] { [
        "m/s".localized(localizationManager),   "km/h".localized(localizationManager),
        "mph".localized(localizationManager),   "knots".localized(localizationManager)
    ]}
    let rates: [Double] = [1, 0.277778, 0.44704, 0.514444]
    var result: String {
        guard let v = Double(inputValue) else { return "0" }
        return String(format: "%.4f", v * rates[fromUnit] / rates[toUnit])
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ConverterBody(title: "speed".localized(localizationManager), isKeyboardVisible: $isKeyboardVisible) {
                converterFields
            }
        }
        .modifier(ConverterNavModifier(title: "speed".localized(localizationManager)) { handleBack() })
        .onKeyboardChange { isKeyboardVisible = $0 }
    }

    private var converterFields: some View {
        Group {
            unitRow(label: "from".localized(localizationManager), value: $inputValue, unit: $fromUnit, isInput: true)
            swapBtn
            unitRow(label: "to".localized(localizationManager), displayValue: result, unit: $toUnit, isInput: false)
        }
    }

    private func handleBack() { ConverterAdCoordinator.shared.handleBackIfNeeded(dismiss: dismiss) }
    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var cardBackground: Color  { themeManager.isDarkMode ? Color(white: 0.15) : .white }

    @ViewBuilder
    private func unitRow(label: String, value: Binding<String>? = nil, displayValue: String = "", unit: Binding<Int>, isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.headline).foregroundColor(.secondary)
            HStack {
                if isInput, let value = value {
                    TextField("enter.value".localized(localizationManager), text: value)
                        .keyboardType(.decimalPad).font(.system(size: 32, weight: .semibold))
                        .padding().background(cardBackground).cornerRadius(12)
                } else {
                    Text(displayValue).font(.system(size: 32, weight: .semibold))
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBackground).cornerRadius(12)
                }
                Picker("", selection: unit) {
                    ForEach(0..<units.count, id: \.self) { Text(units[$0]).tag($0) }
                }
                .pickerStyle(MenuPickerStyle()).frame(width: 100)
                .padding().background(cardBackground).cornerRadius(12)
            }
        }.padding(.horizontal)
    }

    private var swapBtn: some View {
        Button { withAnimation { swap(&fromUnit, &toUnit) } } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                .frame(width: 60, height: 60).background(Color.orange).clipShape(Circle())
        }
    }
}

// MARK: - Time Converter
struct TimeConverterView: View {
    @State private var inputValue = ""
    @State private var fromUnit = 0
    @State private var toUnit = 1
    @State private var isKeyboardVisible = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var units: [String] { [
        "seconds".localized(localizationManager), "minutes".localized(localizationManager),
        "hours".localized(localizationManager),   "days".localized(localizationManager),
        "weeks".localized(localizationManager)
    ]}
    let rates: [Double] = [1, 60, 3600, 86400, 604800]
    var result: String {
        guard let v = Double(inputValue) else { return "0" }
        return String(format: "%.4f", v * rates[fromUnit] / rates[toUnit])
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ConverterBody(title: "time".localized(localizationManager), isKeyboardVisible: $isKeyboardVisible) {
                converterFields
            }
        }
        .modifier(ConverterNavModifier(title: "time".localized(localizationManager)) { handleBack() })
        .onKeyboardChange { isKeyboardVisible = $0 }
    }

    private var converterFields: some View {
        Group {
            unitRow(label: "from".localized(localizationManager), value: $inputValue, unit: $fromUnit, isInput: true)
            swapBtn
            unitRow(label: "to".localized(localizationManager), displayValue: result, unit: $toUnit, isInput: false)
        }
    }

    private func handleBack() { ConverterAdCoordinator.shared.handleBackIfNeeded(dismiss: dismiss) }
    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var cardBackground: Color  { themeManager.isDarkMode ? Color(white: 0.15) : .white }

    @ViewBuilder
    private func unitRow(label: String, value: Binding<String>? = nil, displayValue: String = "", unit: Binding<Int>, isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.headline).foregroundColor(.secondary)
            HStack {
                if isInput, let value = value {
                    TextField("enter.value".localized(localizationManager), text: value)
                        .keyboardType(.decimalPad).font(.system(size: 32, weight: .semibold))
                        .padding().background(cardBackground).cornerRadius(12)
                } else {
                    Text(displayValue).font(.system(size: 32, weight: .semibold))
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBackground).cornerRadius(12)
                }
                Picker("", selection: unit) {
                    ForEach(0..<units.count, id: \.self) { Text(units[$0]).tag($0) }
                }
                .pickerStyle(MenuPickerStyle()).frame(width: 100)
                .padding().background(cardBackground).cornerRadius(12)
            }
        }.padding(.horizontal)
    }

    private var swapBtn: some View {
        Button { withAnimation { swap(&fromUnit, &toUnit) } } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                .frame(width: 60, height: 60).background(Color.orange).clipShape(Circle())
        }
    }
}

// MARK: - Data Converter
struct DataConverterView: View {
    @State private var inputValue = ""
    @State private var fromUnit = 0
    @State private var toUnit = 1
    @State private var isKeyboardVisible = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var units: [String] { [
        "bytes".localized(localizationManager), "kb".localized(localizationManager),
        "mb".localized(localizationManager),    "gb".localized(localizationManager),
        "tb".localized(localizationManager)
    ]}
    let rates: [Double] = [1, 1024, 1_048_576, 1_073_741_824, 1_099_511_627_776]
    var result: String {
        guard let v = Double(inputValue) else { return "0" }
        return String(format: "%.4f", v * rates[fromUnit] / rates[toUnit])
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ConverterBody(title: "data.storage".localized(localizationManager), isKeyboardVisible: $isKeyboardVisible) {
                converterFields
            }
        }
        .modifier(ConverterNavModifier(title: "data.storage".localized(localizationManager)) { handleBack() })
        .onKeyboardChange { isKeyboardVisible = $0 }
    }

    private var converterFields: some View {
        Group {
            unitRow(label: "from".localized(localizationManager), value: $inputValue, unit: $fromUnit, isInput: true)
            swapBtn
            unitRow(label: "to".localized(localizationManager), displayValue: result, unit: $toUnit, isInput: false)
        }
    }

    private func handleBack() { ConverterAdCoordinator.shared.handleBackIfNeeded(dismiss: dismiss) }
    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var cardBackground: Color  { themeManager.isDarkMode ? Color(white: 0.15) : .white }

    @ViewBuilder
    private func unitRow(label: String, value: Binding<String>? = nil, displayValue: String = "", unit: Binding<Int>, isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.headline).foregroundColor(.secondary)
            HStack {
                if isInput, let value = value {
                    TextField("enter.value".localized(localizationManager), text: value)
                        .keyboardType(.decimalPad).font(.system(size: 32, weight: .semibold))
                        .padding().background(cardBackground).cornerRadius(12)
                } else {
                    Text(displayValue).font(.system(size: 32, weight: .semibold))
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBackground).cornerRadius(12)
                }
                Picker("", selection: unit) {
                    ForEach(0..<units.count, id: \.self) { Text(units[$0]).tag($0) }
                }
                .pickerStyle(MenuPickerStyle()).frame(width: 100)
                .padding().background(cardBackground).cornerRadius(12)
            }
        }.padding(.horizontal)
    }

    private var swapBtn: some View {
        Button { withAnimation { swap(&fromUnit, &toUnit) } } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                .frame(width: 60, height: 60).background(Color.orange).clipShape(Circle())
        }
    }
}

#Preview {
    ConvertersView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
}
