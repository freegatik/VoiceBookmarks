//
//  SearchService.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Сервис поиска: папки (кеш), поиск, команды, закладки по категориям

class SearchService {
    
    private let networkService: NetworkService
    private let logger = LoggerService.shared
    
    init(networkService: NetworkService = NetworkService()) {
        self.networkService = networkService
    }
    
    
    /// Получение папок: показывает кеш сразу, обновляет в фоне
    /// Это обеспечивает быстрый отклик UI при сохранении актуальных данных
    func getFolders() async throws -> [Folder] {
        
        struct FoldersResponse: Codable {
            let folders: [String]
        }
        
        if let cachedFolders = FolderCacheService.shared.getCachedFolders() {
            logger.info("Показываем папки из кеша для быстрого отклика: \(cachedFolders.count)", category: .network)
            
            Task {
                do {
                    let response: FoldersResponse = try await networkService.request(
                        endpoint: Constants.API.Endpoints.folders,
                        method: "GET"
                    )
                    let hierarchicalFolders = buildFolderHierarchy(from: response.folders)
                    FolderCacheService.shared.saveFolders(hierarchicalFolders)
                    logger.info("Folders обновлены в фоне: \(hierarchicalFolders.count)", category: .network)
                } catch {
                    logger.warning("Не удалось обновить папки в фоне: \(error)", category: .network)
                }
            }
            
            return cachedFolders
        }
        
        do {
            let response: FoldersResponse = try await networkService.request(
                endpoint: Constants.API.Endpoints.folders,
                method: "GET"
            )
            
            logger.info("Полный список папок с сервера: \(response.folders)", category: .network)
            
            let hierarchicalFolders = buildFolderHierarchy(from: response.folders)
            FolderCacheService.shared.saveFolders(hierarchicalFolders)
            
            logger.info("Получено папок с сервера: \(response.folders.count), построено иерархий: \(hierarchicalFolders.count)", category: .network)
            
            return hierarchicalFolders
            
        } catch {
            logger.error("Error загрузки папок с сервера: \(error)", category: .network)
            throw error
        }
    }
    
    
    /// Строит иерархию папок из плоского списка (разделитель "_", например "Аудиозаписи_Самоанализ")
    /// Автоматически создает родительские папки при необходимости
    private func buildFolderHierarchy(from folderNames: [String]) -> [Folder] {
        logger.info("Построение иерархии из папок с сервера: \(folderNames)", category: .network)
        var rootFolders: [Folder] = []
        var folderMap: [String: Folder] = [:]
        
        let sortedFolders = folderNames.sorted()
        
        for folderName in sortedFolders {
            let parts = folderName.split(separator: "_").map { String($0) }
            
            if parts.isEmpty {
                continue
            }
            
            if parts.count == 1 {
                if folderMap[folderName] == nil {
                    let folder = Folder(name: parts[0])
                    folderMap[folderName] = folder
                    rootFolders.append(folder)
                }
            } else {
                var parentFolder: Folder?
                var currentPath = ""
                
                for part in parts {
                    currentPath = currentPath.isEmpty ? part : "\(currentPath)_\(part)"
                    
                    if let existingFolder = folderMap[currentPath] {
                        parentFolder = existingFolder
                    } else {
                        let folder = Folder(name: part, parent: parentFolder)
                        folderMap[currentPath] = folder
                        
                        if let parent = parentFolder {
                            parent.addChild(folder)
                        } else {
                            rootFolders.append(folder)
                        }
                        
                        parentFolder = folder
                    }
                }
            }
        }
        
        var uniqueRootFolders: [Folder] = []
        var processedIds = Set<String>()
        
        func addUniqueFolder(_ folder: Folder) {
            if processedIds.contains(folder.id) {
                return
            }
            processedIds.insert(folder.id)
            uniqueRootFolders.append(folder)
        }
        
        for folder in rootFolders {
            addUniqueFolder(folder)
        }
        
        uniqueRootFolders.sort { $0.name < $1.name }
        
        logger.info("Построена иерархия: \(uniqueRootFolders.count) корневых папок из \(folderNames.count) исходных", category: .network)
        
        return uniqueRootFolders
    }
    
    
    /// Выполняет поиск: возвращает результаты или HTML команды (intent: "search" или "command")
    /// Команды генерируют HTML ответ на основе сохраненного контента
    func search(query: String, folderId: String?, bookmarkId: String? = nil) async throws -> SearchResponse {
        
        struct SearchRequest: Codable {
            let query: String
            let category: String?
            let elementId: String?
            
            init(query: String, folderId: String?, bookmarkId: String? = nil) {
                self.query = query
                self.category = folderId
                self.elementId = bookmarkId
            }
        }
        
        struct UnifiedSearchResponse: Codable {
            let intent: String
            let results: [Bookmark]?
            let html: String?
        }
        
        do {
            let requestBody = SearchRequest(query: query, folderId: folderId, bookmarkId: bookmarkId)
            logger.info("SearchRequest: query='\(query)', category=\(folderId ?? "nil"), elementId=\(bookmarkId ?? "nil")", category: .network)
            
            let response: UnifiedSearchResponse = try await networkService.request(
                endpoint: Constants.API.Endpoints.search,
                method: "POST",
                body: requestBody
            )
            
            logger.info("Ответ сервера получен: intent=\(response.intent), results.count=\(response.results?.count ?? 0), html.length=\(response.html?.count ?? 0)", category: .network)
            
            if response.intent == "search" {
                logger.info("Intent: search, найдено: \(response.results?.count ?? 0)", category: .network)
                
                if let results = response.results, !results.isEmpty {
                    for bookmark in results.prefix(3) {
                        let voiceNoteInfo = bookmark.voiceNote != nil && !bookmark.voiceNote!.isEmpty ? "voiceNote='\(bookmark.voiceNote!.prefix(100))' (длина: \(bookmark.voiceNote!.count))" : "voiceNote=nil"
                        let summaryInfo: String
                        if let summary = bookmark.summary, !summary.isEmpty {
                            summaryInfo = "summary='\(summary.prefix(100))' (длина: \(summary.count))"
                        } else {
                            summaryInfo = "summary=nil"
                        }
                        logger.debug("Результат поиска: id=\(bookmark.id), fileName=\(bookmark.fileName), contentType=\(bookmark.contentType.rawValue), \(voiceNoteInfo), \(summaryInfo), displayDescription='\(bookmark.displayDescription.prefix(100))' (длина: \(bookmark.displayDescription.count))", category: .network)
                        
                        if bookmark.voiceNote != nil && !bookmark.voiceNote!.isEmpty && bookmark.summary != nil && !bookmark.summary!.isEmpty {
                            logger.warning("Результат поиска \(bookmark.id) имеет и voiceNote и summary. Должен использоваться только voiceNote для отображения.", category: .network)
                        }
                    }
                }
                
                
                return SearchResponse(
                    intent: response.intent,
                    results: response.results ?? [],
                    html: nil
                )
            } else if response.intent == "command" {
                logger.info("Intent: command, получен HTML", category: .network)
                
                if let html = response.html {
                    let htmlLowercased = html.lowercased()
                    let hasNotFoundMessage = htmlLowercased.contains("не нашлось") || 
                                            htmlLowercased.contains("не найден") ||
                                            htmlLowercased.contains("не найдено") ||
                                            htmlLowercased.contains("not found") ||
                                            htmlLowercased.contains("не удалось найти")
                    
                    if hasNotFoundMessage {
                        logger.warning("HTML содержит ошибку поиска: \(html.prefix(500))", category: .network)
                    }
                }
                
                if let results = response.results, !results.isEmpty {
                    logger.info("Команда вернула \(results.count) результатов для отладки", category: .network)
                    
                    var seenFileUrls = Set<String>()
                    var duplicateCount = 0
                    for bookmark in results {
                        if let fileUrl = bookmark.fileUrl, !fileUrl.isEmpty {
                            if seenFileUrls.contains(fileUrl) {
                                duplicateCount += 1
                                logger.warning("Найден дубликат в результатах команды по fileUrl: \(fileUrl) для закладки \(bookmark.id)", category: .network)
                            } else {
                                seenFileUrls.insert(fileUrl)
                            }
                        }
                    }
                    
                    if duplicateCount > 0 {
                        logger.warning("В результатах команды найдено \(duplicateCount) дубликатов по fileUrl из \(results.count) результатов. Это может привести к дубликатам в HTML на сервере.", category: .network)
                    }
                    
                    for bookmark in results.prefix(5) {
                        logger.debug("Результат команды: id=\(bookmark.id), fileName=\(bookmark.fileName), fileUrl=\(bookmark.fileUrl ?? "nil"), timestamp=\(bookmark.timestamp)", category: .network)
                    }
                } else {
                    logger.debug("Команда не вернула результатов для отладки", category: .network)
                }
                
                
                return SearchResponse(
                    intent: response.intent,
                    results: [],
                    html: response.html
                )
            } else {
                throw APIError.serverError(message: "Неизвестный intent: \(response.intent)")
            }
            
        } catch {
            logger.error("Error поиска: \(error)", category: .network)
            throw error
        }
    }
    
    func searchInFolder(folderId: String, query: String) async throws -> [Bookmark] {
        logger.info("Search в папке \(folderId): \(query)", category: .network)
        
        let response = try await search(query: query, folderId: folderId)
        
        guard response.intent == "search" else {
            logger.warning("Ожидался search, получен \(response.intent)", category: .network)
            return []
        }
        
        return response.results
    }
    
    func executeCommand(query: String, folderId: String? = nil, bookmarkId: String? = nil) async throws -> CommandResponse {
        logger.info("Выполнение команды: \(query), folderId: \(folderId ?? "nil"), bookmarkId: \(bookmarkId ?? "nil")", category: .network)
        
        struct SearchRequest: Codable {
            let query: String
            let category: String?
            let elementId: String?
            
            init(query: String, folderId: String?, bookmarkId: String?) {
                self.query = query
                self.category = folderId
                self.elementId = bookmarkId
            }
        }
        
        struct UnifiedSearchResponse: Codable {
            let intent: String
            let results: [Bookmark]?
            let html: String?
        }
        
        do {
            let requestBody = SearchRequest(query: query, folderId: folderId, bookmarkId: bookmarkId)
            logger.info("SearchRequest отправлен на сервер: query=\(query), category=\(folderId ?? "nil"), elementId=\(bookmarkId ?? "nil")", category: .network)
            
            let response: UnifiedSearchResponse = try await networkService.request(
                endpoint: Constants.API.Endpoints.search,
                method: "POST",
                body: requestBody
            )
            
            logger.info("Ответ сервера: intent=\(response.intent), results.count=\(response.results?.count ?? 0), html.length=\(response.html?.count ?? 0)", category: .network)
            
            if let html = response.html {
                let htmlLowercased = html.lowercased()
                let hasNotFoundMessage = htmlLowercased.contains("не нашлось") || 
                                        htmlLowercased.contains("не найден") ||
                                        htmlLowercased.contains("не найдено") ||
                                        htmlLowercased.contains("not found") ||
                                        htmlLowercased.contains("не удалось найти")
                
                if hasNotFoundMessage {
                    logger.warning("HTML содержит ошибку поиска: \(html.prefix(500))", category: .network)
                }
            }
            
            guard response.intent == "command" else {
                logger.error("Неверный intent в ответе команды: ожидался 'command', получен '\(response.intent)'", category: .network)
                throw APIError.serverError(message: "Ожидался command intent, получен: \(response.intent)")
            }
            
            guard let html = response.html else {
                logger.error("HTML отсутствует в ответе команды", category: .network)
                throw APIError.serverError(message: "HTML не получен")
            }
            
            logger.info("Команда выполнена успешно, HTML получен (длина: \(html.count) символов)", category: .network)
            
            let commandResults = response.results ?? []
            if !commandResults.isEmpty {
                logger.info("Команда вернула \(commandResults.count) результатов для отладки", category: .network)
                
                for (index, bookmark) in commandResults.prefix(5).enumerated() {
                    logger.debug("Результат команды [\(index)]: id=\(bookmark.id), fileName=\(bookmark.fileName), contentType=\(bookmark.contentType.rawValue), fileUrl=\(bookmark.fileUrl ?? "nil")", category: .network)
                }
                
                var seenFileUrls = Set<String>()
                var seenFileNames = Set<String>()
                var duplicateCount = 0
                var duplicateDetails: [String] = []
                
                for bookmark in commandResults {
                    var isDuplicate = false
                    
                    if let fileUrl = bookmark.fileUrl, !fileUrl.isEmpty {
                        if seenFileUrls.contains(fileUrl) {
                            isDuplicate = true
                            duplicateDetails.append("Дубликат по fileUrl: \(fileUrl) для id=\(bookmark.id)")
                        } else {
                            seenFileUrls.insert(fileUrl)
                        }
                    }
                    
                    let fileName = bookmark.fileName.lowercased()
                    if seenFileNames.contains(fileName) {
                        if !isDuplicate {
                            isDuplicate = true
                            duplicateDetails.append("Дубликат по fileName: \(fileName) для id=\(bookmark.id)")
                        }
                    } else {
                        seenFileNames.insert(fileName)
                    }
                    
                    if isDuplicate {
                        duplicateCount += 1
                        logger.warning("Найден дубликат в результатах команды: id=\(bookmark.id), fileName=\(bookmark.fileName), fileUrl=\(bookmark.fileUrl ?? "nil")", category: .network)
                    }
                }
                
                if duplicateCount > 0 {
                    logger.error("В результатах команды найдено \(duplicateCount) дубликатов из \(commandResults.count) результатов. Это может привести к дубликатам в HTML на сервере. Детали: \(duplicateDetails.joined(separator: "; "))", category: .network)
                } else {
                    logger.info("В результатах команды дубликатов не найдено", category: .network)
                }
                
                for bookmark in commandResults.prefix(10) {
                    logger.debug("Результат команды: id=\(bookmark.id), fileName=\(bookmark.fileName), contentType=\(bookmark.contentType.rawValue), fileUrl=\(bookmark.fileUrl ?? "nil"), timestamp=\(bookmark.timestamp), summary=\(bookmark.summary?.prefix(50) ?? "nil")", category: .network)
                }
            } else {
                logger.debug("Команда не вернула результатов для отладки", category: .network)
            }
            
            return CommandResponse(
                intent: response.intent,
                html: html,
                results: commandResults
            )
            
        } catch {
            logger.error("Error выполнения команды: \(error)", category: .network)
            throw error
        }
    }
    
    struct CategoryBookmarksResult {
        let bookmarks: [Bookmark]
        let actualCategory: String

    }
    
    func getBookmarksForFolder(category: String) async throws -> CategoryBookmarksResult {
        
        struct CategoryBookmarksResponse: Codable {
            let category: String
            let bookmarks: [Bookmark]
        }
        
        let endpoint = Constants.API.Endpoints.categoryBookmarks(category: category)
        logger.info("Запрос к категории: endpoint='\(endpoint)', category='\(category)'", category: .network)
        
        do {
            let response: CategoryBookmarksResponse = try await networkService.request(
                endpoint: endpoint,
                method: "GET"
            )
            
            let actualCategory = response.category
            
            if response.bookmarks.isEmpty {
                BookmarkCacheService.shared.clearCache(for: actualCategory)
                logger.info("Сервер вернул 0 закладок для '\(category)', кеш очищен", category: .network)
            } else {
            BookmarkCacheService.shared.saveBookmarks(response.bookmarks, for: actualCategory)
            }
            
            if response.bookmarks.isEmpty && actualCategory != category {
                BookmarkCacheService.shared.clearCache(for: category)
                logger.info("Дополнительно очищен кеш для исходного названия категории '\(category)'", category: .network)
            }
            
            logger.info("Запрос успешен: получено закладок для папки '\(category)': \(response.bookmarks.count)", category: .network)
            logger.info("Ответ сервера для категории '\(category)': actualCategory='\(actualCategory)', bookmarks.count=\(response.bookmarks.count)", category: .network)
            
            if actualCategory != category {
                logger.info("Сервер вернул другое название категории: запросили '\(category)', получили '\(actualCategory)'", category: .network)
            }
            
            if !response.bookmarks.isEmpty {
                for bookmark in response.bookmarks.prefix(3) {
                    let voiceNoteInfo = bookmark.voiceNote != nil && !bookmark.voiceNote!.isEmpty ? "voiceNote='\(bookmark.voiceNote!.prefix(50))'" : "voiceNote=nil"
                    let summaryInfo: String
                    if let summary = bookmark.summary, !summary.isEmpty {
                        summaryInfo = "summary='\(summary.prefix(100))' (длина: \(summary.count))"
                    } else {
                        summaryInfo = "summary=nil"
                    }
                    logger.debug("Закладка: id=\(bookmark.id), fileName=\(bookmark.fileName), contentType=\(bookmark.contentType.rawValue), \(voiceNoteInfo), \(summaryInfo), displayDescription='\(bookmark.displayDescription.prefix(100))' (длина: \(bookmark.displayDescription.count))", category: .network)
                    
                    if bookmark.voiceNote != nil && !bookmark.voiceNote!.isEmpty && bookmark.summary != nil && !bookmark.summary!.isEmpty {
                        logger.warning("Закладка \(bookmark.id) имеет и voiceNote и summary. Должен использоваться только voiceNote для отображения.", category: .network)
                    }
                }
            }
            
            
            return CategoryBookmarksResult(bookmarks: response.bookmarks, actualCategory: actualCategory)
            
        } catch {
            let nsError = error as NSError
            let isTimeout = (nsError.domain == "NSURLErrorDomain" || nsError.domain == "kCFErrorDomainCFNetwork") && nsError.code == -1001
            
            if isTimeout {
                logger.warning("Таймаут при загрузке закладок для категории '\(category)', пробуем использовать кеш", category: .network)
                
                if let cachedBookmarks = BookmarkCacheService.shared.getCachedBookmarks(for: category) {
                    logger.info("Используем закладки из кеша для категории '\(category)': \(cachedBookmarks.count)", category: .network)
                    return CategoryBookmarksResult(bookmarks: cachedBookmarks, actualCategory: category)
                } else {
                    logger.warning("Кеш для категории '\(category)' отсутствует или истек, пробуем альтернативное название", category: .network)
                }
            }
            
            logger.error("Error загрузки закладок для папки: \(error)", category: .network)
            throw error
        }
    }
}

protocol SearchServiceProviding {
    func getFolders() async throws -> [Folder]
    func search(query: String, folderId: String?, bookmarkId: String?) async throws -> SearchResponse
    func searchInFolder(folderId: String, query: String) async throws -> [Bookmark]
    func executeCommand(query: String, folderId: String?, bookmarkId: String?) async throws -> CommandResponse
    func getBookmarksForFolder(category: String) async throws -> SearchService.CategoryBookmarksResult
}

extension SearchService: SearchServiceProviding {}
