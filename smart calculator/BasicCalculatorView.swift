import SwiftUI
import Combine

struct BasicCalculatorView: View {
    @StateObject private var calculator = CalculatorBrain()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var calculationHistory: CalculationHistory

    // ✅ KEY FIX: @ObservedObject lagaya taaki isPremium change hote hi view update ho
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var showSettings = false
    @State private var showPremium = false

    let buttons: [[CalculatorButton]] = [
        [.clear, .negative, .percent, .divide],
        [.seven, .eight, .nine, .multiply],
        [.four, .five, .six, .subtract],
        [.one, .two, .three, .add],
        [.zero, .decimal, .equals]
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 8) {
                    Spacer()

                    // Display
                    VStack(alignment: .trailing, spacing: 4) {
                        if !calculator.previousValue.isEmpty {
                            Text(calculator.previousValue)
                                .font(.system(size: displayFontSize(for: geometry, isPrevious: true), weight: .light))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        Text(calculator.display)
                            .font(.system(size: displayFontSize(for: geometry, isPrevious: false), weight: .light))
                            .foregroundColor(displayColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, horizontalPadding(for: geometry))
                    .padding(.vertical, 8)

                    // Buttons
                    VStack(spacing: buttonSpacing(for: geometry)) {
                        ForEach(buttons, id: \.self) { row in
                            HStack(spacing: buttonSpacing(for: geometry)) {
                                ForEach(row, id: \.self) { button in
                                    CalculatorButtonView(button: button, geometry: geometry) {
                                        self.calculator.buttonTapped(button, history: calculationHistory)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding(for: geometry))
                    .padding(.bottom, bottomPadding(for: geometry))

                    // ✅ AD GATING: Premium users ko ads nahi dikhegi
                    if subscriptionManager.shouldShowAds {
                        BannerAdPlaceholderView()
                    }
                }

                // Top-right icons
                VStack {
                    HStack {
                        Spacer()

                        Button(action: { showPremium = true }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: subscriptionManager.isPremium ? "crown.fill" : "crown")
                                    .font(.system(size: 22))
                                    .foregroundColor(subscriptionManager.isPremium ? .yellow : .gray)
                                if subscriptionManager.isPremium {
                                    Circle().fill(Color.green).frame(width: 8, height: 8).offset(x: 3, y: -3)
                                }
                            }
                            .padding(.trailing, 4).padding(.top, 2)
                        }

                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    Spacer()
                }
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            NavigationView {
                AppSettingsView().environmentObject(themeManager)
            }
        }
        .fullScreenCover(isPresented: $showPremium) {
            PremiumView()
        }
    }

    var backgroundColor: Color {
        themeManager.isDarkMode ? Color.black : Color(UIColor.systemGroupedBackground)
    }

    var displayColor: Color {
        themeManager.isDarkMode ? .white : .black
    }

    private func displayFontSize(for geometry: GeometryProxy, isPrevious: Bool) -> CGFloat {
        let base = isPrevious ? 24.0 : 64.0
        return geometry.size.width > 600 ? base * 1.3 : base
    }

    private func horizontalPadding(for geometry: GeometryProxy) -> CGFloat {
        geometry.size.width > 600 ? 60 : 24
    }

    private func buttonSpacing(for geometry: GeometryProxy) -> CGFloat {
        geometry.size.width > 600 ? 16 : 12
    }

    private func bottomPadding(for geometry: GeometryProxy) -> CGFloat {
        geometry.size.width > 600 ? 40 : 12
    }
}

// MARK: - Banner Ad Placeholder
// ✅ Yahan apna actual AdMob BannerView replace karein
struct BannerAdPlaceholderView: View {
    var body: some View {
        // Replace with: BannerView(adUnitID: RemoteConfigManager.shared.mainBanerId)
//        Color.gray.opacity(0.1)
//            .frame(maxWidth: .infinity)
//            .frame(height: 50)
//            .overlay(Text("Ad").font(.caption).foregroundColor(.secondary))
    }
}

// MARK: - CalculatorButtonView
struct CalculatorButtonView: View {
    let button: CalculatorButton
    let geometry: GeometryProxy
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Text(button.title)
                .font(.system(size: fontSize, weight: .medium))
                .frame(width: buttonWidth, height: buttonSize)
                .background(buttonBackgroundColor)
                .foregroundColor(buttonForegroundColor)
                .cornerRadius(buttonSize / 2)
        }
    }

    private var isIPad: Bool { geometry.size.width > 600 }
    private var spacing: CGFloat { isIPad ? 16 : 12 }
    private var hPad: CGFloat { isIPad ? 60 : 24 }

    var buttonSize: CGFloat {
        let size = (geometry.size.width - hPad * 2 - spacing * 3) / 4
        return min(size, isIPad ? 120 : 82)
    }

    var buttonWidth: CGFloat { button == .zero ? buttonSize * 2 + spacing : buttonSize }

    var fontSize: CGFloat {
        let base: CGFloat = isIPad ? 34 : 26
        return buttonSize > 70 ? base + 2 : base
    }

    var buttonBackgroundColor: Color {
        switch button.type {
        case .operation: return .orange
        case .clear:     return themeManager.isDarkMode ? Color(white: 0.3) : Color(white: 0.8)
        case .number:    return themeManager.isDarkMode ? Color(white: 0.2) : Color(white: 0.85)
        }
    }

    var buttonForegroundColor: Color {
        switch button.type {
        case .operation: return .white
        case .clear:     return .black
        case .number:    return themeManager.isDarkMode ? .white : .black
        }
    }
}

// MARK: - CalculatorBrain
class CalculatorBrain: ObservableObject {
    @Published var display = "0"
    @Published var previousValue = ""

    private var currentNumber: Double = 0
    private var previousNumber: Double = 0
    private var operation: CalculatorButton?
    private var isTypingNumber = false
    private var shouldResetDisplay = false

    func buttonTapped(_ button: CalculatorButton, history: CalculationHistory? = nil) {
        switch button.type {
        case .number:    handleNumber(button)
        case .operation: handleOperation(button, history: history)
        case .clear:     handleClear(button)
        }
    }

    private func handleNumber(_ button: CalculatorButton) {
        if shouldResetDisplay { display = "0"; shouldResetDisplay = false }
        if button == .decimal {
            if !display.contains(".") { display += "."; isTypingNumber = true }
            return
        }
        display = (display == "0") ? button.title : display + button.title
        isTypingNumber = true
    }

    private func handleOperation(_ button: CalculatorButton, history: CalculationHistory?) {
        let current = Double(display) ?? 0
        if isTypingNumber {
            if let op = operation {
                let result = calculate(op, previousNumber, current)
                display = format(result); currentNumber = result
            } else { currentNumber = current }
            previousNumber = currentNumber
        }
        if button == .equals {
            if let op = operation {
                let expr = "\(format(previousNumber)) \(op.title) \(format(current))"
                previousValue = expr
                history?.addCalculation(expression: expr, result: format(currentNumber))
            }
            operation = nil
        } else {
            operation = button
            previousValue = "\(format(previousNumber)) \(button.title)"
        }
        isTypingNumber = false; shouldResetDisplay = true
    }

    private func handleClear(_ button: CalculatorButton) {
        switch button {
        case .clear:    display = "0"; currentNumber = 0; previousNumber = 0; operation = nil; isTypingNumber = false; previousValue = ""
        case .negative: if let v = Double(display) { display = format(-v) }
        case .percent:  if let v = Double(display) { display = format(v / 100) }
        default: break
        }
    }

    private func calculate(_ op: CalculatorButton, _ a: Double, _ b: Double) -> Double {
        switch op {
        case .add:      return a + b
        case .subtract: return a - b
        case .multiply: return a * b
        case .divide:   return b != 0 ? a / b : 0
        default:        return b
        }
    }

    private func format(_ n: Double) -> String {
        n.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", n) : String(n)
    }
}

// MARK: - CalculatorButton
enum CalculatorButton: Hashable {
    case zero, one, two, three, four, five, six, seven, eight, nine
    case add, subtract, multiply, divide, equals
    case clear, negative, percent, decimal

    var title: String {
        switch self {
        case .zero: return "0"; case .one: return "1"; case .two: return "2"
        case .three: return "3"; case .four: return "4"; case .five: return "5"
        case .six: return "6"; case .seven: return "7"; case .eight: return "8"
        case .nine: return "9"; case .add: return "+"; case .subtract: return "−"
        case .multiply: return "×"; case .divide: return "÷"; case .equals: return "="
        case .clear: return "AC"; case .negative: return "+/−"
        case .percent: return "%"; case .decimal: return "."
        }
    }

    var type: ButtonType {
        switch self {
        case .add, .subtract, .multiply, .divide, .equals: return .operation
        case .clear, .negative, .percent:                  return .clear
        default:                                            return .number
        }
    }

    enum ButtonType { case number, operation, clear }
}

#Preview {
    BasicCalculatorView()
        .environmentObject(ThemeManager())
        .environmentObject(CalculationHistory())
}
