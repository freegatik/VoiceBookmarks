//
//  NetworkService.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Сетевые запросы: HTTP, retry, кодировка URL (кириллица), таймауты, upload/download

class NetworkService {
    
    private let baseURL: String
    private let session: URLSession
    private var userId: String?
    private let logger = LoggerService.shared
    
    init(baseURL: String = Constants.API.baseURL, session: URLSession? = nil) {
        self.baseURL = baseURL
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 90
            config.allowsCellularAccess = true
            config.httpMaximumConnectionsPerHost = 4
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.networkServiceType = .default
            self.session = URLSession(configuration: config)
        }
    }
    
    func setUserId(_ userId: String) {
        self.userId = userId
        logger.info("UserId установлен для сетевых запросов", category: .network)
    }
    
    
    /// Формирует URL с правильной кодировкой кириллицы в путях
    /// Использует URLComponents и percent encoding для корректной обработки русских символов
    private func buildURL(endpoint: String) throws -> URL {
        guard let baseURLComponents = URLComponents(string: baseURL) else {
            logger.error("Invalid base URL: \(baseURL)", category: .network)
            throw APIError.serverError(message: "Invalid base URL")
        }
        
        let normalizedEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
        
        var urlComponents = baseURLComponents
        let basePath = baseURLComponents.path
        var pathComponents: [String] = []
        
        if !basePath.isEmpty {
            pathComponents.append(contentsOf: basePath.split(separator: "/").map { String($0) })
        }
        
        pathComponents.append(contentsOf: normalizedEndpoint.split(separator: "/").map { String($0) })
        
        let encodedComponents = pathComponents.map { component in
            if let encoded = component.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                return encoded
            }
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
            if let encoded = component.addingPercentEncoding(withAllowedCharacters: allowed) {
                return encoded
            }
            logger.warning("Не удалось закодировать компонент пути: \(component)", category: .network)
            return component
        }
        
        urlComponents.percentEncodedPath = "/" + encodedComponents.joined(separator: "/")
        
        logger.debug("URL сформирован: \(urlComponents.url?.absoluteString ?? "nil"), исходный endpoint: \(endpoint)", category: .network)
        
        guard let url = urlComponents.url else {
            logger.error("Invalid URL: baseURL=\(baseURL), endpoint=\(endpoint)", category: .network)
            throw APIError.serverError(message: "Invalid URL")
        }
        
        return url
    }
    
    
    /// Выполняет HTTP запрос с retry логикой и правильной обработкой ошибок
    /// Retry применяется только для сетевых ошибок и 5xx, не для 4xx
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        logger.logNetworkRequest(method: method, endpoint: endpoint)
        
        let url = try buildURL(endpoint: endpoint)
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if body != nil {
        request.setValue(Constants.API.Headers.contentTypeJSON, forHTTPHeaderField: Constants.API.Headers.contentType)
        }
        
        if let userId = userId {
            request.setValue(userId, forHTTPHeaderField: Constants.API.Headers.userID)
        }
        
        if endpoint.contains("/categories/") {
            logger.info("Запрос к категории: \(method) \(url.absoluteString), заголовки: X-User-ID=\(userId ?? "отсутствует"), таймаут запроса: 30с, таймаут ресурса: 90с", category: .network)
        } else {
            logger.debug("Запрос: \(method) \(url.absoluteString), заголовки: X-User-ID=\(userId ?? "отсутствует"), таймаут запроса: 30с, таймаут ресурса: 90с", category: .network)
        }
        
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
                logger.debug("Body размер: \(request.httpBody?.count ?? 0) байт", category: .network)
            } catch {
                logger.error("Error кодирования body в JSON: \(error)", category: .network)
                throw APIError.decodingError(error)
            }
        }
        
        var lastError: Error?
        
        for attempt in 1...Constants.API.retryCount {
            let attemptStartTime = Date()
            logger.debug("Попытка \(attempt)/\(Constants.API.retryCount) для \(endpoint)", category: .network)
            
            do {
                logger.debug("Начало выполнения запроса для попытки \(attempt), URL: \(url.absoluteString)", category: .network)
                let (data, response) = try await session.data(for: request)
                let attemptDuration = Date().timeIntervalSince(attemptStartTime)
                logger.debug("Попытка \(attempt) завершена за \(String(format: "%.2f", attemptDuration))с, размер ответа: \(data.count) байт", category: .network)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    logger.error("Ответ не является HTTPURLResponse", category: .network)
                    throw APIError.serverError(message: "Non-HTTP response")
                }
                
                let statusCode = httpResponse.statusCode
                
                if statusCode >= 400 {
                    let responseBody = String(data: data, encoding: .utf8) ?? "Не удалось декодировать"
                    let preview = responseBody.count > 500 ? String(responseBody.prefix(500)) + "..." : responseBody
                    logger.error("HTTP \(statusCode) для \(endpoint): \(preview)", category: .network)
                    if responseBody.count > 500 {
                        logger.debug("Полный ответ сервера (первые 1000 символов): \(String(responseBody.prefix(1000)))", category: .network)
                    }
                }
                
                switch statusCode {
                case 200...299:
                    let decoder = JSONDecoder()
                    let logger = self.logger
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)
                        
                        let dateFormatters: [DateFormatter] = [
                            {
                                let f = DateFormatter()
                                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
                                f.timeZone = TimeZone(secondsFromGMT: 0)
                                f.locale = Locale(identifier: "en_US_POSIX")
                                return f
                            }(),
                            {
                                let f = DateFormatter()
                                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                                f.timeZone = TimeZone(secondsFromGMT: 0)
                                f.locale = Locale(identifier: "en_US_POSIX")
                                return f
                            }()
                        ]
                        
                        let iso8601Formatters: [ISO8601DateFormatter] = [
                            {
                                let f = ISO8601DateFormatter()
                                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                return f
                            }(),
                            {
                                let f = ISO8601DateFormatter()
                                f.formatOptions = [.withInternetDateTime]
                                return f
                            }()
                        ]
                        
                        for formatter in dateFormatters {
                            if let date = formatter.date(from: dateString) {
                                return date
                            }
                        }
                        
                        for formatter in iso8601Formatters {
                            if let date = formatter.date(from: dateString) {
                                return date
                            }
                        }
                        
                        logger.error("Не удалось декодировать дату: \(dateString), выбрасываем ошибку", category: .network)
                        throw DecodingError.dataCorruptedError(
                            in: container,
                            debugDescription: "Не удалось распарсить дату: \(dateString)"
                        )
                    }
                    
                    if endpoint.contains("/categories/") {
                        let responseBody = String(data: data, encoding: .utf8) ?? "Не удалось декодировать"
                        logger.info("Запрос к категории успешен: \(endpoint), статус: \(statusCode), размер ответа: \(data.count) байт", category: .network)
                        if responseBody.count < 500 {
                            logger.info("Тело ответа для категории: \(responseBody)", category: .network)
                        }
                    }
                    
                    do {
                        let decoded = try decoder.decode(T.self, from: data)
                        logger.info("Запрос успешен: \(endpoint)", category: .network)
                        return decoded
                    } catch {
                        logger.error("Error декодирования JSON: \(error)", category: .network)
                        throw APIError.decodingError(error)
                    }
                    
                case 401:
                    logger.error("401 Unauthorized: \(endpoint)", category: .network)
                    throw APIError.unauthorized
                    
                case 429:
                    logger.warning("Rate limiting (429), попытка \(attempt)/\(Constants.API.retryCount)", category: .network)
                    
                    let backoffDelay = pow(2.0, Double(attempt)) * Constants.API.retryDelay
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) } ?? backoffDelay
                    
                    lastError = APIError.httpError(statusCode: 429)
                    
                    if attempt < Constants.API.retryCount {
                        logger.info("Ожидание \(retryAfter) секунд перед retry для rate limiting", category: .network)
                        try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                    }
                    continue
                    
                case 400...499:
                    logger.error("HTTP \(statusCode): \(endpoint)", category: .network)
                    throw APIError.httpError(statusCode: statusCode)
                    
                case 500...599:
                    let responseBody = String(data: data, encoding: .utf8) ?? ""
                    let isInvalidCategory = responseBody.contains("Неверная категория") || responseBody.contains("неверная категория")
                    
                    if isInvalidCategory {
                        logger.error("HTTP \(statusCode) с 'Неверная категория', не делаем retry: \(endpoint)", category: .network)
                        throw APIError.serverError(message: responseBody)
                    }
                    
                    logger.warning("HTTP \(statusCode), попытка \(attempt)/\(Constants.API.retryCount)", category: .network)
                    lastError = APIError.httpError(statusCode: statusCode)
                    
                    if attempt < Constants.API.retryCount {
                        try await Task.sleep(nanoseconds: UInt64(Constants.API.retryDelay * 1_000_000_000))
                    }
                    continue
                    
                default:
                    throw APIError.httpError(statusCode: statusCode)
                }
                
            } catch let error as APIError {
                if case .httpError(let code) = error, code >= 400 && code < 500 {
                    throw error
                }
                if case .unauthorized = error {
                    throw error
                }
                if case .serverError(let message) = error, message == "Non-HTTP response" {
                    throw error
                }
                
                lastError = error
                
                if attempt < Constants.API.retryCount {
                    logger.warning("Сетевая ошибка, попытка \(attempt)/\(Constants.API.retryCount)", category: .network)
                    try await Task.sleep(nanoseconds: UInt64(Constants.API.retryDelay * 1_000_000_000))
                }
                
            } catch {
                let attemptDuration = Date().timeIntervalSince(attemptStartTime)
                let nsError = error as NSError
                let errorDetails = "Домен: \(nsError.domain), код: \(nsError.code), описание: \(nsError.localizedDescription)"
                
                if nsError.code == -1001 {
                    logger.error("Таймаут запроса после \(String(format: "%.2f", attemptDuration))с для \(endpoint). URL: \(url.absoluteString)", category: .network)
                } else {
                    logger.error("Сетевая ошибка после \(String(format: "%.2f", attemptDuration))с: \(errorDetails)", category: .network)
                }
                
                lastError = APIError.networkError(error)
                
                if attempt < Constants.API.retryCount {
                    logger.warning("Сетевая ошибка, попытка \(attempt)/\(Constants.API.retryCount): \(error.localizedDescription)", category: .network)
                    try await Task.sleep(nanoseconds: UInt64(Constants.API.retryDelay * 1_000_000_000))
                } else {
                    logger.error("Все попытки исчерпаны для \(endpoint), последняя ошибка: \(errorDetails), общее время: \(String(format: "%.2f", attemptDuration))с", category: .network)
                }
            }
        }
        
        if let lastError = lastError {
            logger.error("Все попытки исчерпаны для \(endpoint), последняя ошибка: \(lastError)", category: .network)
            throw lastError
        } else {
            logger.error("Неожиданная ошибка: нет lastError после всех попыток для \(endpoint)", category: .network)
            throw APIError.networkError(NSError(domain: "NetworkService", code: -1))
        }
    }
    
    
    /// Загружает файл на сервер (multipart/form-data) с увеличенными таймаутами для больших файлов
    /// Таймауты рассчитываются динамически на основе размера файла
    func upload(
        data: Data,
        fileName: String,
        endpoint: String,
        parameters: [String: String]
    ) async throws -> Data {
        
        let url = try buildURL(endpoint: endpoint)
        
        let fileSizeMB = Double(data.count) / (1024 * 1024)
        let calculatedTimeout = max(180, 180 + (fileSizeMB * 30))
        let resourceTimeout = max(600, calculatedTimeout * 3)
        
        logger.debug("Размер файла: \(String(format: "%.2f", fileSizeMB))MB, таймаут запроса: \(Int(calculatedTimeout))сек, таймаут ресурса: \(Int(resourceTimeout))сек", category: .network)
        
        let uploadConfig = URLSessionConfiguration.default
        uploadConfig.timeoutIntervalForRequest = calculatedTimeout
        uploadConfig.timeoutIntervalForResource = resourceTimeout
        uploadConfig.allowsCellularAccess = true
        uploadConfig.httpMaximumConnectionsPerHost = 4
        uploadConfig.urlCache = nil
        uploadConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        if let protocolClasses = session.configuration.protocolClasses, !protocolClasses.isEmpty {
            uploadConfig.protocolClasses = protocolClasses
        }
        let uploadSession = URLSession(configuration: uploadConfig)
        
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var lastError: Error?
        
        for attempt in 1...Constants.API.retryCount {
            if attempt == 1 {
                logger.info("upload вызван с параметрами: \(parameters.keys.joined(separator: ", "))", category: .network)
                if parameters["voiceNote"] != nil {
                    logger.info("voiceNote присутствует в parameters для upload, длина: \(parameters["voiceNote"]?.count ?? 0)", category: .network)
                } else {
                    logger.warning("voiceNote отсутствует в parameters для upload", category: .network)
                }
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: Constants.API.Headers.contentType)
            
            if let userId = userId {
                request.setValue(userId, forHTTPHeaderField: Constants.API.Headers.userID)
            }
            
            var body = Data()
            
            for (key, value) in parameters {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            
            request.httpBody = body
            
            do {
                let (responseData, response) = try await uploadSession.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    logger.error("Ответ не является HTTPURLResponse", category: .network)
                    throw APIError.serverError(message: "Non-HTTP response")
                }
                
                let statusCode = httpResponse.statusCode
                
                switch statusCode {
                case 200...299:
                    return responseData
                    
                case 401:
                    logger.error("401 Unauthorized при upload: \(endpoint)", category: .network)
                    throw APIError.unauthorized
                    
                case 429:
                    logger.warning("Rate limiting (429) при upload, попытка \(attempt)/\(Constants.API.retryCount)", category: .network)
                    lastError = APIError.httpError(statusCode: 429)
                    if attempt < Constants.API.retryCount {
                        let backoffDelay = pow(2.0, Double(attempt)) * Constants.API.retryDelay
                        let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) } ?? backoffDelay
                        logger.info("Ожидание \(retryAfter) секунд перед retry для rate limiting", category: .network)
                        try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                    }
                    continue
                    
                case 400...499:
                    logger.error("HTTP \(statusCode) при upload: \(endpoint)", category: .network)
                    throw APIError.httpError(statusCode: statusCode)
                    
                case 500...599:
                    let responseBody = String(data: data, encoding: .utf8) ?? "Не удалось декодировать"
                    logger.warning("HTTP \(statusCode) при upload, попытка \(attempt)/\(Constants.API.retryCount), ответ: \(responseBody)", category: .network)
                    lastError = APIError.httpError(statusCode: statusCode)
                    if attempt < Constants.API.retryCount {
                        try await Task.sleep(nanoseconds: UInt64(Constants.API.retryDelay * 1_000_000_000))
                    }
                    continue
                    
                default:
                    throw APIError.httpError(statusCode: statusCode)
                }
                
            } catch let error as APIError {
                if case .httpError(let code) = error, code >= 400 && code < 500 {
                    throw error
                }
                if case .unauthorized = error {
                    throw error
                }
                
                lastError = error
                
                if attempt < Constants.API.retryCount {
                    logger.warning("Сетевая ошибка при upload, попытка \(attempt)/\(Constants.API.retryCount): \(error)", category: .network)
                    try await Task.sleep(nanoseconds: UInt64(Constants.API.retryDelay * 1_000_000_000))
                }
                
            } catch {
                let nsError = error as NSError
                let isTimeout = (nsError.domain == "NSURLErrorDomain" || nsError.domain == "kCFErrorDomainCFNetwork") && nsError.code == -1001
                
                lastError = APIError.networkError(error)
                
                if attempt < Constants.API.retryCount {
                    let errorMsg = isTimeout ? "таймаут" : "сетевая ошибка"
                    logger.warning("\(errorMsg) при upload, попытка \(attempt)/\(Constants.API.retryCount): \(error.localizedDescription)", category: .network)
                    
                    let delay: TimeInterval
                    if isTimeout {
                        delay = pow(2.0, Double(attempt))
                        logger.debug("Экспоненциальная задержка для таймаута: \(Int(delay)) секунд", category: .network)
                    } else {
                        delay = Constants.API.retryDelay
                    }
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    logger.error("Все попытки upload исчерпаны для \(fileName)", category: .network)
                }
            }
        }
        
        if let lastError = lastError {
            logger.error("Все попытки upload исчерпаны для \(fileName), последняя ошибка: \(lastError)", category: .network)
            throw lastError
        } else {
            logger.error("Неожиданная ошибка: нет lastError после всех попыток upload для \(fileName)", category: .network)
            throw APIError.networkError(NSError(domain: "NetworkService", code: -1))
        }
    }
    
    func downloadFile(bookmarkId: String) async throws -> Data {
        let trimmedBookmarkId = bookmarkId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBookmarkId.isEmpty else {
            logger.error("downloadFile: пустой bookmarkId", category: .network)
            throw APIError.serverError(message: "Invalid bookmark ID")
        }
        
        let uuidPattern = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        let isValidUUID = trimmedBookmarkId.range(of: uuidPattern, options: .regularExpression, range: nil, locale: nil) != nil
        if !isValidUUID {
            logger.warning("downloadFile: bookmarkId не соответствует формату UUID: '\(trimmedBookmarkId)'", category: .network)
        }
        
        let endpoint = "\(Constants.API.Endpoints.download)/\(trimmedBookmarkId)"
        
        let url = try buildURL(endpoint: endpoint)
        
        logger.info("Download файла: bookmarkId=\(trimmedBookmarkId), endpoint=\(endpoint), URL=\(url.absoluteString), заголовки: X-User-ID=\(userId ?? "отсутствует")", category: .network)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let userId = userId {
            request.setValue(userId, forHTTPHeaderField: Constants.API.Headers.userID)
        }
        
        let requestStartTime = Date()
        
        do {
            let (data, response) = try await session.data(for: request)
            let requestDuration = Date().timeIntervalSince(requestStartTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("downloadFile: ответ не является HTTPURLResponse для bookmarkId=\(trimmedBookmarkId)", category: .network)
                throw APIError.serverError(message: "Non-HTTP response")
            }
            
            let statusCode = httpResponse.statusCode
            
            if statusCode >= 400 {
                let responseBodyUTF8 = String(data: data, encoding: .utf8)
                let responseBodyLatin1 = String(data: data, encoding: .isoLatin1)
                
                let responseBody = responseBodyUTF8 ?? responseBodyLatin1 ?? "Не удалось декодировать (пробовали UTF-8 и Latin-1)"
                let preview = responseBody.count > 500 ? String(responseBody.prefix(500)) + "..." : responseBody
                
                let encodingInfo = responseBodyUTF8 != nil ? "UTF-8" : (responseBodyLatin1 != nil ? "Latin-1" : "неизвестная")
                logger.error("HTTP \(statusCode) при download: bookmarkId=\(trimmedBookmarkId), endpoint=\(endpoint), размер ответа: \(data.count) байт, кодировка: \(encodingInfo), время запроса: \(String(format: "%.2f", requestDuration))с", category: .network)
                logger.error("Тело ответа: \(preview)", category: .network)
                
                if statusCode >= 500 {
                    if responseBody.count <= 1000 {
                        logger.error("Полный ответ сервера при ошибке 500: \(responseBody)", category: .network)
                    } else {
                        logger.error("Полный ответ сервера при ошибке 500 (первые 1000 символов): \(String(responseBody.prefix(1000)))", category: .network)
                    }
                }
            } else {
                logger.info("Download успешен: bookmarkId=\(trimmedBookmarkId), размер: \(data.count) байт, время запроса: \(String(format: "%.2f", requestDuration))с", category: .network)
            }
            
            switch statusCode {
            case 200...299:
                return data
                
            case 404:
                logger.error("File not found (404): bookmarkId=\(trimmedBookmarkId), endpoint=\(endpoint), URL=\(url.absoluteString), userId=\(userId ?? "отсутствует")", category: .network)
                logger.error("Диагностика 404: возможно файл не был загружен на сервер или был удален, проверьте наличие файла для bookmarkId=\(trimmedBookmarkId)", category: .network)
                throw APIError.serverError(message: "File not found")
                
            case 401:
                logger.error("401 Unauthorized при download: bookmarkId=\(trimmedBookmarkId), endpoint=\(endpoint), userId=\(userId ?? "отсутствует")", category: .network)
                throw APIError.unauthorized
                
            case 400...499:
                logger.error("HTTP \(statusCode) при download: bookmarkId=\(trimmedBookmarkId), endpoint=\(endpoint)", category: .network)
                throw APIError.httpError(statusCode: statusCode)
                
            case 500...599:
                let errorMessage = "Error сервера при download (возможно, проблема с кодировкой имени файла): bookmarkId=\(trimmedBookmarkId), endpoint=\(endpoint)"
                logger.error(errorMessage, category: .network)
                throw APIError.httpError(statusCode: statusCode)
                
            default:
                logger.error("Неожиданный статус код \(statusCode) при download: bookmarkId=\(trimmedBookmarkId), endpoint=\(endpoint)", category: .network)
                throw APIError.httpError(statusCode: statusCode)
            }
        } catch let error as APIError {
            let requestDuration = Date().timeIntervalSince(requestStartTime)
            logger.error("Error download файла (APIError): bookmarkId=\(trimmedBookmarkId), endpoint=\(endpoint), ошибка: \(error), время запроса: \(String(format: "%.2f", requestDuration))с", category: .network)
            throw error
        } catch {
            let requestDuration = Date().timeIntervalSince(requestStartTime)
            let nsError = error as NSError
            logger.error("Error download файла: bookmarkId=\(trimmedBookmarkId), endpoint=\(endpoint), домен: \(nsError.domain), код: \(nsError.code), описание: \(nsError.localizedDescription), время запроса: \(String(format: "%.2f", requestDuration))с", category: .network)
            throw APIError.networkError(error)
        }
    }
}
