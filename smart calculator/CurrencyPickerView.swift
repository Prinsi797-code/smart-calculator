//
//  CurrencyPickerView.swift
//  smart calculator
//
//  Created by Hevin Technoweb
//

import SwiftUI

struct CurrencyPickerView: View {
    @EnvironmentObject var currencyManager: CurrencyManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(currencyManager.availableCurrencies) { currency in
                    Button(action: {
                        currencyManager.selectedCurrency = currency
                        dismiss()
                    }) {
                        HStack(spacing: 15) {
                            // Use Image instead of Text emoji
                            Image(currency.flagImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currency.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text("\(currency.symbol) - \(currency.id)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if currency.id == currencyManager.selectedCurrency.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 22))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(rowBackground)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .background(backgroundColor.ignoresSafeArea())
//            .navigationTitle("Select Currency")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Done") {
//                        dismiss()
//                    }
//                }
//            }
            
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("select.currency".localized(localizationManager))
                        .font(.system(size: 20, weight: .semibold))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("settings.done".localized(localizationManager)) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    var backgroundColor: Color {
        themeManager.isDarkMode ? Color.black : Color(UIColor.systemGroupedBackground)
    }
    
    var rowBackground: Color {
        themeManager.isDarkMode ? Color(white: 0.1) : Color.white
    }
}
