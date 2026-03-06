//
//  ThemeManager.swift
//  smart calculator
//
//  Created by Hevin Technoweb on 30/01/26.
//
import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    func toggleTheme() {
        isDarkMode.toggle()
    }
}

class CalculationHistory: ObservableObject {
    @Published var calculations: [CalculationItem] = [] {
        didSet {
            saveCalculations()
        }
    }
    
    init() {
        loadCalculations()
    }
    
    func addCalculation(expression: String, result: String) {
        let item = CalculationItem(expression: expression, result: result, timestamp: Date())
        calculations.insert(item, at: 0)
        
        // Keep only last 50 calculations
        if calculations.count > 50 {
            calculations.removeLast()
        }
    }
    
    func clearHistory() {
        calculations.removeAll()
    }
    
    private func saveCalculations() {
        if let encoded = try? JSONEncoder().encode(calculations) {
            UserDefaults.standard.set(encoded, forKey: "savedCalculations")
        }
    }
    
    private func loadCalculations() {
        if let savedData = UserDefaults.standard.data(forKey: "savedCalculations"),
           let decoded = try? JSONDecoder().decode([CalculationItem].self, from: savedData) {
            calculations = decoded
        }
    }
}

struct CalculationItem: Identifiable, Codable {
    let id: UUID
    let expression: String
    let result: String
    let timestamp: Date
    
    init(expression: String, result: String, timestamp: Date) {
        self.id = UUID()
        self.expression = expression
        self.result = result
        self.timestamp = timestamp
    }
}
