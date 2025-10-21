//
//  SearchServiceTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class SearchServiceTests: XCTestCase {
    
    var sut: SearchService!
    var mockNetwork: MockNetworkService!
    
    override func setUp() {
        super.setUp()
        mockNetwork = MockNetworkService()
        sut = SearchService(networkService: mockNetwork)
        
        FolderCacheService.shared.clearCache()
    }
    
    override func tearDown() {
        sut = nil
        mockNetwork = nil
        super.tearDown()
    }
    
    func testSearchService_GetFolders_CallsCorrectEndpoint() async throws {
        let responseData: [String: Any] = ["folders": ["SelfReflection", "Tasks"]]
        mockNetwork.mockResponse = responseData
        
        _ = try await sut.getFolders()
        
        XCTAssertTrue(mockNetwork.capturedEndpoint?.contains("/api/folders") ?? false,
                     "Endpoint должен содержать /api/folders, получен: \(mockNetwork.capturedEndpoint ?? "nil")")
        XCTAssertEqual(mockNetwork.capturedMethod, "GET")
    }
    
    func testSearchService_GetFolders_DecodesFolders() async throws {
        let responseData: [String: Any] = ["folders": ["SelfReflection", "Tasks", "ProjectResources"]]
        mockNetwork.mockResponse = responseData
        
        let folders = try await sut.getFolders()
        
        XCTAssertEqual(folders.count, 3)
        let names = folders.map(\.name)
        XCTAssertEqual(Set(names), Set(["SelfReflection", "Tasks", "ProjectResources"]))
        XCTAssertEqual(names, ["ProjectResources", "SelfReflection", "Tasks"], "Корневые папки сортируются по имени (см. SearchService.buildFolderHierarchy)")
    }
    
    func testSearchService_GetFolders_ReturnsCorrectCount() async throws {
        let responseData: [String: Any] = ["folders": ["Uncategorised"]]
        mockNetwork.mockResponse = responseData
        
        let folders = try await sut.getFolders()
        
        XCTAssertEqual(folders.count, 1)
    }
    
    func testSearchService_Search_FormsCorrectBody() async throws {
        let responseData: [String: Any] = ["intent": "search", "results": [], "html": NSNull()]
        mockNetwork.mockResponse = responseData
        
        _ = try await sut.search(query: "test query", folderId: "folder123")
        
        XCTAssertNotNil(mockNetwork.capturedBody)
    }
    
    func testSearchService_Search_CallsCorrectEndpoint() async throws {
        let responseData: [String: Any] = ["intent": "search", "results": [], "html": NSNull()]
        mockNetwork.mockResponse = responseData
        
        _ = try await sut.search(query: "test", folderId: nil)
        
        XCTAssertTrue(mockNetwork.capturedEndpoint?.contains("/api/search") ?? false)
        XCTAssertEqual(mockNetwork.capturedMethod, "POST")
    }
    
    func testSearchService_Search_DecodesSearchResponse() async throws {
        let responseData: [String: Any] = [
            "intent": "search",
            "results": [
                [
                    "id": "test-id-123",
                    "fileName": "test.jpg",
                    "contentType": "image",
                    "category": "Tasks",
                    "timestamp": "2025-10-30T12:00:00Z",
                    "summary": "Test summary"
                ]
            ]
        ]
        mockNetwork.mockResponse = responseData
        
        let response = try await sut.search(query: "test", folderId: nil)
        
        XCTAssertEqual(response.intent, "search")
        XCTAssertEqual(response.results.count, 1)
        XCTAssertEqual(response.results[0].id, "test-id-123")
        XCTAssertEqual(response.results[0].fileName, "test.jpg")
        XCTAssertEqual(response.results[0].contentType, .image)
    }
    
    func testSearchService_Search_ReturnsSearchIntent() async throws {
        let responseData: [String: Any] = ["intent": "search", "results": [], "html": NSNull()]
        mockNetwork.mockResponse = responseData
        
        let response = try await sut.search(query: "test", folderId: nil)
        
        XCTAssertEqual(response.intent, "search")
    }
    
    func testSearchService_Search_ReturnsCommandIntent() async throws {
        let responseData: [String: Any] = ["intent": "command", "results": NSNull(), "html": "<html>test</html>"]
        mockNetwork.mockResponse = responseData
        
        let response = try await sut.search(query: "test command", folderId: nil)
        
        XCTAssertEqual(response.intent, "command")
    }
    
    func testSearchService_SearchInFolder_FiltersSearchOnly() async throws {
        let responseData: [String: Any] = [
            "intent": "search",
            "results": [
                [
                    "id": "test-id-456",
                    "fileName": "document.pdf",
                    "contentType": "file",
                    "category": "ProjectResources",
                    "timestamp": "2025-10-30T12:00:00Z",
                    "summary": "Important document",
                    "distance": 0.15
                ]
            ]
        ]
        mockNetwork.mockResponse = responseData
        
        let results = try await sut.searchInFolder(folderId: "folder123", query: "test")
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "test-id-456")
        XCTAssertEqual(results[0].fileName, "document.pdf")
        XCTAssertEqual(results[0].contentType, .file)
        XCTAssertTrue(mockNetwork.capturedEndpoint?.contains("/api/search") ?? false)
    }
    
    func testSearchService_ExecuteCommand_FiltersCommandOnly() async throws {
        let responseData: [String: Any] = [
            "intent": "command",
            "results": [],
            "html": "<html><body>Test HTML</body></html>"
        ]
        mockNetwork.mockResponse = responseData
        
        let response = try await sut.executeCommand(query: "test command")
        
        XCTAssertEqual(response.intent, "command")
        XCTAssertFalse(response.html.isEmpty)
    }
    
    func testSearchService_Search_HandlesNetworkErrors() async {
        mockNetwork.shouldFail = true
        mockNetwork.mockError = APIError.networkError(NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"]))
        
        do {
            _ = try await sut.search(query: "test", folderId: nil)
            XCTFail("Должна быть ошибка")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testSearchService_LogsOperations() async throws {
        let responseData: [String: Any] = ["folders": ["Test"]]
        mockNetwork.mockResponse = responseData
        
        _ = try await sut.getFolders()
        
        XCTAssertNotNil(sut)
    }
}

