//
//  GlobalToastManager.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import SwiftUI

// MARK: - Глобальный менеджер уведомлений: success/error сообщения для всего приложения

class GlobalToastManager: ObservableObject {
    
    static let shared = GlobalToastManager()
    
    @Published var currentToast: ToastMessage?
    
    private init() {}
    
    
    /// Показывает успешное сообщение (зеленое уведомление)
    func showSuccess(_ message: String) {
        DispatchQueue.main.async {
            self.currentToast = ToastMessage(message: message, type: .success)
        }
    }
    
    /// Показывает сообщение об ошибке (красное уведомление)
    func showError(_ message: String) {
        DispatchQueue.main.async {
            self.currentToast = ToastMessage(message: message, type: .error)
        }
    }
    
    /// Скрывает текущее уведомление
    func dismiss() {
        DispatchQueue.main.async {
            self.currentToast = nil
        }
    }
}


/// Сообщение Toast для отображения уведомлений
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        return lhs.message == rhs.message && lhs.type == rhs.type
    }
}

enum ToastType: Equatable {
    case success
    case error
}
