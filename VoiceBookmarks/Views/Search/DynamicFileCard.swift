//
//  DynamicFileCard.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

struct DynamicFileCard: View {
    private let logger = LoggerService.shared
    
    let bookmark: Bookmark
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: bookmark.contentType.iconName)
                .font(.system(size: safeIconSize, weight: .semibold))
                .foregroundColor(.gold)
                .frame(
                    width: safeIconSize,
                    height: safeIconSize
                )
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(bookmark.fileName)
                    .font(.headline)
                    .foregroundColor(.appText)
                    .lineLimit(2)
                
                Text(contentTypeDisplayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.appSecondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gold.opacity(0.15))
                    .cornerRadius(6)
                
                if hasAttachedFile && hasVoiceNote {
                    if hasSummary {
                        let _ = logger.debug("Отображение закладки '\(bookmark.fileName)': показываем описание (есть файл и голосовая заметка)", category: .ui)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.caption2)
                                    .foregroundColor(.gold)
                                Text("Описание:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.appSecondaryText)
                            }
                            Text(bookmark.summary!)
                                .font(.subheadline)
                                .foregroundColor(.appText.opacity(0.8))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 2)
                    } else if hasVoiceNote {
                        let _ = logger.debug("Отображение закладки '\(bookmark.fileName)': показываем голосовую заметку (есть файл, но нет описания)", category: .ui)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "mic.fill")
                                    .font(.caption2)
                                    .foregroundColor(.gold)
                                Text("Заметка:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.appSecondaryText)
                            }
                            Text(bookmark.voiceNote!)
                                .font(.subheadline)
                                .foregroundColor(.appText.opacity(0.8))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 2)
                    }
                } else if !hasAttachedFile && hasVoiceNote {
                    let _ = logger.debug("Отображение закладки '\(bookmark.fileName)': показываем голосовую заметку (нет файла)", category: .ui)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.caption2)
                                .foregroundColor(.gold)
                            Text("Заметка:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.appSecondaryText)
                        }
                        Text(bookmark.voiceNote!)
                            .font(.subheadline)
                            .foregroundColor(.appText.opacity(0.8))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                } else if hasAttachedFile && !hasVoiceNote {
                    if hasSummary {
                        let _ = logger.debug("Отображение закладки '\(bookmark.fileName)': показываем описание (есть файл, нет голосовой заметки)", category: .ui)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.caption2)
                                    .foregroundColor(.gold)
                                Text("Описание:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.appSecondaryText)
                            }
                            Text(bookmark.summary!)
                                .font(.subheadline)
                                .foregroundColor(.appText.opacity(0.8))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 2)
                    }
                } else if hasVoiceNote {
                    let _ = logger.debug("Отображение закладки '\(bookmark.fileName)': показываем голосовую заметку (fallback)", category: .ui)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.caption2)
                                .foregroundColor(.gold)
                            Text("Заметка:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.appSecondaryText)
                        }
                        Text(bookmark.voiceNote!)
                            .font(.subheadline)
                            .foregroundColor(.appText.opacity(0.8))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                } else if hasSummary {
                    let _ = logger.debug("Отображение закладки '\(bookmark.fileName)': показываем описание (fallback)", category: .ui)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundColor(.gold)
                            Text("Описание:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.appSecondaryText)
                        }
                        Text(bookmark.summary!)
                            .font(.subheadline)
                            .foregroundColor(.appText.opacity(0.8))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                } else if !bookmark.displayDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.caption2)
                                .foregroundColor(.gold.opacity(0.7))
                            Text("Заметка:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.appSecondaryText.opacity(0.7))
                        }
                        Text(bookmark.displayDescription)
                            .font(.subheadline)
                            .foregroundColor(.appText.opacity(0.8))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(Constants.UI.cardPadding)
        .cardStyle()
        .frame(minHeight: safeMinHeight)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(bookmark.fileName)
        .accessibilityIdentifier("FileCard_\(bookmark.id)")
    }
    
    private var contentTypeDisplayName: String {
        switch bookmark.contentType {
        case .text: return "Текст"
        case .audio: return "Аудио"
        case .video: return "Видео"
        case .image: return "Изображение"
        case .file: return "Файл"
        }
    }
    
    private var iconSize: CGFloat {
        bookmark.contentType.iconSize
    }
    
    private var safeIconSize: CGFloat {
        let size = iconSize
        return size.isFinite && size > 0 ? size : 32
    }
    
    private var minHeight: CGFloat {
        bookmark.contentType.cardMinHeight
    }
    
    private var safeMinHeight: CGFloat {
        let height = minHeight
        return height.isFinite && height > 0 ? height : 80
    }
    
    
    /// Определяет, есть ли прикрепленный файл (не голосовая заметка)
    private var hasAttachedFile: Bool {
        if let fileUrl = bookmark.fileUrl, !fileUrl.isEmpty {
            return true
        }
        if bookmark.contentType != .text {
            return true
        }
        if bookmark.fileName != "voice_note.txt" {
            return true
        }
        return false
    }
    
    /// Проверяет наличие voiceNote (не пустой после trim)
    /// Проверяем напрямую bookmark.voiceNote, не через displayDescription
    private var hasVoiceNote: Bool {
        guard let voiceNote = bookmark.voiceNote else {
            logger.debug("DynamicFileCard: voiceNote отсутствует для \(bookmark.fileName)", category: .ui)
            return false
        }
        let trimmed = voiceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            logger.debug("DynamicFileCard: voiceNote пустой (только пробелы) для \(bookmark.fileName)", category: .ui)
            return false
        }
        logger.debug("DynamicFileCard: voiceNote найден для \(bookmark.fileName): \(trimmed.prefix(50))...", category: .ui)
        return true
    }
    
    /// Проверяет наличие summary (не пустой после trim)
    private var hasSummary: Bool {
        guard let summary = bookmark.summary else { return false }
        return !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}


