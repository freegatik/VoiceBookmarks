//
//  MockNetworkService.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
@testable import VoiceBookmarks

class MockNetworkService: NetworkService {
    
    var mockResponse: Any?
    var mockError: Error?
    var capturedEndpoint: String?
    var capturedMethod: String?
    var capturedBody: Encodable?
    var shouldFail: Bool = false
    var setUserIdCalled = false
    var capturedUserId: String?
    
    override func request<T: Decodable>(
        endpoint: String,
        method: String,
        body: Encodable?
    ) async throws -> T {
        capturedEndpoint = endpoint
        capturedMethod = method
        capturedBody = body
        
        if shouldFail {
            if let error = mockError {
                throw error
            }
                   throw APIError.networkError(NSError(domain: "MockNetworkService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock network error"]))
        }
        
        if let error = mockError {
            throw error
        }
        
        if let response = mockResponse as? T {
            return response
        }
        
        if let dict = mockResponse as? [String: Any] {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dict)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                return try decoder.decode(T.self, from: jsonData)
            } catch let decodingError as DecodingError {
                switch decodingError {
                case .keyNotFound(let key, _):
                    print("ERROR MockNetworkService: ключ не найден - \(key.stringValue)")
                case .typeMismatch(let type, let context):
                    print("ERROR MockNetworkService: несоответствие типа - \(type) по пути \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("ERROR MockNetworkService: значение не найдено - \(type) по пути \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("ERROR MockNetworkService: поврежденные данные - \(context.debugDescription)")
                @unknown default:
                    print("ERROR MockNetworkService: неизвестная ошибка декодирования")
                }
                throw decodingError
            } catch {
                print("ERROR MockNetworkService: ошибка JSON - \(error)")
                throw APIError.noData
            }
        }
        
        throw APIError.noData
    }
    
    override func setUserId(_ userId: String) {
        setUserIdCalled = true
        capturedUserId = userId
    }
    
    var capturedUploadData: Data?
    var capturedUploadFileName: String?
    var capturedUploadParameters: [String: String]?
    var uploadCalled = false
    var mockUploadResponse: Data?
    
    override func upload(
        data: Data,
        fileName: String,
        endpoint: String,
        parameters: [String: String]
    ) async throws -> Data {
        uploadCalled = true
        capturedEndpoint = endpoint
        capturedUploadData = data
        capturedUploadFileName = fileName
        capturedUploadParameters = parameters
        
        if shouldFail {
            if let error = mockError {
                throw error
            }
            throw APIError.networkError(NSError(domain: "MockNetworkService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock upload error"]))
        }
        
        if let error = mockError {
            throw error
        }
        
        if let response = mockUploadResponse {
            return response
        }
        
        if let dict = mockResponse as? [String: Any] {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dict)
                return jsonData
            } catch {
                return """
                {
                    "success": true,
                    "message": null,
                    "bookmarkId": "test-id"
                }
                """.data(using: .utf8) ?? Data()
            }
        }
        
        return """
        {
            "success": true,
            "message": null,
            "bookmarkId": "test-id"
        }
        """.data(using: .utf8) ?? Data()
    }
}
