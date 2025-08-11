//
//  ContentType.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
import Foundation
import CoreGraphics

/// Тип контента: текст, аудио, видео, изображение, файл (иконки и размеры для UI)
/// 
/// Архитектура:
/// - Определение типа по расширению файла (fromFileExtension)
/// - UI свойства: иконки (iconName), размеры иконок (iconSize), минимальная высота карточки (cardMinHeight)
/// - Поддержка различных форматов для каждого типа контента
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import CoreGraphics

// MARK: - Content kind for bookmarks: text, audio, video, image, file (icons and layout hints).

enum ContentType: String, Codable {
    case text
    case audio
    case video
    case image
    case file
    
    
    /// Определяет тип контента по расширению файла
    /// Поддерживает широкий спектр форматов для каждого типа
    static func fromFileExtension(_ ext: String) -> ContentType {
        let lowercased = ext.lowercased()
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff", "tif", "webp"]
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "opus", "aiff", "aif", "caf"]
        let textExtensions = ["txt", "md", "doc", "docx", "html", "htm", "rtf", "log"]
        let documentExtensions = ["pdf"]
        
        if imageExtensions.contains(lowercased) {
            return .image
        } else if videoExtensions.contains(lowercased) {
            return .video
        } else if audioExtensions.contains(lowercased) {
            return .audio
        } else if textExtensions.contains(lowercased) {
            return .text
        } else if documentExtensions.contains(lowercased) {
            return .file
        } else {
            return .file
        }
    }
    
    
    /// Имя иконки SF Symbols для отображения в UI
    var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .audio: return "waveform"
        case .video: return "video"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
    
    /// Размер иконки в пикселях (зависит от типа контента)
    var iconSize: CGFloat {
        switch self {
        case .text: return 32
        case .audio: return 44
        case .image: return 52
        case .video: return 60
        case .file: return 40
        }
    }
    
    /// Минимальная высота карточки в UI (зависит от типа контента)
    var cardMinHeight: CGFloat {
        switch self {
        case .text: return 96
        case .audio: return 112
        case .image: return 128
        case .video: return 140
        case .file: return 104
        }
    }
}
