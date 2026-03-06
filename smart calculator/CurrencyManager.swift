//
//  CurrencyManager.swift
//  smart calculator
//
//  Created by Hevin Technoweb
//

import SwiftUI
import Combine

struct Currency: Identifiable, Codable {
    let id: String
    let name: String
    let symbol: String
    let flagImage: String // Changed from flag to flagImage
    
    init(id: String, name: String, symbol: String, flagImage: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.flagImage = flagImage
    }
}

class CurrencyManager: ObservableObject {
    @Published var selectedCurrency: Currency {
        didSet {
            saveCurrency()
        }
    }
    
    let availableCurrencies: [Currency] = [
        Currency(id: "AUD", name: "AUD (Australia)", symbol: "A$", flagImage: "flag_australia"),
        Currency(id: "CAD", name: "CAD (Canada)", symbol: "C$", flagImage: "flag_canada"),
        Currency(id: "INR", name: "INR (India)", symbol: "₹", flagImage: "flag_india"),
        Currency(id: "CNY", name: "CNY (China)", symbol: "¥", flagImage: "flag_china"),
        Currency(id: "EUR", name: "EUR (Spain)", symbol: "€", flagImage: "flag_spain"),
        Currency(id: "JPY", name: "JPY (Japan)", symbol: "¥", flagImage: "flag_japan"),
        Currency(id: "RUB", name: "RUB (Russia)", symbol: "₽", flagImage: "flag_russia"),
        Currency(id: "TRY", name: "TRY (Turkey)", symbol: "₺", flagImage: "flag_turkey"),
        Currency(id: "USD", name: "USD (USA)", symbol: "$", flagImage: "flag_usa"),
        Currency(id: "GBP", name: "GBP (UK)", symbol: "£", flagImage: "flag_uk")
    ]
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "selectedCurrency"),
           let currency = try? JSONDecoder().decode(Currency.self, from: data) {
            self.selectedCurrency = currency
        } else {
            self.selectedCurrency = availableCurrencies[2] // Default to INR
        }
    }
    
    private func saveCurrency() {
        if let encoded = try? JSONEncoder().encode(selectedCurrency) {
            UserDefaults.standard.set(encoded, forKey: "selectedCurrency")
        }
    }
}
