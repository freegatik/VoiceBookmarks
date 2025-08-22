//
//  WKWebViewConfiguration+Extensions.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import WebKit

// MARK: - Конфигурации WebView: файлы (доступ к файлам), команды (стандартная)

extension WKWebViewConfiguration {
    
    
    /// Конфигурация для просмотра файлов (PDF, изображения, видео, аудио)
    /// Включает inline media playback для автоматического воспроизведения медиа
    static func filePreviewConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        #endif
        return config
    }
    
    /// Конфигурация для рендеринга HTML команд (результаты поиска)
    /// Включает JavaScript для интерактивных HTML страниц
    static func htmlRenderConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        #endif
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        
        return config
    }
}
