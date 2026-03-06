import SwiftUI
import UIKit

// ============================================================
// MARK: - LoanCalculatorView  (PDF button included)
// ============================================================
// Color.brand / Color.brandDark are from PremiumView.swift
// NO Color extension here — zero duplicate errors.

struct LoanCalculatorView: View {

    @State private var loanAmount        = ""
    @State private var interestRate      = ""
    @State private var loanTerm          = ""
    @State private var isKeyboardVisible = false
    
    
    // PDF states
    @State private var isGeneratingPDF = false
    @State private var showShareSheet  = false
    @State private var showPremium     = false
    @State private var pdfData: Data?

    @ObservedObject private var subManager = SubscriptionManager.shared

    @EnvironmentObject var themeManager:        ThemeManager
    @EnvironmentObject var currencyManager:     CurrencyManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    // ── Calculations ─────────────────────────────────────────────────────
    var monthlyPayment: Double {
        let p = Double(loanAmount) ?? 0
        let r = (Double(interestRate) ?? 0) / 100 / 12
        let n = Double(loanTerm) ?? 0
        guard p > 0, r > 0, n > 0 else { return 0 }
        return p * (r * pow(1 + r, n)) / (pow(1 + r, n) - 1)
    }
    var totalPayment:   Double { monthlyPayment * (Double(loanTerm) ?? 0) }
    var totalInterest:  Double { totalPayment - (Double(loanAmount) ?? 0) }
    var loanTermMonths: Int    { Int(loanTerm) ?? 0 }
    var isPremium:      Bool   { subManager.isPremium }
    static let brand = Color(hex: "#f0ad29")

    var planLabel: String {
        guard let pid = subManager.activeProductID else { return "Premium" }
        if pid == SubscriptionProductID.weekly.rawValue  { return "Weekly Plan" }
        if pid == SubscriptionProductID.monthly.rawValue { return "Monthly Plan" }
        if pid == SubscriptionProductID.yearly.rawValue  { return "Yearly Plan" }
        return "Premium Plan"
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {

                    // ── Loan Amount ──────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("loan.amount".localized(localizationManager))
                            .font(.headline).foregroundColor(.secondary)
                        HStack {
                            Text(currencyManager.selectedCurrency.symbol)
                                .font(.system(size: 28, weight: .semibold))
                            TextField("0", text: $loanAmount)
                                .keyboardType(.numberPad)
                                .font(.system(size: 32, weight: .semibold))
                        }
                        .padding().background(cardBackground).cornerRadius(12)
                    }

                    // ── Interest Rate ────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("interest.rate".localized(localizationManager))
                            .font(.headline).foregroundColor(.secondary)
                        TextField("0", text: $interestRate)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .semibold))
                            .padding().background(cardBackground).cornerRadius(12)
                    }

                    // ── Native Ad ────────────────────────────────────────
                    MoreNativeAd(isKeyboardVisible: $isKeyboardVisible)

                    // ── Loan Term ────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("loan.term".localized(localizationManager))
                            .font(.headline).foregroundColor(.secondary)
                        TextField("0", text: $loanTerm)
                            .keyboardType(.numberPad)
                            .font(.system(size: 28, weight: .semibold))
                            .padding().background(cardBackground).cornerRadius(12)
                    }

                    // ── Results + PDF Button ─────────────────────────────
                    if monthlyPayment > 0 {

                        // Results Card
                        VStack(spacing: 15) {
                            CurrencyResultRow(
                                title: "month.payment".localized(localizationManager),
                                amount: monthlyPayment,
                                currency: currencyManager.selectedCurrency.symbol,
                                color: .blue)
                            Divider()
                            CurrencyResultRow(
                                title: "total.payment".localized(localizationManager),
                                amount: totalPayment,
                                currency: currencyManager.selectedCurrency.symbol,
                                color: .green)
                            Divider()
                            CurrencyResultRow(
                                title: "total.interest".localized(localizationManager),
                                amount: totalInterest,
                                currency: currencyManager.selectedCurrency.symbol,
                                color: .orange)
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(12)

                        // ── PDF Download Button ──────────────────────────
                        pdfDownloadButton
                        // ────────────────────────────────────────────────
                    }

                    Spacer().frame(height: 100)
                }
                .padding()
            }
            .onTapGesture { hideKeyboard() }
        }
        .modifier(MoreNavModifier(title: "loan.calculator".localized(localizationManager)) {
            MoreAdCoordinator.shared.handleBack(screenType: .loan, dismiss: dismiss)
        })
        .onKeyboardChange { isKeyboardVisible = $0 }
        .sheet(isPresented: $showShareSheet) {
            if let data = pdfData {
                LoanPDFShareSheet(data: data, fileName: "LoanReport_MegaCalc.pdf")
            }
        }
        .fullScreenCover(isPresented: $showPremium) {
            PremiumView()
        }
    }

    // ============================================================
    // MARK: - PDF Download Button
    // ============================================================
    // Premium  → Gold (#f0ad29) button → generate + share PDF
    // Free     → Grey locked button   → open PremiumView paywall
    // Expired  → auto grey (StoreKit handles isPremium = false)
    // ============================================================
    private var pdfDownloadButton: some View {
        VStack(spacing: 6) {

            Button(action: handlePDFTap) {
                HStack(spacing: 14) {

                    // ── Left icon ────────────────────────────────────────
                    ZStack {
                        // Circle background
                        Circle()
                            .fill(Color.white.opacity(isPremium ? 0.20 : 0.12))
                            .frame(width: 42, height: 42)

                        if isGeneratingPDF {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: isPremium
                                  ? "arrow.down.doc.fill"
                                  : "lock.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    // ── Text ─────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isGeneratingPDF
                             ? "Generating PDF…"
                             : "Download Loan Report")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)

                        Text(isPremium
                             ? "Full amortization schedule included"
                             : "Premium feature · Tap to unlock")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()

                    // ── Right badge ───────────────────────────────────────
                    if isPremium {
                        // Arrow for premium
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                    } else {
                        // PRO crown badge for locked
                        HStack(spacing: 3) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("PRO")
                                .font(.system(size: 10, weight: .black))
                        }
                        // Badge text in brand gold on dark bg
//                        .foregroundColor(Color.brand)
                        .foregroundColor(.white)   // ✅ White text (gold button pe dikhega)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: "#f0ad29").opacity(0.70), lineWidth: 1.2)

                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                // ── Button background ─────────────────────────────────────
                // Premium  → App brand gold gradient (#f0ad29 → #d4941a)
                // Locked   → Dark grey (so PRO badge pops in gold)
                .background(
                    Group {
                        if isPremium {
                            LinearGradient(
                                colors: [Color.brand, Color.brandDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                colors: [Color.brand, Color.brandDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .cornerRadius(16)
                // Shadow — gold glow when premium, subtle when locked
                .shadow(
                    color: isPremium
                        ? Color.brand.opacity(0.50)
                        : Color.black.opacity(0.22),
                    radius: 10, x: 0, y: 5
                )
                // Dashed gold border only when locked (draws attention)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isPremium ? Color.clear : Color.brand.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])
                        )
                )
            }
            .disabled(isGeneratingPDF)
            .animation(.easeInOut(duration: 0.25), value: isPremium)

            // ── Sub-label ────────────────────────────────────────────────
            HStack(spacing: 5) {
                Image(systemName: isPremium ? "checkmark.shield.fill" : "crown.fill")
                    .font(.system(size: 10))
                    .foregroundColor(isPremium ? .green : Color.brand)

                Text(isPremium
                     ? "Active · \(planLabel) · PDF unlocked"
                     : "Subscribe to unlock · Auto-locks when plan expires")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    // MARK: - Actions
    private func handlePDFTap() {
        if isPremium { generatePDF() } else { showPremium = true }
    }

    private func generatePDF() {
        guard monthlyPayment > 0 else { return }
        isGeneratingPDF = true
        DispatchQueue.global(qos: .userInitiated).async {
            let data = LoanPDFGenerator.generate(
                loanAmount:     Double(self.loanAmount) ?? 0,
                interestRate:   Double(self.interestRate) ?? 0,
                loanTermMonths: self.loanTermMonths,
                monthlyPayment: self.monthlyPayment,
                totalPayment:   self.totalPayment,
                totalInterest:  self.totalInterest,
                currencySymbol: self.currencyManager.selectedCurrency.symbol
            )
            DispatchQueue.main.async {
                self.isGeneratingPDF = false
                self.pdfData = data
                if data != nil { self.showShareSheet = true }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var backgroundColor: Color { themeManager.isDarkMode ? .black : Color(UIColor.systemGroupedBackground) }
    var cardBackground:  Color { themeManager.isDarkMode ? Color(white: 0.15) : .white }
}

// MARK: - Share Sheet
struct LoanPDFShareSheet: UIViewControllerRepresentable {
    let data: Data
    let fileName: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}


// ============================================================
// MARK: - LoanPDFGenerator
// ============================================================
// Native UIGraphicsPDFRenderer — no third-party library.
// Generates a professional A4 PDF with:
//   • Brand-colored header (#f0ad29)
//   • 3 input summary cards
//   • Payment summary table
//   • Principal vs Interest pie chart
//   • Full amortization table (multi-page aware)
//   • Footer on every page

struct LoanPDFGenerator {

    // ── UIColors (matching app brand, no SwiftUI Color needed) ──────────
    private static let cBrand  = UIColor(red: 0.941, green: 0.678, blue: 0.161, alpha: 1) // #f0ad29
    private static let cNavy   = UIColor(red: 0.10,  green: 0.12,  blue: 0.20,  alpha: 1)
    private static let cGreen  = UIColor(red: 0.16,  green: 0.74,  blue: 0.38,  alpha: 1)
    private static let cBlue   = UIColor(red: 0.20,  green: 0.48,  blue: 0.90,  alpha: 1)
    private static let cOrange = UIColor(red: 0.97,  green: 0.56,  blue: 0.12,  alpha: 1)
    private static let cRowAlt = UIColor(red: 0.97,  green: 0.97,  blue: 0.99,  alpha: 1)

    // ── A4 page ──────────────────────────────────────────────────────────
    private static let PW: CGFloat = 595
    private static let PH: CGFloat = 842
    private static let PM: CGFloat = 36   // margin

    // ── Number formatter ─────────────────────────────────────────────────
    private static func fmt(_ v: Double, dec: Int = 2) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = dec
        f.maximumFractionDigits = dec
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.\(dec)f", v)
    }

    // ── Entry point ──────────────────────────────────────────────────────
    static func generate(
        loanAmount:     Double,
        interestRate:   Double,
        loanTermMonths: Int,
        monthlyPayment: Double,
        totalPayment:   Double,
        totalInterest:  Double,
        currencySymbol: String
    ) -> Data? {

        let pageRect = CGRect(x: 0, y: 0, width: PW, height: PH)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            let gc  = ctx.cgContext
            let sym = currencySymbol

            var y = drawHeader(gc, title: "Loan Summary Report")
            y = drawDateLine(gc, y: y)
            y = drawInputCards(gc, y: y,
                               amount: loanAmount,
                               rate: interestRate,
                               months: loanTermMonths,
                               sym: sym)
            y = drawSummaryTable(gc, y: y,
                                 monthly: monthlyPayment,
                                 total: totalPayment,
                                 interest: totalInterest,
                                 sym: sym)
            y = drawPieChart(gc, y: y,
                             principal: loanAmount,
                             interest: totalInterest)
            y = drawSectionTitle(gc, y: y, text: "Amortization Schedule")
            drawAmortTable(ctx, gc: gc, y: y,
                           balance: loanAmount,
                           rate: interestRate / 100.0 / 12.0,
                           months: loanTermMonths,
                           payment: monthlyPayment,
                           sym: sym,
                           pageRect: pageRect)
            drawFooter(gc, rect: pageRect)
        }
    }

    // ── HEADER ───────────────────────────────────────────────────────────
    @discardableResult
    private static func drawHeader(_ gc: CGContext, title: String) -> CGFloat {
        // Navy background
        gc.setFillColor(cNavy.cgColor)
        gc.fill(CGRect(x: 0, y: 0, width: PW, height: 76))
        // Brand gold strip
        gc.setFillColor(cBrand.cgColor)
        gc.fill(CGRect(x: 0, y: 68, width: PW, height: 8))

        draw("MegaCalc · Loan Calculator",
             at: CGPoint(x: PM, y: 10),
             font: .systemFont(ofSize: 10, weight: .medium),
             color: UIColor(white: 0.65, alpha: 1))

        draw(title,
             at: CGPoint(x: PM, y: 28),
             font: .systemFont(ofSize: 22, weight: .bold),
             color: .white)

        // ★ PREMIUM badge
        let bt = " ★ PREMIUM "
        let ba: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: cNavy
        ]
        let bsz = (bt as NSString).size(withAttributes: ba)
        let br  = CGRect(x: PW - PM - bsz.width - 12, y: 24,
                         width: bsz.width + 12, height: 20)
        gc.setFillColor(cBrand.cgColor)
        UIBezierPath(roundedRect: br, cornerRadius: 10).fill()
        bt.draw(at: CGPoint(x: br.minX + 6, y: br.minY + 4), withAttributes: ba)

        return 76
    }

    // ── DATE LINE ────────────────────────────────────────────────────────
    @discardableResult
    private static func drawDateLine(_ gc: CGContext, y: CGFloat) -> CGFloat {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        draw("Generated on \(f.string(from: Date()))",
             at: CGPoint(x: PM, y: y + 10),
             font: .systemFont(ofSize: 10),
             color: .black)
        hline(gc, y: y + 26)
        return y + 34
    }

    // ── INPUT CARDS ──────────────────────────────────────────────────────
    @discardableResult
    private static func drawInputCards(
        _ gc: CGContext, y: CGFloat,
        amount: Double, rate: Double, months: Int, sym: String
    ) -> CGFloat {

        let cW     = (PW - PM * 2 - 16) / 3
        let cH:  CGFloat = 68
        let gap: CGFloat = 8
        let startY = y + 12

        let cards: [(label: String, value: String, color: UIColor)] = [
            ("Loan Amount",   "\(sym)\(fmt(amount, dec: 0))", cBlue),
            ("Interest Rate", "\(fmt(rate, dec: 2))% p.a.",   cOrange),
            ("Loan Term",     "\(months) months",              cGreen)
        ]

        for (i, card) in cards.enumerated() {
            let x    = PM + CGFloat(i) * (cW + gap)
            let rect = CGRect(x: x, y: startY, width: cW, height: cH)

            // shadow
            gc.setFillColor(UIColor(white: 0.80, alpha: 1).cgColor)
            gc.fill(rect.insetBy(dx: -1, dy: -1).offsetBy(dx: 2, dy: 2))
            // white card body
            gc.setFillColor(UIColor.white.cgColor)
            UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
            // left accent bar in brand/blue/green/orange
            gc.setFillColor(card.color.cgColor)
            UIBezierPath(roundedRect: CGRect(x: x, y: startY, width: 5, height: cH),
                         cornerRadius: 2).fill()

            draw(card.label,
                 at: CGPoint(x: x + 12, y: startY + 10),
                 font: .systemFont(ofSize: 9, weight: .medium),
                 color: .black)
            draw(card.value,
                 at: CGPoint(x: x + 12, y: startY + 28),
                 font: .systemFont(ofSize: 14, weight: .bold),
                 color: card.color)
        }
        return startY + cH + 18
    }

    // ── PAYMENT SUMMARY TABLE ────────────────────────────────────────────
    @discardableResult
    private static func drawSummaryTable(
        _ gc: CGContext, y: CGFloat,
        monthly: Double, total: Double, interest: Double, sym: String
    ) -> CGFloat {

        var cy = drawSectionTitle(gc, y: y, text: "Payment Summary")
        let tW = PW - PM * 2
        let rH: CGFloat = 38

        let rows: [(String, String, UIColor)] = [
            ("Monthly EMI Payment",    "\(sym)\(fmt(monthly))",  cBlue),
            ("Total Amount Payable",   "\(sym)\(fmt(total))",    cGreen),
            ("Total Interest Charged", "\(sym)\(fmt(interest))", cOrange)
        ]

        for (i, row) in rows.enumerated() {
            let ry = cy + CGFloat(i) * rH
            gc.setFillColor((i % 2 == 0 ? cRowAlt : UIColor.white).cgColor)
            gc.fill(CGRect(x: PM, y: ry, width: tW, height: rH))

            // coloured dot
            gc.setFillColor(row.2.cgColor)
            UIBezierPath(ovalIn: CGRect(x: PM + 12, y: ry + 13, width: 12, height: 12)).fill()

            draw(row.0,
                 at: CGPoint(x: PM + 32, y: ry + 12),
                 font: .systemFont(ofSize: 12, weight: .medium),
                 color: .black)

            let va: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: row.2
            ]
            let vsz = (row.1 as NSString).size(withAttributes: va)
            row.1.draw(at: CGPoint(x: PM + tW - vsz.width - 12, y: ry + 11), withAttributes: va)

            gc.setStrokeColor(UIColor(white: 0.88, alpha: 1).cgColor)
            gc.setLineWidth(0.5)
            gc.move(to: CGPoint(x: PM, y: ry + rH))
            gc.addLine(to: CGPoint(x: PM + tW, y: ry + rH))
            gc.strokePath()
        }

        gc.setStrokeColor(UIColor(white: 0.78, alpha: 1).cgColor)
        gc.setLineWidth(1)
        UIBezierPath(roundedRect: CGRect(x: PM, y: cy, width: tW, height: rH * 3),
                     cornerRadius: 8).stroke()

        return cy + rH * 3 + 18
    }

    // ── PIE CHART ────────────────────────────────────────────────────────
    @discardableResult
    private static func drawPieChart(
        _ gc: CGContext, y: CGFloat,
        principal: Double, interest: Double
    ) -> CGFloat {

        guard principal + interest > 0 else { return y }
        var cy  = drawSectionTitle(gc, y: y, text: "Principal vs Interest Breakdown")
        let cx  = CGPoint(x: PM + 55, y: cy + 10 + 48)
        let r: CGFloat = 48
        let total = principal + interest
        let pAng  = CGFloat((principal / total) * 2 * .pi)

        // Principal slice (blue)
        gc.setFillColor(cBlue.cgColor)
        let p1 = UIBezierPath()
        p1.move(to: cx)
        p1.addArc(withCenter: cx, radius: r,
                  startAngle: -.pi/2, endAngle: -.pi/2 + pAng, clockwise: true)
        p1.close(); p1.fill()

        // Interest slice (orange)
        gc.setFillColor(cOrange.cgColor)
        let p2 = UIBezierPath()
        p2.move(to: cx)
        p2.addArc(withCenter: cx, radius: r,
                  startAngle: -.pi/2 + pAng, endAngle: -.pi/2 + 2 * .pi, clockwise: true)
        p2.close(); p2.fill()

        // White separator
        gc.setStrokeColor(UIColor.white.cgColor)
        gc.setLineWidth(2)
        gc.move(to: cx)
        gc.addLine(to: CGPoint(x: cx.x, y: cx.y - r))
        gc.strokePath()

        // Legend
        let lx   = cx.x + r + 20
        let topY = cy + 10
        let pPct = Int((principal / total) * 100)

        gc.setFillColor(cBlue.cgColor)
        gc.fill(CGRect(x: lx, y: topY + 14, width: 12, height: 12))
        draw("Principal  \(pPct)%",
             at: CGPoint(x: lx + 18, y: topY + 12),
             font: .systemFont(ofSize: 12, weight: .semibold),
             color: cBlue)

        gc.setFillColor(cOrange.cgColor)
        gc.fill(CGRect(x: lx, y: topY + 36, width: 12, height: 12))
        draw("Interest  \(100 - pPct)%",
             at: CGPoint(x: lx + 18, y: topY + 34),
             font: .systemFont(ofSize: 12, weight: .semibold),
             color: cOrange)

        cy = topY + r * 2 + 24
        return cy
    }

    // ── AMORTIZATION TABLE (multi-page) ──────────────────────────────────
    @discardableResult
    private static func drawAmortTable(
        _ ctx: UIGraphicsPDFRendererContext,
        gc: CGContext,
        y: CGFloat,
        balance startBal: Double,
        rate: Double,
        months: Int,
        payment: Double,
        sym: String,
        pageRect: CGRect
    ) -> CGFloat {

        let cols: [String]  = ["Month", "Opening Bal.", "Principal", "Interest", "Closing Bal."]
        let colW: [CGFloat] = [42,       110,            100,         100,         113]
        let tW   = PW - PM * 2
        let rH: CGFloat = 20
        let hH: CGFloat = 26

        var curGC = gc
        var curY  = y
        var bal   = startBal

        func drawHeaders(at hy: CGFloat) {
            curGC.setFillColor(cNavy.cgColor)
            curGC.fill(CGRect(x: PM, y: hy, width: tW, height: hH))
            var xo: CGFloat = PM
            for (i, col) in cols.enumerated() {
                let a: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let sz = (col as NSString).size(withAttributes: a)
                let tx = i == 0 ? xo + 4 : xo + colW[i] - sz.width - 4
                col.draw(at: CGPoint(x: tx, y: hy + 7), withAttributes: a)
                xo += colW[i]
            }
        }

        drawHeaders(at: curY)
        curY += hH

        for month in 1...max(1, months) {
            // New page if needed
            if curY + rH > PH - 40 {
                drawFooter(curGC, rect: pageRect)
                ctx.beginPage()
                curGC = ctx.cgContext
                _ = drawHeader(curGC, title: "Amortization Schedule (Continued)")
                curY = 84
                drawHeaders(at: curY)
                curY += hH
            }

            let intAmt  = bal * rate
            let prinAmt = min(payment - intAmt, bal)
            let closing = max(bal - prinAmt, 0)

            // Row background
            curGC.setFillColor((month % 2 == 0 ? UIColor.white : cRowAlt).cgColor)
            curGC.fill(CGRect(x: PM, y: curY, width: tW, height: rH))

            // Highlight last row with gold tint
            if month == months {
                curGC.setFillColor(cBrand.withAlphaComponent(0.12).cgColor)
                curGC.fill(CGRect(x: PM, y: curY, width: tW, height: rH))
            }

            let vals: [String] = [
                "\(month)",
                "\(sym)\(fmt(bal))",
                "\(sym)\(fmt(prinAmt))",
                "\(sym)\(fmt(intAmt))",
                "\(sym)\(fmt(closing))"
            ]
            let colors: [UIColor] = [.black, .black, cBlue, cOrange, .black]

            var xo: CGFloat = PM
            for (i, val) in vals.enumerated() {
                let a: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9,
                                            weight: i == 0 ? .semibold : .regular),
                    .foregroundColor: colors[i]
                ]
                let sz = (val as NSString).size(withAttributes: a)
                let tx = i == 0 ? xo + 4 : xo + colW[i] - sz.width - 4
                val.draw(at: CGPoint(x: tx, y: curY + 5), withAttributes: a)
                xo += colW[i]
            }

            curGC.setStrokeColor(UIColor(white: 0.88, alpha: 1).cgColor)
            curGC.setLineWidth(0.3)
            curGC.move(to: CGPoint(x: PM, y: curY + rH))
            curGC.addLine(to: CGPoint(x: PM + tW, y: curY + rH))
            curGC.strokePath()

            bal   = closing
            curY += rH
        }

        // Table outer border
        curGC.setStrokeColor(UIColor(white: 0.72, alpha: 1).cgColor)
        curGC.setLineWidth(1)
        UIBezierPath(roundedRect: CGRect(x: PM, y: y, width: tW, height: curY - y),
                     cornerRadius: 4).stroke()

        return curY + 10
    }

    // ── FOOTER ───────────────────────────────────────────────────────────
    private static func drawFooter(_ gc: CGContext, rect: CGRect) {
        gc.setFillColor(cNavy.cgColor)
        gc.fill(CGRect(x: 0, y: rect.height - 28, width: rect.width, height: 28))

        draw("MegaCalc · Premium Loan Report",
             at: CGPoint(x: PM, y: rect.height - 20),
             font: .systemFont(ofSize: 9),
             color: UIColor(white: 0.65, alpha: 1))

        let note = "For informational purposes only."
        let na: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor(white: 0.65, alpha: 1)
        ]
        let nsz = (note as NSString).size(withAttributes: na)
        note.draw(at: CGPoint(x: rect.width - PM - nsz.width, y: rect.height - 20),
                  withAttributes: na)
    }

    // ── HELPERS ──────────────────────────────────────────────────────────
    @discardableResult
    private static func drawSectionTitle(_ gc: CGContext, y: CGFloat, text: String) -> CGFloat {
        let sy = y + 6
        gc.setFillColor(cBrand.cgColor)
        gc.fill(CGRect(x: PM, y: sy + 1, width: 4, height: 14))
        draw(text,
             at: CGPoint(x: PM + 10, y: sy),
             font: .systemFont(ofSize: 12, weight: .bold),
             color: .black)
        return sy + 22
    }

    private static func hline(_ gc: CGContext, y: CGFloat) {
        gc.setStrokeColor(UIColor(white: 0.85, alpha: 1).cgColor)
        gc.setLineWidth(0.8)
        gc.move(to: CGPoint(x: PM, y: y))
        gc.addLine(to: CGPoint(x: PW - PM, y: y))
        gc.strokePath()
    }

    private static func draw(_ s: String, at p: CGPoint, font: UIFont, color: UIColor) {
        s.draw(at: p, withAttributes: [.font: font, .foregroundColor: color])
    }
}
