//
//  WebViewModel.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import Combine
import SwiftUI

class WebViewModel: ObservableObject {
    
    @Published var content: WebViewContent
    @Published var bookmark: Bookmark?
    @Published var isLoading: Bool = true
    @Published var loadError: String?
    @Published var showShareSheet: Bool = false
    @Published var showDeleteConfirmation: Bool = false
    @Published var isDeleting: Bool = false
    @Published var urlToSave: URL?
    @Published var showDocumentPicker = false
    @Published var shouldDismiss: Bool = false
    @Published var itemsToShare: [Any] = []
    
    var htmlContent: String?
    @Published var currentHTMLFileURL: URL?
    @Published var contentURL: URL?
    
    private let bookmarkService: BookmarkService
    private let keychainService: KeychainServiceProtocol = KeychainService.shared
    private let logger = LoggerService.shared
    private var networkService: NetworkService {
        let service = NetworkService()
        if let userId = keychainService.getUserId() {
            service.setUserId(userId)
        }
        return service
    }
    
    init(
        content: WebViewContent,
        bookmarkService: BookmarkService
    ) {
        self.content = content
        self.bookmarkService = bookmarkService
        
        if case .file(let bookmark) = content {
            self.bookmark = bookmark
        }
        
    }
    
    func prepareContent() -> URL? {
        let contentURL: URL?
        var isAsyncLoad = false
        
        switch content {
        case .file(let bookmark):
            contentURL = prepareFileContent(bookmark: bookmark)
            if contentURL == nil {
                let isPDF = bookmark.fileName.lowercased().hasSuffix(".pdf")
                let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "opus", "aiff", "aif", "caf"]
                let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
                let isAudio = bookmark.contentType == .audio || 
                             audioExtensions.contains(where: { bookmark.fileName.lowercased().hasSuffix(".\($0)") })
                let isVideo = bookmark.contentType == .video || 
                             videoExtensions.contains(where: { bookmark.fileName.lowercased().hasSuffix(".\($0)") })
                if isPDF || isAudio || isVideo {
                    isAsyncLoad = true
                }
            }
        case .command(let html):
            contentURL = prepareHTMLContent(html: html)
        }
        
        if let url = contentURL, url.isFileURL {
        } else if let url = contentURL, !url.isFileURL {
            Task {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                await MainActor.run {
                    if isLoading {
                        logger.warning("Таймаут загрузки контента (20 сек), принудительно завершаем", category: .webview)
                        isLoading = false
                        if loadError == nil {
                            loadError = "Таймаут загрузки контента. Проверьте подключение к интернету."
                        }
                    }
                }
            }
        } else if !isAsyncLoad {
                isLoading = false
            loadError = "Не удалось подготовить контент для отображения"
        }
        
        return contentURL
    }
    
    private func prepareFileContent(bookmark: Bookmark) -> URL? {
        let isHTMLFile = bookmark.fileName.lowercased().hasSuffix(".html") || 
                        bookmark.fileName.lowercased().hasSuffix(".htm")
        
        if isHTMLFile, (bookmark.fileUrl == nil || bookmark.fileUrl?.isEmpty == true) {
            let text = bookmark.content ?? ""
            
            if !text.isEmpty {
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let isHTMLContent = trimmedText.hasPrefix("<!doctype") ||
                                   trimmedText.hasPrefix("<html")
                
                if isHTMLContent {
                    htmlContent = text
                    return createHTMLFile(from: text)
                }
                
                let isURL = trimmedText.hasPrefix("http://") || 
                           trimmedText.hasPrefix("https://") ||
                           (URL(string: trimmedText) != nil && trimmedText.contains("://"))
                
                if isURL {
                    Task {
                        do {
                            guard let url = URL(string: trimmedText) else { return }
                            var request = URLRequest(url: url)
                            request.timeoutInterval = 15
                            if let headers = requestHeaders(for: url) {
                                for (key, value) in headers {
                                    request.setValue(value, forHTTPHeaderField: key)
                                }
                            }
                            let (htmlData, _) = try await URLSession.shared.data(for: request)
                            
                            if let htmlString = String(data: htmlData, encoding: .utf8) {
                                await MainActor.run {
                                    self.htmlContent = htmlString
                                    let newFileURL = self.createHTMLFile(from: htmlString)
                                    self.currentHTMLFileURL = newFileURL
                                    self.contentURL = newFileURL // Обновляем contentURL для обновления WebView
                                }
                            } else {
                                logger.error("Не удалось декодировать HTML с URL", category: .webview)
                            }
                        } catch {
                            logger.error("Ошибка загрузки HTML с URL: \(error)", category: .webview)
                        }
                    }
                    
                    let loadingHTML = """
                    <!doctype html>
                    <html lang="ru"><head><meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <style>
                      html, body { 
                        margin: 0; 
                        padding: 16px; 
                        font-family: -apple-system, system-ui, Helvetica, Arial; 
                        background-color: #FFFFFF; 
                        color: #000000; 
                        min-height: 100vh;
                        display: flex; 
                        justify-content: center; 
                        align-items: center; 
                      }
                    </style></head><body><p>Загрузка HTML...</p></body></html>
                    """
                    htmlContent = loadingHTML
                    return createHTMLFile(from: loadingHTML)
                }
            }
            
            if bookmark.fileUrl == nil || bookmark.fileUrl!.isEmpty {
                logger.warning("fileUrl отсутствует для HTML файла", category: .webview)
            }
            
            Task {
                do {
                    logger.info("Начало загрузки HTML файла: bookmarkId=\(bookmark.id), fileName=\(bookmark.fileName)", category: .webview)
                    let fileData = try await networkService.downloadFile(bookmarkId: bookmark.id)
                    if let htmlString = String(data: fileData, encoding: .utf8) {
                        await MainActor.run {
                            self.htmlContent = htmlString
                            let newFileURL = self.createHTMLFile(from: htmlString)
                            self.currentHTMLFileURL = newFileURL
                            logger.info("HTML файл загружен с сервера и сохранен в локальный файл", category: .webview)
                        }
                    } else {
                        logger.error("Не удалось декодировать HTML файл как UTF-8", category: .webview)
                        await MainActor.run {
                            self.loadError = "Не удалось прочитать содержимое HTML файла"
                            self.isLoading = false
                        }
                    }
                } catch {
                    logger.error("Ошибка загрузки HTML файла с сервера: \(error). fileUrl: \(bookmark.fileUrl ?? "отсутствует")", category: .webview)
                    await MainActor.run {
                        self.useFallbackHTMLContent(for: bookmark, error: error)
                    }
                }
            }
            
            let loadingHTML = """
            <!doctype html>
            <html lang="ru"><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              html, body { 
                margin: 0; 
                padding: 16px; 
                font-family: -apple-system, system-ui, Helvetica, Arial; 
                background-color: #FFFFFF; 
                color: #000000; 
                min-height: 100vh;
                display: flex; 
                justify-content: center; 
                align-items: center; 
              }
            </style></head><body><p>Загрузка HTML файла...</p></body></html>
            """
            htmlContent = loadingHTML
            return createHTMLFile(from: loadingHTML)
        }
        
        
        if bookmark.contentType == .text, (bookmark.fileUrl == nil || bookmark.fileUrl?.isEmpty == true) {
            if let content = bookmark.content, !content.isEmpty {
                let trimmedText = content.trimmingCharacters(in: .whitespacesAndNewlines)
                let isURL = trimmedText.hasPrefix("http://") || 
                           trimmedText.hasPrefix("https://") ||
                           (URL(string: trimmedText) != nil && trimmedText.contains("://"))
                
                if isURL {
                    logger.info("content является URL, открываем как веб-страницу: \(trimmedText)", category: .webview)
                    if let url = URL(string: trimmedText) {
                        return url
                    }
                }
            }
            
                Task {
                    if bookmark.fileUrl == nil || bookmark.fileUrl!.isEmpty {
                        logger.warning("fileUrl отсутствует или пустой для bookmarkId=\(bookmark.id), fileName=\(bookmark.fileName), используем fallback контент без попытки загрузки", category: .webview)
                        await MainActor.run {
                            self.useFallbackContent(for: bookmark)
                            self.isLoading = false
                        }
                        return
                    }
                    
                    logger.info("Подготовка к загрузке файла: bookmarkId=\(bookmark.id), fileName=\(bookmark.fileName), fileUrl=\(bookmark.fileUrl ?? "отсутствует"), contentType=\(bookmark.contentType.rawValue)", category: .webview)
                    
                    let timeout: UInt64
                    if bookmark.contentType == .video || bookmark.contentType == .audio {
                        timeout = 30_000_000_000 // 30 секунд для видео и аудио
                    } else {
                        timeout = 15_000_000_000 // 15 секунд для остальных типов файлов
                    }
                    
                    let downloadTask = Task {
                        do {
                            logger.info("Начало загрузки текстового файла: bookmarkId=\(bookmark.id), fileName=\(bookmark.fileName), contentType=\(bookmark.contentType.rawValue)", category: .webview)
                            let fileData = try await networkService.downloadFile(bookmarkId: bookmark.id)
                            if let fileText = String(data: fileData, encoding: .utf8) {
                                await MainActor.run {
                                    self.updateHTMLContent(with: fileText, for: bookmark)
                                    logger.info("Реальный контент файла загружен и отображен: \(fileText.count) символов", category: .webview)
                                }
                            } else {
                                let encodings: [String.Encoding] = [.windowsCP1251, .isoLatin1, .macOSRoman]
                                var decodedText: String? = nil
                                
                                for encoding in encodings {
                                    if let text = String(data: fileData, encoding: encoding) {
                                        decodedText = text
                                        logger.info("Текстовый файл декодирован с кодировкой: \(encoding)", category: .webview)
                                        break
                                    }
                                }
                                
                                if let text = decodedText {
                                    await MainActor.run {
                                        self.updateHTMLContent(with: text, for: bookmark)
                                        logger.info("Реальный контент файла загружен и отображен: \(text.count) символов", category: .webview)
                                    }
                                } else {
                                    logger.error("Не удалось декодировать загруженный файл", category: .webview)
                                    await MainActor.run {
                                        self.loadError = "Не удалось прочитать содержимое файла"
                                        self.isLoading = false
                                    }
                                }
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
                            
                            logger.warning("Не удалось загрузить реальный контент файла: bookmarkId=\(bookmark.id), fileName=\(bookmark.fileName), contentType=\(bookmark.contentType.rawValue), ошибка: \(errorDetails), используем fallback", category: .webview)
                            
                            await MainActor.run {
                                var shouldUseFallback = false
                                var errorMessage: String? = nil
                                
                                if let apiError = error as? APIError {
                                    if case .httpError(let statusCode) = apiError {
                                        if statusCode == 404 || statusCode == 500 {
                                        shouldUseFallback = true
                                            logger.warning("Текстовый файл не найден на сервере (HTTP \(statusCode)): bookmarkId=\(bookmark.id), fileName=\(bookmark.fileName), используем fallback", category: .webview)
                                        } else {
                                            errorMessage = "Ошибка загрузки файла (HTTP \(statusCode))"
                                        }
                                    }
                                    else if case .serverError(let message) = apiError {
                                        if message.contains("Файл не найден") || message.contains("не найден") {
                                        shouldUseFallback = true
                                            errorMessage = "Файл не найден на сервере. Возможно, файл не был загружен при создании закладки."
                                            logger.warning("Файл не найден на сервере (serverError: \(message)): bookmarkId=\(bookmark.id), fileName=\(bookmark.fileName), fileUrl=\(bookmark.fileUrl ?? "отсутствует"), используем fallback", category: .webview)
                                        } else {
                                            errorMessage = "Ошибка сервера: \(message)"
                                        }
                                    }
                                    else if case .networkError = apiError {
                                        shouldUseFallback = true
                                        logger.warning("Сетевая ошибка при загрузке файла: bookmarkId=\(bookmark.id), используем fallback", category: .webview)
                                    }
                                    else {
                                        errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
                                    }
                                } else {
                                    shouldUseFallback = true
                                    logger.warning("Неизвестная ошибка при загрузке файла: bookmarkId=\(bookmark.id), ошибка: \(error.localizedDescription), используем fallback", category: .webview)
                                }
                                
                                if shouldUseFallback {
                                    self.useFallbackContent(for: bookmark)
                                } else {
                                    self.loadError = errorMessage ?? "Не удалось загрузить файл: \(error.localizedDescription)"
                                    self.isLoading = false
                                }
                            }
                        }
                    }
                    
                    let timeoutTask = Task {
                        try? await Task.sleep(nanoseconds: timeout)
                        if !downloadTask.isCancelled {
                            downloadTask.cancel()
                            await MainActor.run {
                                logger.warning("Таймаут загрузки файла (\(timeout / 1_000_000_000) сек), используем fallback", category: .webview)
                                self.useFallbackContent(for: bookmark)
                            }
                        }
                    }
                    
                    await downloadTask.value
                    timeoutTask.cancel()
                }
            
            let loadingText = "Загрузка контента..."
            
            let escapedText = loadingText
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&#39;")
            
            let html = """
            <!doctype html>
            <html lang="ru"><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              html, body { 
                margin: 0; 
                padding: 16px; 
                font-family: -apple-system, system-ui, Helvetica, Arial; 
                background-color: #F5F5F5; 
                color: #000000; 
                min-height: 100vh;
              }
              pre { 
                white-space: pre-wrap; 
                word-wrap: break-word; 
                margin: 0;
                font-size: 16px;
                line-height: 1.5;
              }
            </style></head><body><pre>\(escapedText)</pre></body></html>
            """
            htmlContent = html
            let fileURL = createHTMLFile(from: html)
            currentHTMLFileURL = fileURL
            return fileURL
        }
        
        
        if bookmark.contentType == .image, (bookmark.fileUrl == nil || bookmark.fileUrl?.isEmpty == true) {
            if bookmark.content == nil || bookmark.content?.isEmpty == true {
                Task {
                    do {
                        let imageData = try await networkService.downloadFile(bookmarkId: bookmark.id)
                        
                        var mimeType = "image/jpeg"
                        if imageData.count > 8 {
                            let header = imageData.prefix(8)
                            let headerArray = Array(header)
                            
                            if headerArray.count >= 4 && headerArray[0] == 0x89 && headerArray[1] == 0x50 && headerArray[2] == 0x4E && headerArray[3] == 0x47 {
                                mimeType = "image/png"
                            }
                            else if headerArray.count >= 3 && headerArray[0] == 0x47 && headerArray[1] == 0x49 && headerArray[2] == 0x46 {
                                mimeType = "image/gif"
                            }
                            else if headerArray.count >= 4 && headerArray[0] == 0x52 && headerArray[1] == 0x49 && headerArray[2] == 0x46 && headerArray[3] == 0x46 {
                                mimeType = "image/webp"
                            }
                        }
                        
                        let base64 = imageData.base64EncodedString()
                        let dataURL = "data:\(mimeType);base64,\(base64)"
                        
                        await MainActor.run {
                            self.updateImageContent(with: dataURL, for: bookmark)
                        }
                    } catch {
                        logger.error("Ошибка загрузки изображения: \(error)", category: .webview)
                        await MainActor.run {
                            self.useFallbackImageContent(for: bookmark)
                        }
                    }
                }
                
                let html = """
                <!doctype html>
                <html lang="ru"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                  html, body { 
                    margin: 0; 
                    padding: 16px; 
                    font-family: -apple-system, system-ui, Helvetica, Arial; 
                    background-color: #F5F5F5; 
                    color: #000000; 
                    min-height: 100vh;
                    display: flex; 
                    justify-content: center; 
                    align-items: center; 
                  }
                </style></head><body><p>Загрузка изображения...</p></body></html>
                """
                htmlContent = html
                let fileURL = createHTMLFile(from: html)
                currentHTMLFileURL = fileURL
                return fileURL
            } else if let content = bookmark.content, !content.isEmpty {
                if content.hasPrefix("data:image/") {
                    let escapedContent = content.replacingOccurrences(of: "\"", with: "&quot;")
                    
                    let html = """
                    <!doctype html>
                    <html lang="ru"><head><meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <style>
                      html, body { 
                        margin: 0; 
                        padding: 0; 
                        font-family: -apple-system, system-ui, Helvetica, Arial; 
                        background-color: #FFFFFF; 
                        min-height: 100vh;
                        display: flex; 
                        justify-content: center; 
                        align-items: center; 
                        overflow: hidden;
                      }
                      img { 
                        max-width: 100%; 
                        max-height: 100vh; 
                        height: auto; 
                        width: auto;
                        object-fit: contain;
                        display: block;
                      }
                    </style></head><body><img src="\(escapedContent)" alt="\(bookmark.fileName)" onload="console.log('Image loaded')" onerror="console.error('Image failed to load')" /></body></html>
                """
                    logger.info("Рендер изображения из content как HTML (data URL)", category: .webview)
                    htmlContent = html
                    let fileURL = createHTMLFile(from: html)
                    currentHTMLFileURL = fileURL
                    return fileURL
                } else {
                    let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    let isURL = trimmedContent.hasPrefix("http://") || 
                               trimmedContent.hasPrefix("https://") ||
                               trimmedContent.hasPrefix("file://") ||
                               (URL(string: trimmedContent) != nil && trimmedContent.contains("://"))
                    
                    if !isURL {
                        Task {
                            do {
                                let imageData = try await networkService.downloadFile(bookmarkId: bookmark.id)
                                
                                var mimeType = "image/jpeg"
                                if imageData.count > 8 {
                                    let header = imageData.prefix(8)
                                    let headerArray = Array(header)
                                    
                                    if headerArray.count >= 4 && headerArray[0] == 0x89 && headerArray[1] == 0x50 && headerArray[2] == 0x4E && headerArray[3] == 0x47 {
                                        mimeType = "image/png"
                                    } else if headerArray.count >= 3 && headerArray[0] == 0x47 && headerArray[1] == 0x49 && headerArray[2] == 0x46 {
                                        mimeType = "image/gif"
                                    } else if headerArray.count >= 4 && headerArray[0] == 0x52 && headerArray[1] == 0x49 && headerArray[2] == 0x46 && headerArray[3] == 0x46 {
                                        mimeType = "image/webp"
                                    }
                                }
                                
                                let base64 = imageData.base64EncodedString()
                                let dataURL = "data:\(mimeType);base64,\(base64)"
                                
                                await MainActor.run {
                                    self.updateImageContent(with: dataURL, for: bookmark)
                                }
                            } catch {
                                logger.error("Ошибка загрузки изображения с сервера: \(error)", category: .webview)
                                await MainActor.run {
                                    self.useFallbackImageContent(for: bookmark)
                                }
                            }
                        }
                        
                        let html = """
                        <!doctype html>
                        <html lang="ru"><head><meta charset="utf-8">
                        <meta name="viewport" content="width=device-width, initial-scale=1">
                        <style>
                          html, body { 
                            margin: 0; 
                            padding: 16px; 
                            font-family: -apple-system, system-ui, Helvetica, Arial; 
                            background-color: #000000; 
                            color: #FFFFFF; 
                            min-height: 100vh;
                            display: flex; 
                            justify-content: center; 
                            align-items: center; 
                          }
                        </style></head><body><p>Загрузка изображения...</p></body></html>
                        """
                        htmlContent = html
                        let fileURL = createHTMLFile(from: html)
                        currentHTMLFileURL = fileURL
                        return fileURL
                    }
                    
                    Task {
                        do {
                            guard let imageURL = URL(string: trimmedContent) else {
                                logger.error("Неверный URL в content: \(trimmedContent)", category: .webview)
                                await MainActor.run {
                                    self.useFallbackImageContent(for: bookmark)
                                }
                                return
                            }
                            
                            let imageData: Data
                            if imageURL.isFileURL {
                                imageData = try Data(contentsOf: imageURL)
                            } else {
                                var request = URLRequest(url: imageURL)
                                request.timeoutInterval = 15
                                let (data, _) = try await URLSession.shared.data(for: request)
                                imageData = data
                            }
                            
                            var mimeType = "image/jpeg"
                            if imageData.count > 8 {
                                let header = imageData.prefix(8)
                                let headerArray = Array(header)
                                
                                if headerArray.count >= 4 && headerArray[0] == 0x89 && headerArray[1] == 0x50 && headerArray[2] == 0x4E && headerArray[3] == 0x47 {
                                    mimeType = "image/png"
                                }
                                else if headerArray.count >= 3 && headerArray[0] == 0x47 && headerArray[1] == 0x49 && headerArray[2] == 0x46 {
                                    mimeType = "image/gif"
                                }
                                else if headerArray.count >= 4 && headerArray[0] == 0x52 && headerArray[1] == 0x49 && headerArray[2] == 0x46 && headerArray[3] == 0x46 {
                                    mimeType = "image/webp"
                                }
                            }
                            
                            let base64 = imageData.base64EncodedString()
                            let dataURL = "data:\(mimeType);base64,\(base64)"
                            
                            await MainActor.run {
                                self.updateImageContent(with: dataURL, for: bookmark)
                            }
                        } catch {
                            logger.error("Ошибка загрузки изображения из URL: \(error)", category: .webview)
                            await MainActor.run {
                                self.useFallbackImageContent(for: bookmark)
                            }
                        }
                    }
                    
                    let html = """
                    <!doctype html>
                    <html lang="ru"><head><meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <style>
                      html, body { 
                        margin: 0; 
                        padding: 16px; 
                        font-family: -apple-system, system-ui, Helvetica, Arial; 
                        background-color: #FFFFFF; 
                        color: #000000; 
                        min-height: 100vh;
                        display: flex; 
                        justify-content: center; 
                        align-items: center; 
                      }
                    </style></head><body><p>Загрузка изображения...</p></body></html>
                    """
                    htmlContent = html
                    let fileURL = createHTMLFile(from: html)
                    currentHTMLFileURL = fileURL
                    return fileURL
                }
            } else {
                logger.warning("Изображение без fileUrl и content, показываем сообщение", category: .webview)
                let html = """
                <!doctype html>
                <html lang="ru"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                  html, body { 
                    margin: 0; 
                    padding: 16px; 
                    font-family: -apple-system, system-ui, Helvetica, Arial; 
                    background-color: #F5F5F5; 
                    color: #000000; 
                    min-height: 100vh;
                    text-align: center;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                  }
                </style></head><body><p>Изображение недоступно</p><p>\(bookmark.fileName)</p></body></html>
                """
                htmlContent = html
                return createHTMLFile(from: html)
            }
        }

        let isPDFFile = bookmark.fileName.lowercased().hasSuffix(".pdf")
        
        if isPDFFile {
            if bookmark.fileUrl == nil || bookmark.fileUrl?.isEmpty == true {
                let message = "Не удалось загрузить PDF: отсутствует ссылка на файл"
                loadError = message
                logger.warning("\(message): \(bookmark.fileName)", category: .webview)
                let escapedName = bookmark.fileName
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                let html = """
                <!doctype html>
                <html lang="ru"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                  html, body {
                    margin: 0;
                    padding: 16px;
                    font-family: -apple-system, system-ui, Helvetica, Arial;
                    background-color: #F5F5F5;
                    color: #000000;
                    min-height: 100vh;
                  }
                </style></head><body><p>\(message)</p><p>\(escapedName)</p></body></html>
                """
                htmlContent = html
                return createHTMLFile(from: html)
            }
            
            logger.info("Загрузка PDF: \(bookmark.fileName)", category: .webview)
            
            Task {
                do {
                    if let fileUrl = bookmark.fileUrl, !fileUrl.isEmpty,
                       let directURL = URL(string: fileUrl),
                       directURL.scheme == "http" || directURL.scheme == "https" {
                        do {
                            let (pdfData, response) = try await URLSession.shared.data(from: directURL)
                            
                            if let httpResponse = response as? HTTPURLResponse {
                                if httpResponse.statusCode == 404 || httpResponse.statusCode == 500 {
                                } else {
                                    let tempDir = FileManager.default.temporaryDirectory
                                    let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).pdf")
                                    
                                    let minPDFSize: Int = 1024
                                    if pdfData.count < minPDFSize {
                                    } else {
                                        try pdfData.write(to: tempURL)
                                        
                                        await MainActor.run {
                                            self.contentURL = tempURL
                                            self.isLoading = false
                                        }
                                        return
                                    }
                                }
                            }
                        } catch {
                        }
                    }
                    
                    let pdfData = try await networkService.downloadFile(bookmarkId: bookmark.id)
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).pdf")
                    
                    let minPDFSize: Int = 1024
                    if pdfData.count < minPDFSize {
                        await MainActor.run {
                            self.useFallbackContent(for: bookmark)
                        }
                        return
                    }
                    
                    try pdfData.write(to: tempURL)
                    
                    await MainActor.run {
                        self.contentURL = tempURL
                        self.isLoading = false
                    }
                } catch {
                    logger.error("Ошибка загрузки PDF: \(error)", category: .webview)
                    await MainActor.run {
                        if let apiError = error as? APIError {
                            if case .httpError(let statusCode) = apiError, statusCode == 404 || statusCode == 500 {
                                self.useFallbackContent(for: bookmark)
                            } else {
                                self.loadError = "Не удалось загрузить PDF файл: \(error.localizedDescription)"
                                self.isLoading = false
                            }
                        } else {
                            self.loadError = "Не удалось загрузить PDF файл: \(error.localizedDescription)"
                            self.isLoading = false
                        }
                    }
                }
            }
            
            return nil
        }
        
        guard let fileUrlString = bookmark.fileUrl, !fileUrlString.isEmpty else {
            let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "opus", "aiff", "aif", "caf"]
            let isAudioFile = bookmark.contentType == .audio || 
                             audioExtensions.contains(where: { bookmark.fileName.lowercased().hasSuffix(".\($0)") })
            
            if isAudioFile {
                logger.info("Аудио файл без fileUrl, загружаем с сервера: \(bookmark.fileName)", category: .webview)
                
                Task {
                    do {
                        let audioData = try await networkService.downloadFile(bookmarkId: bookmark.id)
                        let tempDir = FileManager.default.temporaryDirectory
                        
                        let fileExtension = bookmark.fileName.components(separatedBy: ".").last ?? "m4a"
                        let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
                        
                        let minAudioSize: Int = 1024
                        if audioData.count < minAudioSize {
                            logger.warning("Аудио файл слишком маленький (\(audioData.count) байт), возможно поврежден. Используем fallback", category: .webview)
                            await MainActor.run {
                                self.useFallbackContent(for: bookmark)
                            }
                            return
                        }
                        
                        try audioData.write(to: tempURL)
                        
                        logger.info("Аудио загружено с сервера и сохранено во временный файл: \(tempURL.path), размер: \(audioData.count) байт", category: .webview)
                        
                        await MainActor.run {
                            self.contentURL = tempURL
                            self.isLoading = false
                            logger.info("contentURL обновлен на локальный аудио файл: \(tempURL.lastPathComponent)", category: .webview)
                        }
                    } catch {
                        logger.error("Ошибка загрузки аудио с сервера: \(error)", category: .webview)
                        await MainActor.run {
                            if let apiError = error as? APIError {
                                if case .httpError(let statusCode) = apiError, statusCode == 404 || statusCode == 500 {
                                    logger.warning("Аудио файл не найден на сервере (HTTP \(statusCode)), используем fallback", category: .webview)
                                    self.useFallbackContent(for: bookmark)
                                } else {
                            self.loadError = "Не удалось загрузить аудио файл: \(error.localizedDescription)"
                            self.isLoading = false
                                }
                            } else {
                                self.loadError = "Не удалось загрузить аудио файл: \(error.localizedDescription)"
                                self.isLoading = false
                            }
                        }
                    }
                }
                
                return nil
            }
            
            let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
            let isVideoFile = bookmark.contentType == .video || 
                             videoExtensions.contains(where: { bookmark.fileName.lowercased().hasSuffix(".\($0)") })
            
            if isVideoFile {
                logger.info("Видео файл без fileUrl, загружаем с сервера: \(bookmark.fileName)", category: .webview)
                
                Task {
                    do {
                        let videoData = try await networkService.downloadFile(bookmarkId: bookmark.id)
                        let tempDir = FileManager.default.temporaryDirectory
                        
                        let fileExtension = bookmark.fileName.components(separatedBy: ".").last ?? "mp4"
                        let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
                        
                        try videoData.write(to: tempURL)
                        
                        logger.info("Видео загружено с сервера и сохранено во временный файл: \(tempURL.path), размер: \(videoData.count) байт", category: .webview)
                        
                        await MainActor.run {
                            self.contentURL = tempURL
                            self.isLoading = false
                            logger.info("contentURL обновлен на локальный видео файл: \(tempURL.lastPathComponent)", category: .webview)
                        }
                    } catch {
                        logger.error("Ошибка загрузки видео с сервера: \(error)", category: .webview)
                        await MainActor.run {
                            if let apiError = error as? APIError {
                                if case .httpError(let statusCode) = apiError, statusCode == 404 || statusCode == 500 {
                                    logger.warning("Видео файл не найден на сервере (HTTP \(statusCode)), используем fallback", category: .webview)
                                    self.useFallbackContent(for: bookmark)
                                } else {
                                    self.loadError = "Не удалось загрузить видео файл: \(error.localizedDescription)"
                                    self.isLoading = false
                                }
                            } else {
                                self.loadError = "Не удалось загрузить видео файл: \(error.localizedDescription)"
                                self.isLoading = false
                            }
                        }
                    }
                }
                
                return nil
            }
            
            if let content = bookmark.content, !content.isEmpty {
                let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let isHTML = trimmedContent.hasPrefix("<!doctype") ||
                             trimmedContent.hasPrefix("<html") ||
                             bookmark.fileName.lowercased().hasSuffix(".html") ||
                             bookmark.fileName.lowercased().hasSuffix(".htm")
                
                if isHTML {
                    logger.info("Создание HTML файла из content для \(bookmark.fileName)", category: .webview)
                    htmlContent = trimmedContent
                    return createHTMLFile(from: trimmedContent)
                }
                
                let isURL = trimmedContent.hasPrefix("http://") || 
                           trimmedContent.hasPrefix("https://") ||
                           (URL(string: trimmedContent) != nil && trimmedContent.contains("://"))
                
                if isURL {
                    logger.info("content является URL, загружаем HTML с URL для \(bookmark.fileName)", category: .webview)
                    
                    Task {
                        do {
                            guard let url = URL(string: trimmedContent) else { return }
                            var request = URLRequest(url: url)
                            request.timeoutInterval = 15
                            if let headers = requestHeaders(for: url) {
                                for (key, value) in headers {
                                    request.setValue(value, forHTTPHeaderField: key)
                                }
                            }
                            let (htmlData, _) = try await URLSession.shared.data(for: request)
                            
                            if let htmlString = String(data: htmlData, encoding: .utf8) {
                                await MainActor.run {
                                    self.htmlContent = htmlString
                                    let newFileURL = self.createHTMLFile(from: htmlString)
                                    self.currentHTMLFileURL = newFileURL
                                    logger.info("HTML загружен с URL из content и сохранен в локальный файл", category: .webview)
                                }
                            } else {
                                logger.error("Не удалось декодировать HTML с URL из content", category: .webview)
                            }
                        } catch {
                            logger.error("Ошибка загрузки HTML с URL из content: \(error)", category: .webview)
                        }
                    }
                    
                    let loadingHTML = """
                    <!doctype html>
                    <html lang="ru"><head><meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <style>
                      html, body { 
                        margin: 0; 
                        padding: 16px; 
                        font-family: -apple-system, system-ui, Helvetica, Arial; 
                        background-color: #F5F5F5; 
                        color: #000000; 
                        min-height: 100vh;
                        display: flex; 
                        justify-content: center; 
                        align-items: center; 
                      }
                    </style></head><body><p>Загрузка HTML...</p></body></html>
                    """
                    htmlContent = loadingHTML
                    return createHTMLFile(from: loadingHTML)
                }
            }
            
            let isHTMLFile = bookmark.fileName.lowercased().hasSuffix(".html") || 
                            bookmark.fileName.lowercased().hasSuffix(".htm")
            
            if isHTMLFile {
                if let fileUrlString = bookmark.fileUrl, !fileUrlString.isEmpty, let fileUrl = URL(string: fileUrlString) {
                    Task {
                        do {
                            var request = URLRequest(url: fileUrl)
                            request.timeoutInterval = 15
                            if let headers = requestHeaders(for: fileUrl) {
                                for (key, value) in headers {
                                    request.setValue(value, forHTTPHeaderField: key)
                                }
                            }
                            let (htmlData, _) = try await URLSession.shared.data(for: request)
                            
                            if let htmlString = String(data: htmlData, encoding: .utf8) {
                                await MainActor.run {
                                    self.htmlContent = htmlString
                                    let newFileURL = self.createHTMLFile(from: htmlString)
                                    self.currentHTMLFileURL = newFileURL
                                    logger.info("HTML файл загружен по fileUrl и сохранен в локальный файл", category: .webview)
                                }
                            } else {
                                await self.fallbackDownloadHTML(bookmarkId: bookmark.id)
                            }
                        } catch {
                            await self.fallbackDownloadHTML(bookmarkId: bookmark.id)
                        }
                    }
                } else {
                    Task {
                        do {
                            let fileData = try await networkService.downloadFile(bookmarkId: bookmark.id)
                            if let htmlString = String(data: fileData, encoding: .utf8) {
                                await MainActor.run {
                                    self.htmlContent = htmlString
                                    let newFileURL = self.createHTMLFile(from: htmlString)
                                    self.currentHTMLFileURL = newFileURL
                                    logger.info("HTML файл загружен с сервера и сохранен в локальный файл", category: .webview)
                                }
                            } else {
                                logger.error("Не удалось декодировать HTML файл как UTF-8", category: .webview)
                                await MainActor.run {
                                    self.useFallbackHTMLContent(for: bookmark, error: NSError(domain: "WebViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось прочитать содержимое HTML файла"]))
                                }
                            }
                        } catch {
                            await MainActor.run {
                                self.useFallbackHTMLContent(for: bookmark, error: error)
                            }
                        }
                    }
                }
                
                let loadingHTML = """
                <!doctype html>
                <html lang="ru"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                  html, body { 
                    margin: 0; 
                    padding: 16px; 
                    font-family: -apple-system, system-ui, Helvetica, Arial; 
                    background-color: #FFFFFF; 
                    color: #000000; 
                    min-height: 100vh;
                    display: flex; 
                    justify-content: center; 
                    align-items: center; 
                  }
                </style></head><body><p>Загрузка HTML файла...</p></body></html>
                """
                htmlContent = loadingHTML
                return createHTMLFile(from: loadingHTML)
            }
            
            logger.error("Пустой URL файла для типа \(bookmark.contentType)", category: .webview)
            let html = """
            <!doctype html>
            <html lang=\"ru\"><head><meta charset=\"utf-8\">
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
            <style>
              body { font-family: -apple-system, system-ui, Helvetica, Arial; padding: 16px; text-align: center; }
            </style></head><body><p>Файл недоступен</p><p>\(bookmark.fileName)</p></body></html>
            """
            htmlContent = html
            loadError = "Неверный URL файла"
            return createHTMLFile(from: html)
        }
        
        
        if isPDFFile {
            logger.info("PDF файл обнаружен, загружаем с сервера: \(bookmark.fileName)", category: .webview)
            
            Task {
                do {
                    if let fileUrl = bookmark.fileUrl, !fileUrl.isEmpty,
                       let directURL = URL(string: fileUrl),
                       directURL.scheme == "http" || directURL.scheme == "https" {
                        logger.info("Загружаем PDF напрямую из fileUrl: \(fileUrl)", category: .webview)
                        do {
                            let (pdfData, response) = try await URLSession.shared.data(from: directURL)
                            
                            if let httpResponse = response as? HTTPURLResponse {
                                if httpResponse.statusCode == 404 || httpResponse.statusCode == 500 {
                                    logger.warning("PDF файл не найден на сервере (HTTP \(httpResponse.statusCode)), используем download endpoint", category: .webview)
                                } else {
                                    let tempDir = FileManager.default.temporaryDirectory
                                    let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).pdf")
                                    
                                    let minPDFSize: Int = 1024
                                    if pdfData.count < minPDFSize {
                                        logger.warning("PDF файл слишком маленький (\(pdfData.count) байт), возможно поврежден. Используем download endpoint", category: .webview)
                                    } else {
                                        try pdfData.write(to: tempURL)
                                        
                                        logger.info("PDF загружен напрямую из fileUrl и сохранен во временный файл: \(tempURL.path), размер: \(pdfData.count) байт", category: .webview)
                                        
                                        await MainActor.run {
                                            self.contentURL = tempURL
                                            self.isLoading = false
                                            logger.info("contentURL обновлен на локальный PDF файл: \(tempURL.lastPathComponent)", category: .webview)
                                        }
                                        return
                                    }
                                }
                            }
                        } catch {
                            logger.error("Ошибка загрузки PDF с fileUrl: \(error), используем download endpoint", category: .webview)
                        }
                    }
                    
                    logger.info("Загружаем PDF через download endpoint", category: .webview)
                    let pdfData = try await networkService.downloadFile(bookmarkId: bookmark.id)
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).pdf")
                    
                    let minPDFSize: Int = 1024
                    if pdfData.count < minPDFSize {
                        logger.warning("PDF файл слишком маленький (\(pdfData.count) байт), возможно поврежден. Используем fallback", category: .webview)
                        await MainActor.run {
                            self.useFallbackContent(for: bookmark)
                        }
                        return
                    }
                    
                    try pdfData.write(to: tempURL)
                    
                    logger.info("PDF загружен с сервера через download endpoint и сохранен во временный файл: \(tempURL.path), размер: \(pdfData.count) байт", category: .webview)
                    
                    await MainActor.run {
                        self.contentURL = tempURL
                        self.isLoading = false
                        logger.info("contentURL обновлен на локальный PDF файл: \(tempURL.lastPathComponent)", category: .webview)
                    }
                } catch {
                        logger.error("Ошибка загрузки PDF с сервера: \(error)", category: .webview)
                        await MainActor.run {
                            if let apiError = error as? APIError {
                                if case .httpError(let statusCode) = apiError, statusCode == 404 || statusCode == 500 {
                                logger.warning("PDF файл не найден на сервере (HTTP \(statusCode)), используем fallback", category: .webview)
                                self.useFallbackContent(for: bookmark)
                            } else {
                                self.loadError = "Не удалось загрузить PDF файл: \(error.localizedDescription)"
                                self.isLoading = false
                            }
                        } else {
                            self.loadError = "Не удалось загрузить PDF файл: \(error.localizedDescription)"
                            self.isLoading = false
                        }
                    }
                }
            }
            
            return nil
        }
        
        
        let url: URL
        if let parsedURL = URL(string: fileUrlString),
           parsedURL.scheme == "http" || parsedURL.scheme == "https" {
            url = parsedURL
            
            let isHTMLURL = url.pathExtension.lowercased() == "html" || 
                           url.pathExtension.lowercased() == "htm" ||
                           url.pathExtension.isEmpty
            
            if isHTMLURL {
                if let content = bookmark.content, !content.isEmpty {
                    let isHTMLContent = content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<!doctype") ||
                                        content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<html")
                    
                    if isHTMLContent {
                        logger.info("HTML URL обнаружен, используем content для создания локального файла: \(bookmark.fileName)", category: .webview)
                        htmlContent = content
                        return createHTMLFile(from: content)
                    }
                }
                
                logger.info("HTML URL обнаружен, загружаем HTML с сервера: \(url.absoluteString)", category: .webview)
                
                Task {
                    do {
                        var request = URLRequest(url: url)
                        request.timeoutInterval = 15
                        if let headers = requestHeaders(for: url) {
                            for (key, value) in headers {
                                request.setValue(value, forHTTPHeaderField: key)
                            }
                        }
                        let (htmlData, _) = try await URLSession.shared.data(for: request)
                        
                        if let htmlString = String(data: htmlData, encoding: .utf8) {
                            await MainActor.run {
                                self.htmlContent = htmlString
                                let newFileURL = self.createHTMLFile(from: htmlString)
                                self.currentHTMLFileURL = newFileURL
                                logger.info("HTML загружен с URL и сохранен в локальный файл", category: .webview)
                                
                                if let fileURL = newFileURL {
                                    Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                                        self.contentURL = fileURL
                                        logger.info("contentURL обновлен на новый файл: \(fileURL.lastPathComponent), ожидаем загрузку в WebView", category: .webview)
                                    }
                                } else {
                                    logger.error("Не удалось создать HTML файл для обновления contentURL", category: .webview)
                                    self.isLoading = false
                                }
                            }
                        } else {
                            logger.error("Не удалось декодировать HTML с URL", category: .webview)
                            await self.fallbackDownloadHTML(bookmarkId: bookmark.id)
                        }
                    } catch {
                        logger.error("Ошибка загрузки HTML с URL: \(error)", category: .webview)
                        await self.fallbackDownloadHTML(bookmarkId: bookmark.id)
                    }
                }
                
                let loadingHTML = """
                <!doctype html>
                <html lang="ru"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                  html, body { 
                    margin: 0; 
                    padding: 16px; 
                    font-family: -apple-system, system-ui, Helvetica, Arial; 
                    background-color: #F5F5F5; 
                    color: #000000; 
                    min-height: 100vh;
                    display: flex; 
                    justify-content: center; 
                    align-items: center; 
                  }
                </style></head><body><p>Загрузка HTML...</p></body></html>
                """
                htmlContent = loadingHTML
                return createHTMLFile(from: loadingHTML)
            }
            
            
            let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "opus", "aiff", "aif", "caf"]
            let isAudioFile = bookmark.contentType == .audio || 
                             audioExtensions.contains(url.pathExtension.lowercased()) ||
                             audioExtensions.contains(where: { bookmark.fileName.lowercased().hasSuffix(".\($0)") })
            
            if isAudioFile {
                logger.info("Аудио файл обнаружен с HTTP/HTTPS URL, загружаем с сервера: \(url.absoluteString)", category: .webview)
                
                Task {
                    do {
                        if let fileUrl = bookmark.fileUrl, let directURL = URL(string: fileUrl) {
                            logger.info("Загружаем аудио напрямую из fileUrl (обход download endpoint): \(fileUrl)", category: .webview)
                            let (audioData, _) = try await URLSession.shared.data(from: directURL)
                            let tempDir = FileManager.default.temporaryDirectory
                            
                            let fileExtension: String
                            if let fileNameExt = bookmark.fileName.components(separatedBy: ".").last, !fileNameExt.isEmpty {
                                fileExtension = fileNameExt.lowercased()
                            } else if !directURL.pathExtension.isEmpty {
                                fileExtension = directURL.pathExtension.lowercased()
                            } else {
                                fileExtension = "m4a"
                            }
                            
                            let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
                            
                            let minAudioSize: Int = 1024
                            if audioData.count < minAudioSize {
                                logger.warning("Аудио файл слишком маленький (\(audioData.count) байт), возможно поврежден. Используем fallback", category: .webview)
                                await MainActor.run {
                                    self.useFallbackContent(for: bookmark)
                                }
                                return
                            }
                            
                            try audioData.write(to: tempURL)
                            
                            logger.info("Аудио загружено напрямую из fileUrl и сохранено во временный файл: \(tempURL.path), размер: \(audioData.count) байт, расширение: \(fileExtension)", category: .webview)
                            
                            await MainActor.run {
                                self.contentURL = tempURL
                                self.isLoading = false
                                logger.info("contentURL обновлен на локальный аудио файл: \(tempURL.lastPathComponent)", category: .webview)
                            }
                            return
                        }
                        
                        logger.warning("fileUrl отсутствует, используем download endpoint (может быть проблема с кодировкой для русских символов)", category: .webview)
                        let audioData = try await networkService.downloadFile(bookmarkId: bookmark.id)
                        let tempDir = FileManager.default.temporaryDirectory
                        
                        let fileExtension = bookmark.fileName.components(separatedBy: ".").last ?? 
                                           (url.pathExtension.isEmpty ? "m4a" : url.pathExtension)
                        let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
                        
                        try audioData.write(to: tempURL)
                        
                        logger.info("Аудио загружено с сервера через download endpoint и сохранено во временный файл: \(tempURL.path), размер: \(audioData.count) байт", category: .webview)
                        
                        await MainActor.run {
                            self.contentURL = tempURL
                            self.isLoading = false
                            logger.info("contentURL обновлен на локальный аудио файл: \(tempURL.lastPathComponent)", category: .webview)
                        }
                    } catch {
                        logger.error("Ошибка загрузки аудио с сервера: \(error)", category: .webview)
                        await MainActor.run {
                            self.loadError = "Не удалось загрузить аудио файл: \(error.localizedDescription)"
                            self.isLoading = false
                        }
                    }
                }
                
                return nil
            }
            
            
            let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
            let isVideoFile = bookmark.contentType == .video || 
                             videoExtensions.contains(url.pathExtension.lowercased()) ||
                             videoExtensions.contains(where: { bookmark.fileName.lowercased().hasSuffix(".\($0)") })
            
            if isVideoFile {
                logger.info("Видео файл обнаружен с HTTP/HTTPS URL, загружаем с сервера: \(url.absoluteString)", category: .webview)
                
                Task {
                    do {
                        if let fileUrl = bookmark.fileUrl, let directURL = URL(string: fileUrl) {
                            logger.info("Загружаем видео напрямую из fileUrl (обход download endpoint): \(fileUrl)", category: .webview)
                            let (videoData, _) = try await URLSession.shared.data(from: directURL)
                            let tempDir = FileManager.default.temporaryDirectory
                            
                            let fileExtension: String
                            if let fileNameExt = bookmark.fileName.components(separatedBy: ".").last, !fileNameExt.isEmpty {
                                fileExtension = fileNameExt.lowercased()
                            } else if !directURL.pathExtension.isEmpty {
                                fileExtension = directURL.pathExtension.lowercased()
                            } else {
                                fileExtension = "mp4"
                            }
                            
                            let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
                            
                            try videoData.write(to: tempURL)
                            
                            logger.info("Видео загружено напрямую из fileUrl и сохранено во временный файл: \(tempURL.path), размер: \(videoData.count) байт, расширение: \(fileExtension)", category: .webview)
                            
                            await MainActor.run {
                                self.contentURL = tempURL
                                self.isLoading = false
                                logger.info("contentURL обновлен на локальный видео файл: \(tempURL.lastPathComponent)", category: .webview)
                            }
                            return
                        }
                        
                        logger.warning("fileUrl отсутствует, используем download endpoint (может быть проблема с кодировкой для русских символов)", category: .webview)
                        let videoData = try await networkService.downloadFile(bookmarkId: bookmark.id)
                        let tempDir = FileManager.default.temporaryDirectory
                        
                        let fileExtension = bookmark.fileName.components(separatedBy: ".").last ?? 
                                           (url.pathExtension.isEmpty ? "mp4" : url.pathExtension)
                        let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
                        
                        try videoData.write(to: tempURL)
                        
                        logger.info("Видео загружено с сервера через download endpoint и сохранено во временный файл: \(tempURL.path), размер: \(videoData.count) байт", category: .webview)
                        
                        await MainActor.run {
                            self.contentURL = tempURL
                            self.isLoading = false
                            logger.info("contentURL обновлен на локальный видео файл: \(tempURL.lastPathComponent)", category: .webview)
                        }
                    } catch {
                        logger.error("Ошибка загрузки видео с сервера: \(error)", category: .webview)
                        await MainActor.run {
                            self.loadError = "Не удалось загрузить видео файл: \(error.localizedDescription)"
                            self.isLoading = false
                        }
                    }
                }
                
                return nil
            }
            
            
            let textExtensions = ["txt", "md", "log", "rtf", "csv", "json", "xml", "yaml", "yml"]
            let isTextFile = bookmark.contentType == .text || 
                           textExtensions.contains(url.pathExtension.lowercased()) ||
                           textExtensions.contains(where: { bookmark.fileName.lowercased().hasSuffix(".\($0)") })
            
            if isTextFile {
                logger.info("Текстовый файл обнаружен с HTTP/HTTPS URL, загружаем с сервера: \(url.absoluteString)", category: .webview)
                
                Task {
                    do {
                        if let fileUrl = bookmark.fileUrl, let directURL = URL(string: fileUrl) {
                            logger.info("Загружаем текстовый файл напрямую из fileUrl (обход download endpoint): \(fileUrl)", category: .webview)
                            let (fileData, _) = try await URLSession.shared.data(from: directURL)
                            
                            if let fileText = String(data: fileData, encoding: .utf8) {
                                await MainActor.run {
                                    self.updateHTMLContent(with: fileText, for: bookmark)
                                    logger.info("Текстовый файл загружен напрямую из fileUrl и отображен: \(fileText.count) символов", category: .webview)
                                }
                                return
                            } else {
                                let encodings: [String.Encoding] = [.windowsCP1251, .isoLatin1, .macOSRoman]
                                var decodedText: String? = nil
                                
                                for encoding in encodings {
                                    if let text = String(data: fileData, encoding: encoding) {
                                        decodedText = text
                                        logger.info("Текстовый файл декодирован с кодировкой: \(encoding)", category: .webview)
                                        break
                                    }
                                }
                                
                                if let text = decodedText {
                                    await MainActor.run {
                                        self.updateHTMLContent(with: text, for: bookmark)
                                        logger.info("Текстовый файл загружен напрямую из fileUrl и отображен: \(text.count) символов", category: .webview)
                                    }
                                    return
                                } else {
                                    logger.error("Не удалось декодировать текстовый файл из fileUrl", category: .webview)
                                    await MainActor.run {
                                        self.loadError = "Не удалось прочитать текстовый файл"
                                        self.isLoading = false
                                    }
                                    return
                                }
                            }
                        }
                        
                        logger.warning("fileUrl отсутствует, используем download endpoint (может быть проблема с кодировкой для русских символов)", category: .webview)
                        let fileData = try await networkService.downloadFile(bookmarkId: bookmark.id)
                        
                        if let fileText = String(data: fileData, encoding: .utf8) {
                            await MainActor.run {
                                self.updateHTMLContent(with: fileText, for: bookmark)
                                logger.info("Текстовый файл загружен с сервера через download endpoint и отображен: \(fileText.count) символов", category: .webview)
                            }
                        } else {
                            let encodings: [String.Encoding] = [.windowsCP1251, .isoLatin1, .macOSRoman]
                            var decodedText: String? = nil
                            
                            for encoding in encodings {
                                if let text = String(data: fileData, encoding: encoding) {
                                    decodedText = text
                                    logger.info("Текстовый файл декодирован с кодировкой: \(encoding)", category: .webview)
                                    break
                                }
                            }
                            
                            if let text = decodedText {
                                await MainActor.run {
                                    self.updateHTMLContent(with: text, for: bookmark)
                                    logger.info("Текстовый файл загружен с сервера через download endpoint и отображен: \(text.count) символов", category: .webview)
                                }
                            } else {
                                logger.error("Не удалось декодировать текстовый файл с сервера", category: .webview)
                                await MainActor.run {
                                    self.loadError = "Не удалось прочитать текстовый файл"
                                    self.isLoading = false
                                }
                            }
                        }
                    } catch {
                        logger.error("Ошибка загрузки текстового файла с сервера: \(error)", category: .webview)
                        await MainActor.run {
                            if let apiError = error as? APIError {
                                if case .httpError(let statusCode) = apiError, statusCode == 404 || statusCode == 500 {
                                    logger.warning("Текстовый файл не найден на сервере (HTTP \(statusCode)), используем fallback", category: .webview)
                                    self.useFallbackContent(for: bookmark)
                                } else {
                            self.loadError = "Не удалось загрузить текстовый файл: \(error.localizedDescription)"
                            self.isLoading = false
                                }
                            } else {
                                self.loadError = "Не удалось загрузить текстовый файл: \(error.localizedDescription)"
                                self.isLoading = false
                            }
                        }
                    }
                }
                
                let loadingHTML = """
                <!doctype html>
                <html lang="ru"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                  html, body { 
                    margin: 0; 
                    padding: 16px; 
                    font-family: -apple-system, system-ui, Helvetica, Arial; 
                    background-color: #F5F5F5; 
                    color: #000000; 
                    min-height: 100vh;
                    display: flex; 
                    justify-content: center; 
                    align-items: center; 
                  }
                </style></head><body><p>Загрузка текстового документа...</p></body></html>
                """
                htmlContent = loadingHTML
                return createHTMLFile(from: loadingHTML)
            }
            
            logger.info("Файл с HTTP/HTTPS URL (не HTML, не PDF, не текст): \(url.absoluteString)", category: .webview)
            return url
        } else if fileUrlString.hasPrefix("file://") {
            url = URL(fileURLWithPath: String(fileUrlString.dropFirst(7)))
        } else {
            url = URL(fileURLWithPath: fileUrlString)
        }
        
        logger.info("Подготовка файла: \(bookmark.fileName) → \(url.absoluteString)", category: .webview)
        return url
    }

    
    /// Заголовки авторизации для защищенных URL (наш домен API)
    func requestHeaders(for url: URL) -> [String: String]? {
        guard let host = URL(string: Constants.API.baseURL)?.host,
              url.host == host,
              let userId = keychainService.getUserId() else {
            return nil
        }
        return [Constants.API.Headers.userID: userId]
    }
    
    
    /// Подготовка HTML контента для команды: удаление дубликатов изображений и создание файла
    private func prepareHTMLContent(html: String) -> URL? {
        logger.info("Создание HTML файла для команды, размер HTML: \(html.count) символов", category: .webview)
        
        let originalImageCount = countImages(in: html)
        logger.info("Найдено \(originalImageCount) изображений в HTML до дедупликации", category: .webview)
        
        let processedHTML = removeDuplicateImages(from: html)
        
        let processedImageCount = countImages(in: processedHTML)
        let removedCount = originalImageCount - processedImageCount
        
        if processedHTML != html {
            if removedCount > 0 {
                logger.info("Удалено \(removedCount) дубликатов изображений из HTML (было \(originalImageCount), стало \(processedImageCount))", category: .webview)
            } else {
                logger.info("HTML обработан, но дубликатов не найдено (было \(originalImageCount), стало \(processedImageCount))", category: .webview)
            }
        } else {
            logger.info("HTML не изменен после дедупликации (изображений: \(originalImageCount))", category: .webview)
        }
        
        htmlContent = processedHTML
        return createHTMLFile(from: processedHTML)
    }
    
    
    /// Удаление дубликатов изображений из HTML: находит все теги <img> и удаляет дубликаты по src
    private func removeDuplicateImages(from html: String) -> String {
        let imgTagPattern = #"<img[^>]*src\s*=\s*["']([^"']+)["'][^>]*>"#
        
        guard let regex = try? NSRegularExpression(pattern: imgTagPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            logger.warning("Не удалось создать регулярное выражение для поиска изображений", category: .webview)
            return html
        }
        
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        guard !matches.isEmpty else {
            logger.debug("Изображения в HTML не найдены", category: .webview)
            return html
        }
        
        logger.debug("Найдено \(matches.count) изображений в HTML", category: .webview)
        
        var seenImageSources = Set<String>()
        var imageRangesToRemove: [NSRange] = []
        var duplicateCount = 0
        
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            
            let fullRange = match.range(at: 0) // Полный тег <img>
            let srcRange = match.range(at: 1) // Значение src атрибута
            
            guard srcRange.location != NSNotFound else { continue }
            
            let imageSrc = nsString.substring(with: srcRange).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let normalizedSrc = normalizeImageSrc(imageSrc)
            
            if seenImageSources.contains(normalizedSrc) {
                imageRangesToRemove.append(fullRange)
                duplicateCount += 1
                logger.debug("Найден дубликат изображения: \(imageSrc)", category: .webview)
            } else {
                seenImageSources.insert(normalizedSrc)
            }
        }
        
        guard !imageRangesToRemove.isEmpty else {
            logger.debug("Дубликатов изображений в HTML не найдено", category: .webview)
            return html
        }
        
        logger.info("Найдено \(duplicateCount) дубликатов изображений в HTML, удаляем их", category: .webview)
        
        let mutableHTML = NSMutableString(string: html)
        let rangesToRemove = imageRangesToRemove.sorted { $0.location > $1.location }
        
        for range in rangesToRemove {
            mutableHTML.deleteCharacters(in: range)
        }
        
        let processedHTML = mutableHTML as String
        logger.info("Удалено \(duplicateCount) дубликатов изображений из HTML, размер уменьшился с \(html.count) до \(processedHTML.count) символов", category: .webview)
        
        return processedHTML
    }
    
    /// Подсчет количества изображений в HTML
    private func countImages(in html: String) -> Int {
        let imgTagPattern = #"<img[^>]*src\s*=\s*["']([^"']+)["'][^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: imgTagPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return 0
        }
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        return matches.count
    }
    
    /// Нормализация src атрибута изображения для сравнения: убирает query параметры и нормализует пути
    private func normalizeImageSrc(_ src: String) -> String {
        let trimmedSrc = src.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedSrc.hasPrefix("data:image/") {
            if let commaIndex = trimmedSrc.firstIndex(of: ",") {
                let header = String(trimmedSrc[..<commaIndex])
                return header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            return trimmedSrc.lowercased()
        }
        
        if trimmedSrc.hasPrefix("file://") {
            let fileURL = trimmedSrc.replacingOccurrences(of: "file://", with: "")
            let normalizedPath = (fileURL as NSString).standardizingPath
            return normalizedPath.lowercased()
        }
        
        if let url = URL(string: trimmedSrc) {
            var baseUrl = ""
            if let scheme = url.scheme {
                baseUrl += "\(scheme)://"
            }
            if let host = url.host {
                baseUrl += host
            }
            baseUrl += url.path
            return baseUrl.lowercased()
        }
        
        return trimmedSrc.lowercased()
    }
    
    
    /// Создание временного HTML файла с уникальным именем для WebView
    private func createHTMLFile(from html: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "command_\(UUID().uuidString).html"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            let startTime = Date()
            try html.write(to: fileURL, atomically: false, encoding: .utf8)
            let writeDuration = Date().timeIntervalSince(startTime)
            logger.info("HTML файл создан: \(fileURL.path) (запись заняла \(String(format: "%.3f", writeDuration))с, размер: \(html.count) символов)", category: .webview)
                return fileURL
            } catch {
                logger.error("Ошибка создания HTML файла: \(error)", category: .webview)
                loadError = "Не удалось создать HTML файл"
                return nil
        }
    }
    
    /// Обновление HTML контента: определяет тип (HTML/URL/текст) и создает соответствующий файл
    private func updateHTMLContent(with text: String, for bookmark: Bookmark) {
        logger.info("Обновление HTML контента с полным текстом: \(text.count) символов", category: .webview)
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let isHTMLContent = trimmedText.hasPrefix("<!doctype") ||
                           trimmedText.hasPrefix("<html")
        
        if isHTMLContent {
            logger.info("Загруженный контент является HTML кодом, добавляем voiceNote если есть", category: .webview)
            if let voiceNote = bookmark.voiceNote, !voiceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let escapedVoiceNote = voiceNote
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                    .replacingOccurrences(of: "\"", with: "&quot;")
                    .replacingOccurrences(of: "'", with: "&#39;")
                
                let voiceNoteHTML = """
                <div style="background-color: #FFF9E6; padding: 16px; margin-bottom: 16px; border-left: 4px solid #FFD700; border-radius: 4px;">
                  <h3 style="margin: 0 0 8px 0; font-size: 16px; font-weight: 600; color: #000000;">Голосовая заметка:</h3>
                  <p style="margin: 0; font-size: 14px; line-height: 1.5; color: #000000; white-space: pre-wrap;">\(escapedVoiceNote)</p>
                </div>
                """
                
                var modifiedHTML = text
                if let bodyRange = text.range(of: "<body", options: .caseInsensitive) {
                    let afterBody = text[bodyRange.upperBound...]
                    if let closingBracket = afterBody.firstIndex(of: ">") {
                        let insertPosition = text.index(after: closingBracket)
                        modifiedHTML = String(text[..<insertPosition]) + voiceNoteHTML + String(text[insertPosition...])
                    }
                }
                
                htmlContent = modifiedHTML
                let newFileURL = createHTMLFile(from: modifiedHTML)
                currentHTMLFileURL = newFileURL
                logger.info("HTML файл обновлен с голосовой заметкой: заметка \(voiceNote.count) символов, HTML \(text.count) символов, файл: \(newFileURL?.path ?? "не создан")", category: .webview)
            } else {
            htmlContent = text
            let newFileURL = createHTMLFile(from: text)
            currentHTMLFileURL = newFileURL
            logger.info("HTML файл обновлен с HTML кодом, создан новый файл: \(newFileURL?.path ?? "nil")", category: .webview)
            }
            return
        }
        
        let isURL = trimmedText.hasPrefix("http://") || 
                   trimmedText.hasPrefix("https://") ||
                   (URL(string: trimmedText) != nil && trimmedText.contains("://"))
        
        if isURL {
            logger.info("Загруженный контент является URL, открываем как веб-страницу: \(trimmedText)", category: .webview)
            if let url = URL(string: trimmedText) {
                currentHTMLFileURL = nil
                contentURL = url
                return
            }
        }
        
        let escapedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
        
        logger.info("Обновление контента для '\(bookmark.fileName)': файл \(text.count) символов, голосовая заметка \(bookmark.voiceNote?.isEmpty == false ? "\(bookmark.voiceNote!.count) символов" : "отсутствует"), описание \(bookmark.summary?.isEmpty == false ? "\(bookmark.summary!.count) символов" : "отсутствует")", category: .webview)
        
        var finalContent = escapedText
        if let voiceNote = bookmark.voiceNote, !voiceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let escapedVoiceNote = voiceNote
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&#39;")
            finalContent = """
            <div style="background-color: #FFF9E6; padding: 16px; margin-bottom: 16px; border-left: 4px solid #FFD700; border-radius: 4px;">
              <h3 style="margin: 0 0 8px 0; font-size: 16px; font-weight: 600; color: #000000;">Голосовая заметка:</h3>
              <p style="margin: 0; font-size: 14px; line-height: 1.5; color: #000000; white-space: pre-wrap;">\(escapedVoiceNote)</p>
            </div>
            <div style="margin-top: 16px;">
              <h3 style="margin: 0 0 8px 0; font-size: 16px; font-weight: 600; color: #000000;">Содержимое файла:</h3>
              <pre style="margin: 0; font-size: 14px; line-height: 1.5; white-space: pre-wrap; word-wrap: break-word;">\(escapedText)</pre>
            </div>
            """
            logger.info("Голосовая заметка добавлена к содержимому файла: заметка \(voiceNote.count) символов, файл \(text.count) символов", category: .webview)
        } else {
            finalContent = "<pre style=\"margin: 0; font-size: 14px; line-height: 1.5; white-space: pre-wrap; word-wrap: break-word;\">\(escapedText)</pre>"
            logger.info("Показываем только содержимое файла (голосовая заметка отсутствует): \(text.count) символов", category: .webview)
        }
        
        let html = """
        <!doctype html>
        <html lang="ru"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          html, body { 
            margin: 0; 
            padding: 16px; 
            font-family: -apple-system, system-ui, Helvetica, Arial; 
            background-color: #F5F5F5; 
            color: #000000; 
            min-height: 100vh;
          }
          pre { 
            white-space: pre-wrap; 
            word-wrap: break-word; 
            margin: 0;
            font-size: 16px;
            line-height: 1.5;
          }
        </style></head><body>\(finalContent)</body></html>
        """
        
        htmlContent = html
        
        let newFileURL = createHTMLFile(from: html)
        currentHTMLFileURL = newFileURL
        contentURL = newFileURL
        logger.info("HTML файл обновлен с полным контентом, создан новый файл: \(newFileURL?.path ?? "nil")", category: .webview)
    }
    
    
    /// Fallback загрузка HTML файла через /api/download если загрузка с URL не удалась
    private func fallbackDownloadHTML(bookmarkId: String) async {
        logger.info("Попытка загрузки HTML файла через /api/download для bookmark \(bookmarkId)", category: .webview)
        
        do {
            let fileData = try await networkService.downloadFile(bookmarkId: bookmarkId)
            if let htmlString = String(data: fileData, encoding: .utf8) {
                await MainActor.run {
                    self.htmlContent = htmlString
                    let newFileURL = self.createHTMLFile(from: htmlString)
                    self.currentHTMLFileURL = newFileURL
                    self.contentURL = newFileURL // Обновляем contentURL для обновления WebView
                    logger.info("HTML файл загружен через /api/download и сохранен в локальный файл", category: .webview)
                }
            } else {
                logger.error("Не удалось декодировать HTML файл как UTF-8", category: .webview)
                await MainActor.run {
                    self.loadError = "Не удалось прочитать содержимое HTML файла"
                    self.isLoading = false
                }
            }
        } catch {
            logger.error("Ошибка загрузки HTML файла через /api/download: \(error)", category: .webview)
            await MainActor.run {
                self.loadError = "Не удалось загрузить HTML файл: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Использование fallback контента для HTML файлов при ошибке загрузки
    private func useFallbackHTMLContent(for bookmark: Bookmark, error: Error) {
        logger.warning("Используем fallback контент для HTML файла из-за ошибки", category: .webview)
        
        var errorMessage = "Не удалось загрузить HTML файл"
        if let apiError = error as? APIError {
            switch apiError {
            case .httpError(let statusCode):
                if statusCode == 500 {
                    let hasFileUrl = bookmark.fileUrl != nil && !bookmark.fileUrl!.isEmpty
                    if !hasFileUrl {
                        errorMessage = "Файл недоступен: отсутствует ссылка на файл. Возможно, файл не был корректно сохранен при создании закладки."
                    } else {
                        errorMessage = "Ошибка сервера при загрузке файла"
                    }
                } else if statusCode == 404 {
                    errorMessage = "Файл не найден на сервере"
                } else {
                    errorMessage = "Ошибка загрузки (код: \(statusCode))"
                }
            case .serverError(let message):
                errorMessage = message
            default:
                errorMessage = error.localizedDescription
            }
        } else {
            errorMessage = error.localizedDescription
        }
        
        var content = errorMessage
        if let summary = bookmark.summary, !summary.isEmpty {
            content = "\(errorMessage)\n\nОписание:\n\(summary)"
        } else if let voiceNote = bookmark.voiceNote, !voiceNote.isEmpty {
            content = "\(errorMessage)\n\nЗаметка:\n\(voiceNote)"
        }
        
        let escapedContent = content
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
        
        let html = """
        <!doctype html>
        <html lang="ru"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          html, body { 
            margin: 0; 
            padding: 16px; 
            font-family: -apple-system, system-ui, Helvetica, Arial; 
            background-color: #FFFFFF; 
            color: #000000; 
            min-height: 100vh;
          }
          pre { 
            white-space: pre-wrap; 
            word-wrap: break-word; 
            margin: 0;
            font-size: 16px;
            line-height: 1.5;
          }
        </style></head><body><pre>\(escapedContent)</pre></body></html>
        """
        
        htmlContent = html
        let newFileURL = createHTMLFile(from: html)
        currentHTMLFileURL = newFileURL
        isLoading = false
        logger.info("Fallback HTML контент создан для файла \(bookmark.fileName)", category: .webview)
    }
    
    /// Использование fallback контента (summary/voiceNote) только если загрузка реального файла не удалась
    private func useFallbackContent(for bookmark: Bookmark) {
        logger.warning("Используем fallback контент (summary/voiceNote), так как загрузка реального файла не удалась", category: .webview)
        
        var text = ""
        var prefix = ""
        
        let fileExtension = (bookmark.fileName as NSString).pathExtension.lowercased()
        let isImage = ["jpg", "jpeg", "png", "gif", "webp"].contains(fileExtension) || bookmark.contentType == .image
        let isPDF = fileExtension == "pdf" || bookmark.contentType == .file && fileExtension == "pdf"
        let isAudio = ["mp3", "wav", "m4a", "aac"].contains(fileExtension)
        let isVideo = ["mp4", "mov", "avi", "mkv"].contains(fileExtension) || bookmark.contentType == .video
        
        if let summary = bookmark.summary, !summary.isEmpty {
            text = summary
            if isImage {
                prefix = "Не удалось загрузить изображение. Показано описание от ИИ:\n\n"
            } else if isPDF {
                prefix = "Не удалось загрузить PDF файл. Возможно, файл не был загружен при создании закладки. Показано описание от ИИ:\n\n"
            } else if isAudio {
                prefix = "Не удалось загрузить аудио файл. Показано описание от ИИ:\n\n"
            } else if isVideo {
                prefix = "Не удалось загрузить видео файл. Показано описание от ИИ:\n\n"
            } else {
            prefix = "Не удалось загрузить содержимое файла. Показано описание от ИИ:\n\n"
            }
        } else if let voiceNote = bookmark.voiceNote, !voiceNote.isEmpty {
            text = voiceNote
            if isImage {
                prefix = "Не удалось загрузить изображение. Показана заметка:\n\n"
            } else if isPDF {
                prefix = "Не удалось загрузить PDF файл. Возможно, файл не был загружен при создании закладки. Показана заметка:\n\n"
            } else {
            prefix = "Не удалось загрузить содержимое файла. Показана заметка:\n\n"
            }
        } else {
            text = "Контент недоступен"
            if isImage {
                prefix = "Не удалось загрузить изображение. Файл не найден на сервере."
            } else if isPDF {
                prefix = "Не удалось загрузить PDF файл. Возможно, файл не был загружен при создании закладки."
            } else {
                prefix = "Не удалось загрузить содержимое файла. Файл не найден на сервере."
            }
        }
        
        updateHTMLContent(with: prefix + text, for: bookmark)
        
        isLoading = false
        loadError = nil
    }
    
    /// Обновление HTML контента с изображением: создает HTML с data URL
    private func updateImageContent(with imageDataURL: String, for bookmark: Bookmark) {
        logger.info("Обновление HTML контента с изображением: \(imageDataURL.prefix(50))...", category: .webview)
        
        let escapedImageURL = imageDataURL
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
        
        let html = """
        <!doctype html>
        <html lang="ru"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          html, body { 
            margin: 0; 
            padding: 0; 
            font-family: -apple-system, system-ui, Helvetica, Arial; 
            background-color: #FFFFFF; 
            min-height: 100vh;
            display: flex; 
            justify-content: center; 
            align-items: center; 
            overflow: hidden;
          }
          img { 
            max-width: 100%; 
            max-height: 100vh; 
            height: auto; 
            width: auto;
            object-fit: contain;
            display: block;
          }
        </style></head><body><img src="\(escapedImageURL)" alt="\(bookmark.fileName)" onload="console.log('Image loaded')" onerror="console.error('Image failed to load')" /></body></html>
        """
        
        htmlContent = html
        
        let newFileURL = createHTMLFile(from: html)
        currentHTMLFileURL = newFileURL
        logger.info("HTML файл обновлен с изображением, создан новый файл: \(newFileURL?.path ?? "nil")", category: .webview)
    }
    
    /// Использование fallback контента для изображения если загрузка не удалась
    private func useFallbackImageContent(for bookmark: Bookmark) {
        logger.warning("Используем fallback контент для изображения", category: .webview)
        
        let html = """
        <!doctype html>
        <html lang="ru"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          html, body { 
            margin: 0; 
            padding: 16px; 
            font-family: -apple-system, system-ui, Helvetica, Arial; 
            background-color: #F5F5F5; 
            color: #000000; 
            min-height: 100vh;
            text-align: center;
            display: flex;
            justify-content: center;
            align-items: center;
          }
        </style></head><body><p>Не удалось загрузить изображение</p><p>\(bookmark.fileName)</p></body></html>
        """
        
        htmlContent = html
        let newFileURL = createHTMLFile(from: html)
        currentHTMLFileURL = newFileURL
    }
    
    
    /// Подготовка данных для Share sheet: URL файла, имя, описание или HTML команды
    func handleShareAction() {
        logger.info("Открытие Share sheet", category: .ui)
        
        var items: [Any] = []
        
        switch content {
        case .file(let bookmark):
            if let fileUrlString = bookmark.fileUrl,
               let url = URL(string: fileUrlString) {
                items.append(url)
            }
            items.append(bookmark.fileName)
            if !bookmark.displayDescription.isEmpty {
                items.append(bookmark.displayDescription)
            }
            
        case .command(let html):
            items.append(html)
        }
        
        itemsToShare = items
        showShareSheet = true
        logger.info("Share sheet подготовлен с \(items.count) элементами", category: .ui)
    }
    
    /// Сохранение файла на диск: подготовка и открытие DocumentPicker
    func handleSaveToFiles() {
        logger.info("Сохранение на диск", category: .ui)
        
        Task { @MainActor in
            do {
                let fileURL = try await prepareFileForSaving()
                
                urlToSave = fileURL
                showDocumentPicker = true
                
            } catch {
                loadError = "Ошибка подготовки файла: \(error.localizedDescription)"
                logger.error("Ошибка подготовки файла для сохранения: \(error)", category: .ui)
            }
        }
    }
    
    /// Подготовка файла для сохранения: для файла возвращает URL, для команды создает временный HTML
    private func prepareFileForSaving() async throws -> URL {
        switch content {
        case .file(let bookmark):
            guard let fileUrlString = bookmark.fileUrl,
                  let url = URL(string: fileUrlString) else {
                throw APIError.serverError(message: "Неверный URL файла")
            }
            return url
            
        case .command(let html):
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "command_result_\(Date().timeIntervalSince1970).html"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        }
    }
    
    /// Инициация удаления: проверка canDelete и показ подтверждения
    func handleDeleteAction() {
        guard content.canDelete else {
            logger.warning("Попытка удалить не удаляемый контент", category: .ui)
            return
        }
        
        logger.info("Запрос подтверждения удаления", category: .ui)
        showDeleteConfirmation = true
    }
    
    /// Подтверждение удаления: вызов API, обработка результата, закрытие view при успехе
    func confirmDelete() async {
        guard content.canDelete, let bookmark = bookmark else {
            logger.error("Нельзя удалить этот контент", category: .ui)
            return
        }
        
        await MainActor.run {
            isDeleting = true
        }
        
        
        do {
            let success = try await bookmarkService.deleteBookmark(id: bookmark.id)
            
            await MainActor.run {
                if success {
                    logger.info("Закладка успешно удалена", category: .network)
                    shouldDismiss = true
                    showDeleteConfirmation = false
                } else {
                    loadError = "Не удалось удалить закладку"
                    logger.error("Удаление не удалось: success = false", category: .network)
                }
                isDeleting = false
            }
            
        } catch {
            await MainActor.run {
                loadError = "Ошибка удаления: \(error.localizedDescription)"
                logger.error("Ошибка удаления закладки: \(error)", category: .network)
                isDeleting = false
            }
        }
    }
    
    
    func loadingDidFinish() {
        isLoading = false
        logger.info("Контент загружен в WebView", category: .webview)
    }
    
    func loadingDidFail(error: Error) {
        isLoading = false
        
        if let nsError = error as NSError?,
           nsError.domain == "AVFoundationErrorDomain" && nsError.code == -11829,
           case .file(let bookmark) = content {
            logger.warning("Аудио файл поврежден (ошибка -11829), используем fallback для: \(bookmark.fileName)", category: .webview)
            useFallbackContent(for: bookmark)
            return
        }
        
        loadError = error.localizedDescription
        logger.error("Ошибка загрузки в WebView: \(error)", category: .webview)
    }
    
    func cleanup() {
        isLoading = false
        logger.debug("WebViewModel cleanup: ресурсы освобождены", category: .webview)
    }
}

