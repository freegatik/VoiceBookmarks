//
//  FileService.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import AVFoundation
import CommonCrypto

struct FileValidationResult {
    let isValid: Bool
    let contentType: ContentType
    let fileSize: Int64
    let errorMessage: String?
}

protocol FileServiceProtocol {
    func validateFile(at url: URL) throws -> FileValidationResult
    #if canImport(UIKit)
    func compressImage(_ image: UIImage) -> Data?
    #else
    func compressImage(_ imageData: Data) -> Data?
    #endif
    func compressVideo(at url: URL, completion: @escaping (URL?, Error?) -> Void)
    func saveToTemporaryDirectory(data: Data, fileName: String) -> URL?
    func copyToAppGroupContainer(from url: URL) throws -> URL
    func getFileSize(at url: URL) -> Int64?
    func deleteFile(at url: URL)
    func generateFileName(originalName: String, contentType: ContentType) -> String
}

/// Работа с файлами: валидация, сжатие изображений/видео, хэширование, временные файлы, App Group
/// 
/// Основные функции:
/// - Валидация файлов (размер, тип, существование)
/// - Сжатие изображений (до 2048px, JPEG)
/// - Сжатие видео (AVAssetExportPresetMediumQuality)
/// - Вычисление SHA-256 хэша для проверки дубликатов
/// - Работа с App Group контейнером для обмена файлами между приложением и Share Extension
class FileService: FileServiceProtocol {
    
    static let shared = FileService()
    private let logger = LoggerService.shared
    
    private init() {}
    
    
    /// Вычисляет SHA-256 хэш файла по частям (для больших файлов, читает по 1MB за раз)
    /// Используется для проверки дубликатов по содержимому, а не по имени файла
    func computeContentHash(url: URL, chunkSize: Int = 1_048_576) -> String? {
        guard let stream = InputStream(url: url) else { return nil }
        stream.open()
        defer { stream.close() }
        
        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)
        
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { buffer.deallocate() }
        
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: chunkSize)
            if read < 0 { return nil }
            if read == 0 { break }
            CC_SHA256_Update(&context, buffer, CC_LONG(read))
        }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Вычисляет SHA-256 хэш данных (для небольших файлов)
    /// Более быстрый вариант для файлов, которые уже загружены в память
    func computeContentHash(data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    
    /// Валидация файла: проверка существования, размера (макс 500MB), определение типа контента
    func validateFile(at url: URL) throws -> FileValidationResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.error("Файл не существует: \(url.path)", category: .fileOperation)
            return FileValidationResult(isValid: false, contentType: .file, fileSize: 0, errorMessage: "Файл не найден")
        }
        
        guard let fileSize = getFileSize(at: url) else {
            return FileValidationResult(isValid: false, contentType: .file, fileSize: 0, errorMessage: "Не удалось определить размер")
        }
        
        if fileSize > Constants.Files.maxSizeBytes {
            logger.error("Файл слишком большой: \(fileSize) bytes", category: .fileOperation)
            return FileValidationResult(
                isValid: false,
                contentType: .file,
                fileSize: fileSize,
                errorMessage: "Файл превышает 500MB"
            )
        }
        
        let ext = url.pathExtension.lowercased()
        let detectedContentType = determineContentType(extension: ext)
        
        logger.info("Файл валиден: \(url.lastPathComponent), размер: \(fileSize) bytes, тип: \(detectedContentType)", category: .fileOperation)
        
        return FileValidationResult(isValid: true, contentType: detectedContentType, fileSize: fileSize, errorMessage: nil)
    }
    
    
    #if canImport(UIKit)
    /// Уменьшает изображение до 2048px и сжимает в JPEG
    /// Оптимизирует размер файла для быстрой загрузки на сервер
    func compressImage(_ image: UIImage) -> Data? {
        guard image.size.width > 0 && image.size.height > 0,
              image.size.width.isFinite && image.size.height.isFinite else {
            logger.error("Невалидный размер изображения: width=\(image.size.width), height=\(image.size.height)", category: .fileOperation)
            return nil
        }
        
        let targetMax: CGFloat = 2048
        let maxDimension = max(image.size.width, image.size.height)
        guard maxDimension > 0 && maxDimension.isFinite else {
            logger.error("Невалидная максимальная размерность: \(maxDimension)", category: .fileOperation)
            return nil
        }
        
        if maxDimension > targetMax {
            let scale = targetMax / maxDimension
            guard scale > 0 && scale.isFinite else {
                logger.error("Невалидный scale: \(scale)", category: .fileOperation)
                return nil
            }
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            
            return autoreleasepool { () -> Data? in
                UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
                defer { UIGraphicsEndImageContext() }
                image.draw(in: CGRect(origin: .zero, size: newSize))
                guard let scaled = UIGraphicsGetImageFromCurrentImageContext() else {
                    logger.error("Не удалось создать уменьшенное изображение", category: .fileOperation)
                    return nil
                }
                logger.debug("Изображение даунскейлено до \(Int(newSize.width))x\(Int(newSize.height))", category: .fileOperation)
                
                guard let data = scaled.jpegData(compressionQuality: Constants.Files.compressionQuality) else {
                    logger.error("Не удалось сжать изображение", category: .fileOperation)
                    return nil
                }
                
                logger.info("Изображение сжато: \(data.count) bytes", category: .fileOperation)
                return data
            }
        } else {
            guard let data = image.jpegData(compressionQuality: Constants.Files.compressionQuality) else {
                logger.error("Не удалось сжать изображение", category: .fileOperation)
                return nil
            }
            
            logger.info("Изображение сжато (без даунскейла): \(data.count) bytes", category: .fileOperation)
            return data
        }
    }
    #else
    func compressImage(_ imageData: Data) -> Data? {
        logger.warning("UIKit недоступен, возвращаем исходные данные", category: .fileOperation)
        return imageData
    }
    #endif
    
    
    /// Сжимает видео до среднего качества (AVAssetExportPresetMediumQuality)
    /// Асинхронная операция, результат возвращается через completion handler
    func compressVideo(at url: URL, completion: @escaping (URL?, Error?) -> Void) {
        
        let asset = AVAsset(url: url)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetMediumQuality
        ) else {
            let error = NSError(domain: "FileService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать export session"])
            logger.error("Error создания export session", category: .fileOperation)
            completion(nil, error)
            return
        }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        
        let originalSize = getFileSize(at: url) ?? 0
        logger.debug("Размер до сжатия: \(originalSize) bytes", category: .fileOperation)
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    let compressedSize = self.getFileSize(at: outputURL) ?? 0
                    let ratio: Double
                    if originalSize > 0 {
                        ratio = Double(compressedSize) / Double(originalSize) * 100
                    } else {
                        ratio = 0
                    }
                    self.logger.info("Видео сжато: \(originalSize) -> \(compressedSize) bytes (\(String(format: "%.1f", ratio))%)", category: .fileOperation)
                    completion(outputURL, nil)
                    
                case .failed, .cancelled:
                    self.logger.error("Error сжатия видео: \(exportSession.error?.localizedDescription ?? "unknown")", category: .fileOperation)
                    completion(nil, exportSession.error)
                    
                default:
                    break
                }
            }
        }
    }
    
    
    /// Сохранение данных во временную директорию
    func saveToTemporaryDirectory(data: Data, fileName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: url)
            logger.info("Файл сохранен в temp: \(fileName)", category: .fileOperation)
            return url
        } catch {
            logger.error("Error сохранения в temp: \(error)", category: .fileOperation)
            return nil
        }
    }
    
    
    /// Копирует файл в App Group контейнер (для обмена между основным приложением и Share Extension)
    /// Share Extension не может напрямую передавать файлы в основное приложение, поэтому используется App Group
    func copyToAppGroupContainer(from url: URL) throws -> URL {
        let appGroupIdentifier = Constants.AppGroups.identifier
        logger.info("Попытка получить App Group container с identifier: \(appGroupIdentifier)", category: .fileOperation)
        logger.info("Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")", category: .fileOperation)
        
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            let errorMessage = "App Group container недоступен для identifier '\(appGroupIdentifier)'. Проверьте, что:\n1. App Group настроен в Capabilities для основного приложения и Share Extension\n2. Bundle ID и App Group identifier совпадают в entitlements\n3. App Group зарегистрирован в Apple Developer Portal"
            logger.error(errorMessage, category: .fileOperation)
            logger.error("Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")", category: .fileOperation)
            throw APIError.serverError(message: "App Group container недоступен. Проверьте entitlements и настройки App Group в Xcode.")
        }
        
        logger.info("App Group container получен: \(containerURL.path)", category: .fileOperation)
        
        let filesDir = containerURL.appendingPathComponent("Files")
        let uniqueName = "\(UUID().uuidString.prefix(8))_\(url.lastPathComponent)"
        let destinationURL = filesDir.appendingPathComponent(uniqueName)
        
        logger.info("Создание директории Files в App Group: \(filesDir.path)", category: .fileOperation)
        do {
            try FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Error создания директории Files в App Group: \(error)", category: .fileOperation)
            throw error
        }
        
        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            logger.info("Файл скопирован в App Group: \(destinationURL.lastPathComponent)", category: .fileOperation)
            return destinationURL
        } catch {
            logger.error("Error копирования файла в App Group: \(error)", category: .fileOperation)
            throw error
        }
    }
    
    func getFileSize(at url: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            logger.error("Error получения размера файла: \(error)", category: .fileOperation)
            return nil
        }
    }
    
    func deleteFile(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("Файл уже удален или не существует: \(url.lastPathComponent)", category: .fileOperation)
            return
        }
        
        do {
            try FileManager.default.removeItem(at: url)
            logger.info("Файл удален: \(url.lastPathComponent)", category: .fileOperation)
        } catch {
            if (error as NSError).code == NSFileNoSuchFileError || (error as NSError).code == 2 {
                logger.info("Файл уже был удален: \(url.lastPathComponent)", category: .fileOperation)
            } else {
                logger.error("Error удаления файла: \(error)", category: .fileOperation)
            }
        }
    }
    
    func generateFileName(originalName: String, contentType: ContentType) -> String {
        let uuid = UUID().uuidString.prefix(8)
        let ext = (originalName as NSString).pathExtension
        let nameWithoutExt = (originalName as NSString).deletingPathExtension
        
        if ext.isEmpty {
            return "\(uuid)_\(nameWithoutExt)"
        } else {
            return "\(uuid)_\(nameWithoutExt).\(ext)"
        }
    }
    
    private func determineContentType(extension ext: String) -> ContentType {
        return ContentType.fromFileExtension(ext)
    }
}
