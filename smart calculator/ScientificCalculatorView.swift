import SwiftUI
import Combine

struct ScientificCalculatorView: View {
    @StateObject private var calculator = ScientificCalculatorBrain()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var calculationHistory: CalculationHistory
    @StateObject private var localizationManager = LocalizationManager()
    @ObservedObject private var remoteConfig = RemoteConfigManager.shared
//    @StateObject private var backAdManager = InterstitialAdManager(adUnitID: "")
    @Environment(\.dismiss) var dismiss
    @State private var isInverseMode = false
    
    private func handleBackButton() {
//        if remoteConfig.shouldShowBackButtonAd() {
//            backAdManager.showAd()
//        }
        dismiss()
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    backgroundColor.ignoresSafeArea()
                    
                    VStack(spacing: spacing(for: geometry)) {
                        // Display
                        VStack(alignment: .trailing, spacing: 8) {
                            if !calculator.previousValue.isEmpty {
                                Text(calculator.previousValue)
                                    .font(.system(size: previousFontSize(for: geometry), weight: .light))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                            
                            Text(calculator.display)
                                .font(.system(size: displayFontSize(for: geometry), weight: .light))
                                .foregroundColor(displayColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.3)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, horizontalPadding(for: geometry))
                        .padding(.vertical, verticalPadding(for: geometry))
                        
                        // Toggle Inverse Mode
                        HStack {
                            Button(action: { isInverseMode.toggle() }) {
                                Text(isInverseMode ? "INV" : "2nd")
                                    .font(.system(size: toggleFontSize(for: geometry), weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: toggleWidth(for: geometry), height: toggleHeight(for: geometry))
                                    .background(isInverseMode ? Color.orange : Color.gray)
                                    .cornerRadius(8)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, horizontalPadding(for: geometry))
                        
                        // Scientific Buttons
                        ScrollView {
                            VStack(spacing: buttonSpacing(for: geometry)) {
                                // Row 1: Functions
                                HStack(spacing: buttonSpacing(for: geometry)) {
                                    sciButton("(", .gray, geometry)
                                    sciButton(")", .gray, geometry)
                                    sciButton("mc", .gray, geometry)
                                    sciButton("m+", .gray, geometry)
                                    sciButton("m-", .gray, geometry)
                                    sciButton("mr", .gray, geometry)
                                }
                                
                                // Row 2: Advanced Functions
                                HStack(spacing: buttonSpacing(for: geometry)) {
                                    sciButton(isInverseMode ? "²" : "x²", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                    sciButton(isInverseMode ? "³" : "x³", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                    sciButton(isInverseMode ? "ʸ" : "xʸ", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                    sciButton(isInverseMode ? "eˣ" : "eˣ", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                    sciButton(isInverseMode ? "10ˣ" : "10ˣ", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                }
                                
                                // Row 3: Inverse & Roots
                                HStack(spacing: buttonSpacing(for: geometry)) {
                                    sciButton("1/x", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                    sciButton("√", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                    sciButton("∛", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                    sciButton(isInverseMode ? "ʸ√x" : "ʸ√", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                    sciButton("ln", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                }
                                
                                // Row 4: Trig Functions
                                HStack(spacing: buttonSpacing(for: geometry)) {
                                    sciButton(isInverseMode ? "sin⁻¹" : "sin", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                    sciButton(isInverseMode ? "cos⁻¹" : "cos", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                    sciButton(isInverseMode ? "tan⁻¹" : "tan", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                    sciButton("log", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                    sciButton("x!", Color(red: 0.3, green: 0.3, blue: 0.3), geometry)
                                }
                                
                                // Row 5: Constants & Memory
                                HStack(spacing: buttonSpacing(for: geometry)) {
                                    sciButton("Rad", .gray, geometry)
                                    sciButton("π", .gray, geometry)
                                    sciButton("e", .gray, geometry)
                                    sciButton("C", .gray, geometry)
                                    sciButton("⌫", .gray, geometry)
                                }
                                
                                // Basic Calculator Grid
                                VStack(spacing: buttonSpacing(for: geometry)) {
                                    HStack(spacing: buttonSpacing(for: geometry)) {
                                        numButton("7", geometry)
                                        numButton("8", geometry)
                                        numButton("9", geometry)
                                        opButton("÷", geometry)
                                    }
                                    
                                    HStack(spacing: buttonSpacing(for: geometry)) {
                                        numButton("4", geometry)
                                        numButton("5", geometry)
                                        numButton("6", geometry)
                                        opButton("×", geometry)
                                    }
                                    
                                    HStack(spacing: buttonSpacing(for: geometry)) {
                                        numButton("1", geometry)
                                        numButton("2", geometry)
                                        numButton("3", geometry)
                                        opButton("−", geometry)
                                    }
                                    
                                    HStack(spacing: buttonSpacing(for: geometry)) {
                                        numButton("0", geometry)
                                        numButton(".", geometry)
                                        opButton("=", geometry)
                                        opButton("+", geometry)
                                    }
                                }
                            }
                            .padding(.horizontal, horizontalPadding(for: geometry))
                        }
                        .padding(.bottom, bottomPadding(for: geometry))
                    }
                }
            }
//            .navigationTitle("tab.scientific".localized(localizationManager))
//            .navigationBarTitleDisplayMode(.inline)
            
            
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("tab.scientific".localized(localizationManager))
                        .font(.system(size: 20, weight: .semibold))
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Helper Functions
    
    private func isIPad(_ geometry: GeometryProxy) -> Bool {
        geometry.size.width > 600
    }
    
    private func horizontalPadding(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 40 : 20
    }
    
    private func verticalPadding(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 24 : 16
    }
    
    private func spacing(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 16 : 12
    }
    
    private func buttonSpacing(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 12 : 8
    }
    
    private func bottomPadding(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 20 : 10
    }
    
    private func displayFontSize(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 64 : 48
    }
    
    private func previousFontSize(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 28 : 20
    }
    
    private func toggleFontSize(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 20 : 16
    }
    
    private func toggleWidth(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 80 : 60
    }
    
    private func toggleHeight(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 45 : 35
    }
    
    private func sciFontSize(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 18 : 14
    }
    
    private func sciButtonHeight(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 60 : 45
    }
    
    private func numFontSize(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 32 : 24
    }
    
    private func numButtonHeight(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 75 : 60
    }
    
    private func opFontSize(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 36 : 28
    }
    
    // MARK: - Button Views
    
    func sciButton(_ title: String, _ color: Color, _ geometry: GeometryProxy) -> some View {
        Button(action: {
            calculator.scientificButtonTapped(title)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            Text(title)
                .font(.system(size: sciFontSize(for: geometry), weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: sciButtonHeight(for: geometry))
                .background(color)
                .cornerRadius(isIPad(geometry) ? 12 : 8)
        }
    }
    
    func numButton(_ title: String, _ geometry: GeometryProxy) -> some View {
        Button(action: {
            calculator.numberTapped(title)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            Text(title)
                .font(.system(size: numFontSize(for: geometry), weight: .medium))
                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                .frame(maxWidth: .infinity)
                .frame(height: numButtonHeight(for: geometry))
                .background(themeManager.isDarkMode ? Color(white: 0.2) : Color(white: 0.95))
                .cornerRadius(isIPad(geometry) ? 16 : 12)
        }
    }
    
    func opButton(_ title: String, _ geometry: GeometryProxy) -> some View {
        Button(action: {
            calculator.operationTapped(title, history: calculationHistory)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            Text(title)
                .font(.system(size: opFontSize(for: geometry), weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: numButtonHeight(for: geometry))
                .background(Color.orange)
                .cornerRadius(isIPad(geometry) ? 16 : 12)
        }
    }
    
    var backgroundColor: Color {
        themeManager.isDarkMode ? Color.black : Color(UIColor.systemGroupedBackground)
    }
    
    var displayColor: Color {
        themeManager.isDarkMode ? .white : .black
    }
}

class ScientificCalculatorBrain: ObservableObject {
    @Published var display = "0"
    @Published var previousValue = ""
    
    private var currentNumber: Double = 0
    private var previousNumber: Double = 0
    private var operation: String?
    private var memory: Double = 0
    private var isTypingNumber = false
    
    func numberTapped(_ num: String) {
        if num == "." {
            if !display.contains(".") {
                display += "."
            }
            return
        }
        
        if display == "0" || !isTypingNumber {
            display = num
        } else {
            display += num
        }
        isTypingNumber = true
    }
    
    func operationTapped(_ op: String, history: CalculationHistory? = nil) {
        guard let currentValue = Double(display) else { return }
        
        if isTypingNumber {
            if let operation = operation {
                let result = performOperation(operation, previousNumber, currentValue)
                display = formatNumber(result)
                currentNumber = result
            } else {
                currentNumber = currentValue
            }
            previousNumber = currentNumber
        }
        
        if op == "=" {
            if let operation = operation {
                let expression = "\(formatNumber(previousNumber)) \(operation) \(formatNumber(currentValue))"
                let resultString = formatNumber(currentNumber)
                
                // Save to history
                history?.addCalculation(expression: expression, result: resultString)
            }
            previousValue = ""
            operation = nil
        } else {
            operation = op
            previousValue = "\(formatNumber(previousNumber)) \(op)"
        }
        
        isTypingNumber = false
    }
    
    func scientificButtonTapped(_ button: String) {
        guard let value = Double(display) else { return }
        var result: Double = 0
        
        switch button {
        case "sin":
            result = sin(value * .pi / 180)
        case "cos":
            result = cos(value * .pi / 180)
        case "tan":
            result = tan(value * .pi / 180)
        case "sin⁻¹":
            result = asin(value) * 180 / .pi
        case "cos⁻¹":
            result = acos(value) * 180 / .pi
        case "tan⁻¹":
            result = atan(value) * 180 / .pi
        case "ln":
            result = log(value)
        case "log":
            result = log10(value)
        case "x²", "²":
            result = pow(value, 2)
        case "x³", "³":
            result = pow(value, 3)
        case "√":
            result = sqrt(value)
        case "∛":
            result = pow(value, 1.0/3.0)
        case "1/x":
            result = 1 / value
        case "x!":
            result = factorial(Int(value))
        case "eˣ":
            result = exp(value)
        case "10ˣ":
            result = pow(10, value)
        case "π":
            display = String(Double.pi)
            return
        case "e":
            display = String(M_E)
            return
        case "C":
            display = "0"
            currentNumber = 0
            previousNumber = 0
            operation = nil
            previousValue = ""
            return
        case "⌫":
            if display.count > 1 {
                display.removeLast()
            } else {
                display = "0"
            }
            return
        case "mc":
            memory = 0
            return
        case "m+":
            memory += value
            return
        case "m-":
            memory -= value
            return
        case "mr":
            display = formatNumber(memory)
            return
        default:
            return
        }
        
        display = formatNumber(result)
        isTypingNumber = false
    }
    
    private func performOperation(_ op: String, _ num1: Double, _ num2: Double) -> Double {
        switch op {
        case "+": return num1 + num2
        case "−": return num1 - num2
        case "×": return num1 * num2
        case "÷": return num2 != 0 ? num1 / num2 : 0
        default: return num2
        }
    }
    
    private func factorial(_ n: Int) -> Double {
        if n < 0 { return 0 }
        if n <= 1 { return 1 }
        if n > 20 { return Double.infinity }
        
        var result: Double = 1
        for i in 2...n {
            result *= Double(i)
        }
        return result
    }
    
    private func formatNumber(_ number: Double) -> String {
        if number.isNaN || number.isInfinite {
            return "Error"
        }
        
        if abs(number) < 0.000001 && number != 0 {
            return String(format: "%.2e", number)
        }
        
        if number.truncatingRemainder(dividingBy: 1) == 0 && abs(number) < 1000000000 {
            return String(format: "%.0f", number)
        } else {
            let formatted = String(format: "%.8f", number)
            return formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
    }
}

#Preview {
    ScientificCalculatorView()
        .environmentObject(ThemeManager())
        .environmentObject(CalculationHistory())
}
