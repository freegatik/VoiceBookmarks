//
//  BookmarkService.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - Создание и удаление закладок: валидация, сжатие, проверка дубликатов по хэшу
class BookmarkService {
    
    private let networkService: NetworkService
    private let fileService: FileServiceProtocol
    private let logger = LoggerService.shared
    
    init(
        networkService: NetworkService = NetworkService(),
        fileService: FileServiceProtocol = FileService.shared
    ) {
        self.networkService = networkService
        self.fileService = fileService
    }
    
    
    /// Создает закладку: валидация, сжатие видео/изображений, проверка дубликатов (24ч окно)
    /// Возвращает true при успехе или если файл уже был загружен (дубликат)
    func createBookmark(filePath: String, voiceNote: String?, summary: String?) async throws -> Bool {
        let fileURL = URL(fileURLWithPath: filePath)
        let validation = try fileService.validateFile(at: fileURL)
        
        guard validation.isValid else {
            logger.error("Файл не прошел валидацию: \(validation.errorMessage ?? "неизвестная ошибка")", category: .fileOperation)
            throw APIError.serverError(message: validation.errorMessage ?? "Файл невалиден")
        }
        
        var fileData: Data
        var effectiveFileURL = fileURL
        
        if validation.contentType == .video {
            let compressedURL: URL? = await withCheckedContinuation { continuation in
                fileService.compressVideo(at: fileURL) { url, _ in
                    continuation.resume(returning: url)
                }
            }
            if let compressedURL = compressedURL {
                effectiveFileURL = compressedURL
                logger.info("Используем сжатое видео для загрузки: \(compressedURL.lastPathComponent)", category: .fileOperation)
            } else {
                logger.warning("Не удалось сжать видео, отправляем оригинал", category: .fileOperation)
            }
        }
        
        do {
            let fileSize = try FileManager.default.attributesOfItem(atPath: effectiveFileURL.path)[.size] as? Int64 ?? 0
            if fileSize > 10 * 1024 * 1024 {
                fileData = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: effectiveFileURL)
                }.value
            } else {
                fileData = try Data(contentsOf: effectiveFileURL)
            }
        } catch {
            logger.error("Ошибка чтения файла: \(error)", category: .fileOperation)
            throw error
        }
        
        let preHash = FileService.shared.computeContentHash(data: fileData)
        #if !os(macOS)
        let isShareExtension = Bundle.main.bundleURL.pathExtension == "appex"
        if !isShareExtension {
            if RecentHashCache.shared.isRecent(hash: preHash, within: 24 * 3600) {
                logger.warning("Дубликат контента по хэшу (24ч окно), пропускаем upload", category: .fileOperation)
                return true
            }
        }
        #endif
        
        #if canImport(UIKit)
        if validation.contentType == .image, let image = UIImage(data: fileData) {
            if let compressed = fileService.compressImage(image) {
                fileData = compressed
                logger.info("Изображение сжато: \(fileData.count) bytes", category: .fileOperation)
            }
        }
        #endif
        
        if fileData.count > Constants.Files.maxSizeBytes {
            throw APIError.serverError(message: "Файл превышает 500MB даже после сжатия")
        }
        
        let fileName = effectiveFileURL.lastPathComponent
        let isHTMLFile = fileName.lowercased().hasSuffix(".html") || fileName.lowercased().hasSuffix(".htm")
        let contentTypeToSend = (isHTMLFile && validation.contentType == .text) ? ContentType.file : validation.contentType
        
        var params: [String: String] = [
            "content": fileName,
            "contentType": contentTypeToSend.rawValue,
            "category": Constants.Categories.defaultCategory,
            "fileName": fileName
        ]
        
        let contentHash = preHash
        params["contentHash"] = contentHash
        if let voiceNote = voiceNote, !voiceNote.isEmpty {
            params["voiceNote"] = voiceNote
            logger.info("Голосовая заметка будет отправлена: \(voiceNote.count) символов", category: .fileOperation)
        } else {
            logger.debug("Голосовая заметка отсутствует или пуста, не отправляется", category: .fileOperation)
        }
        if let summary = summary, !summary.isEmpty {
            params["summary"] = summary
            logger.info("Описание будет отправлено: \(summary.count) символов", category: .fileOperation)
        } else {
            logger.debug("Описание отсутствует или пусто, не отправляется", category: .fileOperation)
        }
        
        let hasVoiceNote = params["voiceNote"] != nil
        let hasSummary = params["summary"] != nil
        logger.info("Параметры для создания закладки: голосовая заметка \(hasVoiceNote ? "\(params["voiceNote"]!.count) символов" : "отсутствует"), описание \(hasSummary ? "\(params["summary"]!.count) символов" : "отсутствует"), файл \(fileName)", category: .fileOperation)

        logger.info("Подготовка к загрузке файла: fileName=\(fileName), размер=\(fileData.count) байт, contentType=\(contentTypeToSend.rawValue)", category: .fileOperation)
        
        do {
            let responseData = try await networkService.upload(
                data: fileData,
                fileName: fileName,
                endpoint: Constants.API.Endpoints.bookmarks,
                parameters: params
            )
            #if !os(macOS)
            let isShareExtension = Bundle.main.bundleURL.pathExtension == "appex"
            if !isShareExtension {
                RecentHashCache.shared.record(hash: contentHash)
            }
            #endif

            struct CreateResponse: Codable { let success: Bool; let message: String?; let bookmarkId: String? }
            
            let decoded: CreateResponse
            do {
                decoded = try JSONDecoder().decode(CreateResponse.self, from: responseData)
            } catch {
                logger.error("Ошибка декодирования ответа API при создании закладки: \(error)", category: .network)
                logger.error("Ответ сервера (первые 500 символов): \(String(data: responseData.prefix(500), encoding: .utf8) ?? "не удалось декодировать")", category: .network)
                throw APIError.decodingError(error)
            }
            
            if decoded.success {
                let bookmarkId = decoded.bookmarkId ?? "не указан"
                
                if bookmarkId == "не указан" || bookmarkId.isEmpty {
                    logger.error("КРИТИЧНО: bookmarkId не получен от сервера после успешной загрузки файла: fileName=\(fileName), размер=\(fileData.count) байт", category: .fileOperation)
                } else {
                    logger.info("Закладка создана успешно: bookmarkId=\(bookmarkId), fileName=\(fileName), размер=\(fileData.count) байт, contentType=\(contentTypeToSend.rawValue)", category: .fileOperation)
                    
                    Task {
                        await verifyFileAvailability(bookmarkId: bookmarkId, fileName: fileName)
                    }
                }
                
                return true
            } else {
                let errorMessage = decoded.message ?? "Ответ API неуспешный"
                logger.warning("Ответ API неуспешный: success=false, message=\(errorMessage)", category: .network)
                throw APIError.serverError(message: errorMessage)
            }
        } catch {
            let errorDetails: String
            if let apiError = error as? APIError {
                switch apiError {
                case .noData:
                    errorDetails = "noData"
                case .httpError(let statusCode):
                    errorDetails = "HTTP \(statusCode)"
                case .serverError(let message):
                    errorDetails = "serverError: \(message)"
                case .networkError(let underlyingError):
                    let nsError = underlyingError as NSError
                    errorDetails = "networkError: domain=\(nsError.domain), code=\(nsError.code), description=\(nsError.localizedDescription)"
                case .decodingError(let underlyingError):
                    errorDetails = "decodingError: \(underlyingError.localizedDescription)"
                case .unauthorized:
                    errorDetails = "unauthorized"
                }
            } else {
                let nsError = error as NSError
                errorDetails = "unknownError: domain=\(nsError.domain), code=\(nsError.code), description=\(nsError.localizedDescription)"
            }
            logger.error("Ошибка создания закладки: fileName=\(fileName), размер=\(fileData.count) байт, contentType=\(contentTypeToSend.rawValue), ошибка: \(errorDetails)", category: .fileOperation)
            throw error
        }
    }
    
    
    /// Проверяет доступность файла после создания закладки (опционально, в фоне)
    private func verifyFileAvailability(bookmarkId: String, fileName: String) async {
        try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 секунды
        
        do {
            let _ = try await networkService.downloadFile(bookmarkId: bookmarkId)
            logger.info("Проверка доступности файла успешна: bookmarkId=\(bookmarkId), fileName=\(fileName)", category: .fileOperation)
        } catch {
            logger.warning("Файл недоступен для загрузки после создания: bookmarkId=\(bookmarkId), fileName=\(fileName), ошибка: \(error.localizedDescription). Возможно, файл еще обрабатывается на сервере.", category: .fileOperation)
        }
    }
    
    
    /// Удаление закладки по ID через API
    func deleteBookmark(id: String) async throws -> Bool {
        logger.info("Удаление закладки: \(id)", category: .network)
        
        struct DeleteResponse: Codable {
            let success: Bool
            let message: String?
        }
        
        let response: DeleteResponse = try await networkService.request(
            endpoint: "\(Constants.API.Endpoints.bookmarks)/\(id)",
            method: "DELETE"
        )
        
        logger.info("Закладка удалена: \(response.success)", category: .network)
        return response.success
    }
}

