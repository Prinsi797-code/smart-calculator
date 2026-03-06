import SwiftUI
import Combine

struct HistoryView: View {
    @EnvironmentObject var calculationHistory: CalculationHistory
    @StateObject private var localizationManager = LocalizationManager()
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    backgroundColor.ignoresSafeArea()
                    
                    if calculationHistory.calculations.isEmpty {
                        VStack(spacing: emptyStateSpacing(for: geometry)) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: emptyIconSize(for: geometry)))
                                .foregroundColor(.secondary)
                            
                            Text ("history.not".localized(localizationManager))
                            
//                            Text("No History Yet")
                                .font(.system(size: emptyTitleSize(for: geometry), weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Text ("history.small.not".localized(localizationManager))
//                            Text("Your calculations will appear here")
                                .font(.system(size: emptySubtitleSize(for: geometry)))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: maxContentWidth(for: geometry))
                    } else {
                        List {
                            ForEach(calculationHistory.calculations) { item in
                                VStack(alignment: .leading, spacing: itemSpacing(for: geometry)) {
                                    Text(item.expression)
                                        .font(.system(size: expressionFontSize(for: geometry)))
                                        .foregroundColor(.secondary)
                                    
                                    Text(item.result)
                                        .font(.system(size: resultFontSize(for: geometry), weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text(item.timestamp, style: .time)
                                        .font(.system(size: timestampFontSize(for: geometry)))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, itemVerticalPadding(for: geometry))
                                .listRowBackground(themeManager.isDarkMode ? Color(white: 0.1) : Color.white)
                            }
                            .onDelete { indexSet in
                                calculationHistory.calculations.remove(atOffsets: indexSet)
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
            }
            .navigationTitle("tab.history".localized(localizationManager))
            .navigationBarTitleDisplayMode(isIPadNavigation ? .inline : .large)
            .toolbar {
                if !calculationHistory.calculations.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("history.clear".localized(localizationManager)) {
                            withAnimation {
                                calculationHistory.clearHistory()
                            }
                        }
                        .foregroundColor(.red)
                        .font(.system(size: toolbarButtonSize))
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    var backgroundColor: Color {
        themeManager.isDarkMode ? Color.black : Color(UIColor.systemGroupedBackground)
    }
    
    // MARK: - Helper Functions
    
    private func isIPad(_ geometry: GeometryProxy) -> Bool {
        geometry.size.width > 600
    }
    
    private var isIPadNavigation: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var toolbarButtonSize: CGFloat {
        isIPadNavigation ? 18 : 17
    }
    
    // Empty State Sizing
    private func emptyIconSize(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 90 : 60
    }
    
    private func emptyTitleSize(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 32 : 22
    }
    
    private func emptySubtitleSize(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 20 : 15
    }
    
    private func emptyStateSpacing(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 28 : 20
    }
    
    // List Item Sizing
    private func expressionFontSize(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 22 : 16
    }
    
    private func resultFontSize(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 38 : 28
    }
    
    private func timestampFontSize(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 15 : 12
    }
    
    private func itemSpacing(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 12 : 8
    }
    
    private func itemVerticalPadding(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? 12 : 8
    }
    
    private func maxContentWidth(for geometry: GeometryProxy) -> CGFloat {
        isIPad(geometry) ? min(geometry.size.width * 0.6, 600) : .infinity
    }
}

#Preview {
    HistoryView()
        .environmentObject(ThemeManager())
        .environmentObject(CalculationHistory())
}
