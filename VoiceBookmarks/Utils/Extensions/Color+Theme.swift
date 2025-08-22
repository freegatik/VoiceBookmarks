//
//  Color+Theme.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

// MARK: - Цвета темы: gold (#FFD700), appWhite, appBackground, appText, error

extension Color {
    
    
    /// Золотой цвет (#FFD700) - основной акцентный цвет
    static let gold = Color(hex: "#FFD700")
    /// Белый цвет (#FFFFFF) - фон карточек
    static let appWhite = Color(hex: "#FFFFFF")
    /// Цвет фона приложения (#F5F5F5) - светло-серый
    static let appBackground = Color(hex: "#F5F5F5")
    /// Основной цвет текста (#000000) - черный
    static let appText = Color(hex: "#000000")
    /// Вторичный цвет текста (#666666) - серый
    static let appSecondaryText = Color(hex: "#666666")
    /// Цвет ошибки (#FF3B30) - красный
    static let error = Color(hex: "#FF3B30")
    
    
    /// Инициализация из HEX строки (#FFD700, #FFFFFF, #F5F5F5)
    /// Поддерживает форматы: 3 символа (#RGB), 6 символов (#RRGGBB), 8 символов (#AARRGGBB)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
