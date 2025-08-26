//
//  ClipboardService.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#endif

struct ClipboardContent {
    let type: ClipboardType
    let text: String?
    let url: URL?
#if canImport(UIKit)
    let image: UIImage?
#else
    let image: Data?
#endif
    let fileURL: URL?
    
#if canImport(UIKit)
    init(type: ClipboardType, text: String?, url: URL?, image: UIImage?, fileURL: URL? = nil) {
        self.type = type
        self.text = text
        self.url = url
        self.image = image
        self.fileURL = fileURL
    }
#else
    init(type: ClipboardType, text: String?, url: URL?, image: Data?, fileURL: URL? = nil) {
        self.type = type
        self.text = text
        self.url = url
        self.image = image
        self.fileURL = fileURL
    }
#endif
    
    enum ClipboardType {
        case text
        case url
        case image
        case unknown
    }
}

protocol ClipboardServiceProtocol {
    func getClipboardContent() -> ClipboardContent?
    func getClipboardContentAsync() async -> ClipboardContent?
    func hasContent() -> Bool
    func clearClipboard()
}

// MARK: - Чтение буфера обмена: приоритет URL > изображение > файлы > текст, асинхронная загрузка…
class ClipboardService: ClipboardServiceProtocol {
    
    static let shared = ClipboardService()
    
    private let logger = LoggerService.shared
    
    private init() {}
    
    
    /// Определяет расширение файла из UTType идентификатора (fallback на известные типы)
    /// Используется для правильного сохранения файлов из буфера обмена
    private func getFileExtension(from typeIdentifier: String) -> String? {
        if let utType = UTType(typeIdentifier) {
            if let preferredExtension = utType.preferredFilenameExtension {
                return preferredExtension
            }
            
            if let tags = utType.tags[.filenameExtension], let firstTag = tags.first {
                return firstTag
            }
        }
        
        let typeLower = typeIdentifier.lowercased()
        
        if typeLower.contains("pdf") || typeIdentifier == "com.adobe.pdf" {
            return "pdf"
        }
        
        if typeLower.contains("image") || typeIdentifier.hasPrefix("public.image") {
            if typeLower.contains("jpeg") || typeLower.contains("jpg") {
                return "jpg"
            } else if typeLower.contains("png") {
                return "png"
            } else if typeLower.contains("heic") || typeLower.contains("heif") {
                return "heic"
            } else if typeLower.contains("gif") {
                return "gif"
            } else if typeLower.contains("webp") {
                return "webp"
            }
            return "jpg" // fallback для изображений
        }
        
        if typeLower.contains("movie") || typeLower.contains("video") || typeIdentifier.hasPrefix("public.movie") {
            if typeLower.contains("mp4") {
                return "mp4"
            } else if typeLower.contains("mov") {
                return "mov"
            } else if typeLower.contains("m4v") {
                return "m4v"
            }
            return "mp4" // fallback для видео
        }
        
        if typeLower.contains("audio") || typeIdentifier.hasPrefix("public.audio") {
            if typeLower.contains("m4a") {
                return "m4a"
            } else if typeLower.contains("mp3") {
                return "mp3"
            } else if typeLower.contains("wav") {
                return "wav"
            } else if typeLower.contains("aac") {
                return "aac"
            } else if typeLower.contains("flac") {
                return "flac"
            }
            return "m4a" // fallback для аудио
        }
        
        if typeLower.contains("text") || typeIdentifier.hasPrefix("public.text") {
            if typeLower.contains("plain") {
                return "txt"
            } else if typeLower.contains("markdown") || typeLower.contains("md") {
                return "md"
            } else if typeLower.contains("html") || typeLower.contains("htm") {
                return "html"
            } else if typeLower.contains("rtf") {
                return "rtf"
            }
            return "txt" // fallback для текста
        }
        
        if typeLower.contains("document") {
            if typeLower.contains("word") || typeLower.contains("docx") {
                return "docx"
            } else if typeLower.contains("doc") {
                return "doc"
            }
        }
        
        return nil
    }
    
    func hasContent() -> Bool {
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        
        if pasteboard.hasURLs || pasteboard.hasImages || pasteboard.hasStrings {
            logger.debug("Буфер содержит стандартные типы: URLs=\(pasteboard.hasURLs), Images=\(pasteboard.hasImages), Strings=\(pasteboard.hasStrings)", category: .storage)
            return true
        }
        
        logger.debug("Проверка items в буфере обмена: количество=\(pasteboard.items.count)", category: .storage)
        for (index, item) in pasteboard.items.enumerated() {
            let typeIdentifiers = Array(item.keys)
            logger.debug("Item \(index): типы=\(typeIdentifiers)", category: .storage)
            
            for typeIdentifier in typeIdentifiers {
                if typeIdentifier == "com.apple.is-remote-clipboard" {
                    continue
                }
                if typeIdentifier == UTType.fileURL.identifier || 
                   typeIdentifier == "public.file-url" ||
                   typeIdentifier == UTType.data.identifier ||
                   typeIdentifier == "public.data" ||
                   typeIdentifier.hasPrefix("public.") ||
                   typeIdentifier.hasPrefix("com.apple.") {
                    logger.debug("Найден потенциальный файл с типом: \(typeIdentifier)", category: .storage)
                    return true
                }
            }
        }
        
        logger.debug("Буфер обмена пустой", category: .storage)
        return false
        #else
        return false
        #endif
    }
    
    func getClipboardContent() -> ClipboardContent? {
        
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        
        if pasteboard.hasURLs, let url = pasteboard.url {
            if url.isFileURL {
                logger.info("Найден файл в буфере (file:// URL): \(url.absoluteString)", category: .storage)
                return ClipboardContent(type: .unknown, text: url.lastPathComponent, url: nil, image: nil, fileURL: url)
            } else {
            logger.info("Найден URL в буфере: \(url.absoluteString)", category: .storage)
            return ClipboardContent(type: .url, text: nil, url: url, image: nil)
            }
        }
        
        if pasteboard.hasImages, let originalImage = pasteboard.image {
            logger.info("Найдено изображение в буфере", category: .storage)
            
            let maxDimension: CGFloat = 2048
            let optimizedImage: UIImage
            if max(originalImage.size.width, originalImage.size.height) > maxDimension {
                let scale = maxDimension / max(originalImage.size.width, originalImage.size.height)
                let newSize = CGSize(width: originalImage.size.width * scale, height: originalImage.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                defer { UIGraphicsEndImageContext() }
                originalImage.draw(in: CGRect(origin: .zero, size: newSize))
                optimizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? originalImage
                logger.info("Изображение оптимизировано до \(Int(newSize.width))x\(Int(newSize.height))", category: .storage)
            } else {
                optimizedImage = originalImage
            }
            
            return ClipboardContent(type: .image, text: nil, url: nil, image: optimizedImage)
        }
        
        logger.debug("Проверка items для файлов: количество=\(pasteboard.items.count)", category: .storage)
        for (itemIndex, item) in pasteboard.items.enumerated() {
            logger.debug("Обработка item \(itemIndex), типы: \(Array(item.keys))", category: .storage)
            
            for (typeIdentifier, value) in item {
                logger.debug("Проверка типа: \(typeIdentifier), тип значения: \(type(of: value))", category: .storage)
                
                if typeIdentifier == UTType.fileURL.identifier || typeIdentifier == "public.file-url" {
                    var fileURL: URL?
                    
                    if let data = value as? Data,
                       let urlString = String(data: data, encoding: .utf8),
                       let url = URL(string: urlString),
                       url.isFileURL {
                        fileURL = url
                    }
                    else if let urlString = value as? String,
                            let url = URL(string: urlString),
                            url.isFileURL {
                        fileURL = url
                    }
                    
                    if let url = fileURL {
                        logger.info("Найден файл в буфере через fileURL: \(url.path)", category: .storage)
                        return ClipboardContent(type: .unknown, text: url.lastPathComponent, url: nil, image: nil, fileURL: url)
                    }
                }
                
                let isFileType = typeIdentifier == "com.adobe.pdf" ||
                                 typeIdentifier == "com.apple.DocumentManager.FPItem.File" ||
                                 typeIdentifier.hasPrefix("com.") ||
                                 typeIdentifier.hasPrefix("public.") ||
                                 typeIdentifier.hasSuffix(".File") ||
                                 typeIdentifier.hasSuffix(".pdf") ||
                                 typeIdentifier.hasSuffix(".image") ||
                                 typeIdentifier.hasSuffix(".movie") ||
                                 typeIdentifier.hasSuffix(".audio")
                
                if isFileType && typeIdentifier != "public.text" && 
                   typeIdentifier != "public.plain-text" && 
                   typeIdentifier != "public.utf8-plain-text" &&
                   typeIdentifier != "public.url" &&
                   typeIdentifier != UTType.url.identifier &&
                   typeIdentifier != UTType.text.identifier &&
                   typeIdentifier != "com.apple.is-remote-clipboard" {
                    logger.debug("Найден тип файла: \(typeIdentifier)", category: .storage)
                    
                    let fileExtension = getFileExtension(from: typeIdentifier) ?? "file"
                    logger.debug("Определено расширение файла: \(fileExtension) для типа \(typeIdentifier)", category: .storage)
                    
                    var fileData: Data? = nil
                    
                    if let data = value as? Data {
                        fileData = data
                    } else if let dispatchData = value as? DispatchData {
                        fileData = Data(dispatchData)
                    }
                    
                    if let data = fileData {
                        var originalFileName: String? = nil
                        
                        logger.debug("Поиск имени файла в item, доступные типы: \(Array(item.keys))", category: .storage)
                        
                        for (otherType, otherValue) in item {
                            logger.debug("Проверка типа для имени файла: \(otherType), тип значения: \(type(of: otherValue))", category: .storage)
                            
                            if otherType == "public.filename" || 
                               otherType == "public.file-name" ||
                               otherType == "com.apple.DocumentManager.FPItem.FileName" ||
                               otherType == "com.apple.DocumentManager.FPItem.DisplayName" ||
                               otherType.hasSuffix(".filename") ||
                               otherType.hasSuffix(".file-name") ||
                               otherType.contains("filename") ||
                               otherType.contains("FileName") ||
                               otherType.contains("DisplayName") {
                                
                                if let fileName = otherValue as? String {
                                    originalFileName = fileName
                                    logger.info("Найдено исходное имя файла из типа \(otherType): \(fileName)", category: .storage)
                                    break
                                }
                                
                                if let fileNameData = otherValue as? Data,
                                   let fileName = String(data: fileNameData, encoding: .utf8) {
                                    originalFileName = fileName
                                    logger.info("Найдено исходное имя файла из типа \(otherType) (как Data): \(fileName)", category: .storage)
                                    break
                                }
                                
                                if let dispatchData = otherValue as? DispatchData,
                                   let fileName = String(data: Data(dispatchData), encoding: .utf8) {
                                    originalFileName = fileName
                                    logger.info("Найдено исходное имя файла из типа \(otherType) (как DispatchData): \(fileName)", category: .storage)
                                    break
                                }
                            }
                        }
                        
                        if originalFileName == nil {
                            let providers = UIPasteboard.general.itemProviders
                            if !providers.isEmpty {
                                logger.info("Имя файла не найдено в item, переключаемся на асинхронную загрузку через NSItemProvider", category: .storage)
                                return nil
                            }
                        }
                        
                        let fileName: String
                        if let original = originalFileName {
                            let nameWithoutExt = (original as NSString).deletingPathExtension
                            let originalExt = (original as NSString).pathExtension.lowercased()
                            
                            if !originalExt.isEmpty && getFileExtension(from: "public.\(originalExt)") != nil {
                                fileName = original
                                logger.debug("Используем исходное имя файла с расширением: \(fileName)", category: .storage)
                            } else {
                                fileName = "\(nameWithoutExt).\(fileExtension)"
                                logger.debug("Используем исходное имя файла с новым расширением: \(fileName)", category: .storage)
                            }
                        } else {
                            fileName = "clipboard_file_\(UUID().uuidString).\(fileExtension)"
                            logger.debug("Генерируем новое имя файла: \(fileName)", category: .storage)
                        }
                        
                        if let url = FileService.shared.saveToTemporaryDirectory(data: data, fileName: fileName) {
                            logger.info("Найден файл в буфере через тип \(typeIdentifier): \(url.path)", category: .storage)
                            return ClipboardContent(type: .unknown, text: url.lastPathComponent, url: nil, image: nil, fileURL: url)
                        }
                    } else {
                        logger.debug("Значение типа \(typeIdentifier) не является Data или DispatchData, тип: \(type(of: value))", category: .storage)
                        logger.info("Требуется асинхронная загрузка для типа \(typeIdentifier)", category: .storage)
                        return nil
                    }
                }
                
                if typeIdentifier == UTType.data.identifier || 
                   typeIdentifier == "public.data" ||
                   (typeIdentifier.hasPrefix("public.") && !typeIdentifier.contains("text") && !typeIdentifier.contains("image") && !typeIdentifier.contains("url")) {
                    if let data = value as? Data {
                        logger.debug("Найдены данные типа \(typeIdentifier), размер: \(data.count) байт", category: .storage)
                        let fileName = "clipboard_file_\(UUID().uuidString)"
                        if let url = FileService.shared.saveToTemporaryDirectory(data: data, fileName: fileName) {
                            logger.info("Найден файл в буфере через data (тип: \(typeIdentifier)): \(url.path)", category: .storage)
                            return ClipboardContent(type: .unknown, text: url.lastPathComponent, url: nil, image: nil, fileURL: url)
                        } else {
                            logger.warning("Не удалось сохранить данные типа \(typeIdentifier) во временный файл", category: .storage)
                        }
                    } else {
                        logger.debug("Значение типа \(typeIdentifier) не является Data, тип: \(type(of: value))", category: .storage)
                    }
                }
            }
        }
        
        if pasteboard.hasStrings, let text = pasteboard.string {
            logger.info("Найден текст в буфере (\(text.count) символов)", category: .storage)
            return ClipboardContent(type: .text, text: text, url: nil, image: nil)
        }
        
        logger.warning("Буфер обмена пустой", category: .storage)
        return nil
        #else
        logger.warning("UIKit недоступен, чтение буфера обмена невозможно", category: .storage)
        return nil
        #endif
    }
    
    func getClipboardContentAsync() async -> ClipboardContent? {
        
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        
        if let content = getClipboardContent() {
            return content
        }
        
        logger.debug("Попытка асинхронной загрузки файлов через NSItemProvider", category: .storage)
        
        let providers = pasteboard.itemProviders
        logger.debug("Найдено NSItemProvider в буфере: \(providers.count)", category: .storage)
        
        for (index, provider) in providers.enumerated() {
            logger.debug("Обработка провайдера \(index + 1): registeredTypeIdentifiers=\(provider.registeredTypeIdentifiers)", category: .storage)
            
            var preferredType: String? = nil
            let rti = provider.registeredTypeIdentifiers
            if rti.contains(UTType.fileURL.identifier) || rti.contains("public.file-url") {
                preferredType = rti.contains(UTType.fileURL.identifier) ? UTType.fileURL.identifier : "public.file-url"
            } else if rti.contains("com.adobe.pdf") {
                preferredType = "com.adobe.pdf"
            } else if rti.contains(UTType.movie.identifier) {
                preferredType = UTType.movie.identifier
            } else if rti.contains(UTType.image.identifier) {
                preferredType = UTType.image.identifier
            } else if rti.contains(UTType.audio.identifier) {
                preferredType = UTType.audio.identifier
            } else if rti.contains(UTType.data.identifier) || rti.contains("public.data") {
                preferredType = rti.contains(UTType.data.identifier) ? UTType.data.identifier : "public.data"
            }
            
            if preferredType == nil {
                preferredType = rti.first
            }
            
            guard let preferredType = preferredType else { continue }
            
            let fileURL = await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
                provider.loadFileRepresentation(forTypeIdentifier: preferredType) { url, error in
                    if let error = error {
                        LoggerService.shared.warning("Ошибка загрузки файла через loadFileRepresentation: \(error)", category: .storage)
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: url)
                }
            }
            
            if let url = fileURL, url.isFileURL {
                logger.info("Файл загружен асинхронно через loadFileRepresentation: \(url.path)", category: .storage)
                return ClipboardContent(type: .unknown, text: url.lastPathComponent, url: nil, image: nil, fileURL: url)
            }
            
            let data = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                provider.loadItem(forTypeIdentifier: preferredType, options: nil) { item, error in
                    if let error = error {
                        LoggerService.shared.warning("Ошибка загрузки файла через loadItem: \(error)", category: .storage)
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: item as? Data)
                }
            }
            
            if let fileData = data {
                let fileExtension = getFileExtension(from: preferredType) ?? "file"
                var originalFileName: String? = nil
                
                if let suggested = provider.suggestedName, !suggested.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    originalFileName = suggested
                    logger.info("Используем suggestedName провайдера: \(suggested)", category: .storage)
                }
                
                if originalFileName == nil {
                    for registeredType in provider.registeredTypeIdentifiers {
                        if registeredType.contains("filename") || 
                           registeredType.contains("FileName") ||
                            registeredType.contains("DisplayName") {
                            if let nameData = try? await provider.loadItem(forTypeIdentifier: registeredType, options: nil) as? Data,
                               let name = String(data: nameData, encoding: .utf8),
                               !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                originalFileName = name
                                logger.info("Найдено исходное имя файла из асинхронной загрузки: \(name)", category: .storage)
                                break
                            }
                        }
                    }
                }
                
                let fileName: String
                if let original = originalFileName {
                    let nameWithoutExt = (original as NSString).deletingPathExtension
                    let originalExt = (original as NSString).pathExtension.lowercased()
                    
                    if !originalExt.isEmpty && getFileExtension(from: "public.\(originalExt)") != nil {
                        fileName = original
                    } else {
                        fileName = "\(nameWithoutExt).\(fileExtension)"
                    }
                    logger.debug("Используем исходное имя файла: \(fileName)", category: .storage)
                } else {
                    fileName = "clipboard_file_\(UUID().uuidString).\(fileExtension)"
                    logger.debug("Генерируем новое имя файла: \(fileName)", category: .storage)
                }
                
                if let url = FileService.shared.saveToTemporaryDirectory(data: fileData, fileName: fileName) {
                    logger.info("Файл загружен асинхронно как Data: \(url.path)", category: .storage)
                    return ClipboardContent(type: .unknown, text: url.lastPathComponent, url: nil, image: nil, fileURL: url)
                }
            }
        }
        
        logger.warning("Не удалось загрузить файл асинхронно", category: .storage)
        return nil
        #else
        return nil
        #endif
    }
    
    func clearClipboard() {
        logger.info("Очистка буфера обмена", category: .storage)
        #if canImport(UIKit)
        UIPasteboard.general.items = []
        #endif
    }
}

