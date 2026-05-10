//
//  Bookmark.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Bookmark model: normalizes `ContentType` from extension and payload; prefers `voiceNote…

struct Bookmark: Codable, Identifiable {
    let id: String
    let fileName: String
    let contentType: ContentType
    let category: String
    let voiceNote: String?
    let fileUrl: String?
    let summary: String?
    let content: String?
    let contentHash: String?
    let timestamp: Date
    let totalChunks: Int?
    let distance: Double?
    
    
    /// User-visible caption: `voiceNote` wins over `summary` when present.
    var displayDescription: String {
        if let voiceNote = voiceNote, !voiceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return voiceNote
        }
        return summary ?? ""
    }
    
    /// Estimated row height from icon size and optional description text.
    var dynamicHeight: CGFloat {
        let baseHeight: CGFloat = 80
        let iconHeight = contentType.iconSize
        let textHeight: CGFloat = displayDescription.isEmpty ? 0 : 40
        return baseHeight + iconHeight + textHeight
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case fileName
        case contentType
        case category
        case voiceNote
        case fileUrl
        case summary
        case content
        case contentHash
        case timestamp
        case totalChunks
        case distance
    }

    init(
        id: String,
        fileName: String,
        contentType: ContentType,
        category: String,
        voiceNote: String?,
        fileUrl: String?,
        summary: String?,
        content: String?,
        contentHash: String?,
        timestamp: Date,
        totalChunks: Int?,
        distance: Double?
    ) {
        self.id = id
        self.fileName = fileName
        self.contentType = Bookmark.normalizeContentType(
            rawType: contentType,
            fileName: fileName,
            fileUrl: fileUrl,
            content: content
        )
        self.category = category
        self.voiceNote = voiceNote
        self.fileUrl = fileUrl
        self.summary = summary
        self.content = content
        self.contentHash = contentHash
        self.timestamp = timestamp
        self.totalChunks = totalChunks
        self.distance = distance
    }
    
    
    /// Decodes JSON and normalizes `ContentType`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let id = try container.decode(String.self, forKey: .id)
        let fileName = try container.decode(String.self, forKey: .fileName)
        let rawContentType = try container.decode(ContentType.self, forKey: .contentType)
        let category = try container.decode(String.self, forKey: .category)
        let voiceNote = try container.decodeIfPresent(String.self, forKey: .voiceNote)
        let fileUrl = try container.decodeIfPresent(String.self, forKey: .fileUrl)
        let summary = try container.decodeIfPresent(String.self, forKey: .summary)
        let content = try container.decodeIfPresent(String.self, forKey: .content)
        let contentHash = try container.decodeIfPresent(String.self, forKey: .contentHash)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let totalChunks = try container.decodeIfPresent(Int.self, forKey: .totalChunks)
        let distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        
        self.init(
            id: id,
            fileName: fileName,
            contentType: rawContentType,
            category: category,
            voiceNote: voiceNote,
            fileUrl: fileUrl,
            summary: summary,
            content: content,
            contentHash: contentHash,
            timestamp: timestamp,
            totalChunks: totalChunks,
            distance: distance
        )
    }
    
    
    /// Normalizes stored type using filename/url first, then payload heuristics (data URLs, HTML).
    private static func normalizeContentType(
        rawType: ContentType,
        fileName: String,
        fileUrl: String?,
        content: String?
    ) -> ContentType {
        let extensionType = bestTypeFromExtensions(fileName: fileName, fileUrl: fileUrl)
        
        if extensionType != .file && extensionType != rawType {
            return extensionType
        }
        
        if extensionType != .file {
            return extensionType
        }
        
        if rawType == .text || rawType == .file {
            if let inferred = inferTypeFromContent(content) {
                return inferred
            }
        }
        
        return rawType
    }
    
    /// Infers type from extensions present in `fileName` and `fileUrl`.
    private static func bestTypeFromExtensions(fileName: String, fileUrl: String?) -> ContentType {
        var extensionsToCheck: [String] = []
        
        let fileNameExtension = (fileName as NSString).pathExtension
        if !fileNameExtension.isEmpty {
            extensionsToCheck.append(fileNameExtension)
        }
        
        if let fileUrlString = fileUrl {
            if let remoteURL = URL(string: fileUrlString), !remoteURL.pathExtension.isEmpty {
                extensionsToCheck.append(remoteURL.pathExtension)
            }
            
            let localURL = URL(fileURLWithPath: fileUrlString)
            let localExtension = localURL.pathExtension
            if !localExtension.isEmpty {
                extensionsToCheck.append(localExtension)
            }
        }
        
        for ext in extensionsToCheck {
            let type = ContentType.fromFileExtension(ext)
            if type != .file {
                return type
            }
        }
        
        return .file
    }
    
    /// Fallback type detection from inline content (data URLs, `<img>` / `<audio>` / `<video>` hints).
    private static func inferTypeFromContent(_ content: String?) -> ContentType? {
        guard let contentLowercased = content?.lowercased() else { return nil }
        
        if contentLowercased.hasPrefix("data:audio/") || contentLowercased.contains("<audio") {
            return .audio
        }
        
        if contentLowercased.hasPrefix("data:video/") || contentLowercased.contains("<video") {
            return .video
        }
        
        if contentLowercased.hasPrefix("data:image/") || contentLowercased.contains("<img") {
            return .image
        }
        
        if contentLowercased.hasPrefix("http://") || contentLowercased.hasPrefix("https://") {
            let urlExt = URL(string: contentLowercased)?.pathExtension ?? ""
            let type = ContentType.fromFileExtension(urlExt)
            return type == .file ? nil : type
        }
        
        return nil
    }
}
