//
//  ShareExtensionViewModel.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
import Combine

// MARK: - ViewModel для Share Extension UI: состояние загрузки, успех/ошибка, сообщения

public class ShareExtensionViewModel: ObservableObject {
    @Published public var isLoading = true
    @Published public var statusMessage = "Добавление контента..."
    @Published public var showSuccess = false
    @Published public var showError = false
    @Published public var errorMessage: String?
    
    
    /// Обновление статуса загрузки: устанавливает сообщение и состояние (успех/ошибка)
    public func updateStatus(message: String, isSuccess: Bool) {
        DispatchQueue.main.async {
            self.statusMessage = message
            if isSuccess {
                self.isLoading = false
                self.showSuccess = true
                self.showError = false
                self.errorMessage = nil
            }
        }
    }
    
    /// Показ ошибки: устанавливает сообщение об ошибке и скрывает индикатор загрузки
    public func showError(_ message: String) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.statusMessage = message
            self.showError = true
            self.errorMessage = message
        }
    }
}

