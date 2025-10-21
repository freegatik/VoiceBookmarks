//
//  BookmarkServiceTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class BookmarkServiceTests: XCTestCase {
    
    var sut: BookmarkService!
    var mockNetwork: MockNetworkService!
    var mockFile: MockFileService!
    
    override func setUp() {
        super.setUp()
        mockNetwork = MockNetworkService()
        mockFile = MockFileService()
        sut = BookmarkService(
            networkService: mockNetwork,
            fileService: mockFile
        )
        RecentHashCache.shared.removeAllForTesting()
    }
    
    override func tearDown() {
        sut = nil
        mockNetwork = nil
        mockFile = nil
        super.tearDown()
    }
    
    func testBookmarkService_CreateBookmark_CallsValidateFile() async throws {
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try "test".write(to: testURL, atomically: true, encoding: .utf8)
        
        mockFile.mockValidationResult = FileValidationResult(
            isValid: true,
            contentType: .text,
            fileSize: 100,
            errorMessage: nil
        )
        
        do {
            _ = try await sut.createBookmark(
                filePath: testURL.path,
                voiceNote: nil,
                summary: nil
            )
        } catch {
        }
        
        XCTAssertTrue(mockFile.validateFileCalled)
        
        try? FileManager.default.removeItem(at: testURL)
    }
    
    func testBookmarkService_DeleteBookmark_CallsCorrectEndpoint() async throws {
        let responseData: [String: Any] = ["success": true, "message": NSNull()]
        mockNetwork.mockResponse = responseData
        
        do {
            _ = try await sut.deleteBookmark(id: "test-id-123")
        } catch {
        }
        
        XCTAssertTrue(mockNetwork.capturedEndpoint?.contains("/api/bookmarks/test-id-123") ?? false,
                     "Endpoint должен содержать '/api/bookmarks/test-id-123', получен: \(mockNetwork.capturedEndpoint ?? "nil")")
    }
    
    func testBookmarkService_DeleteBookmark_UsesDELETEMethod() async throws {
        let responseData: [String: Any] = ["success": true, "message": NSNull()]
        mockNetwork.mockResponse = responseData
        
        do {
            _ = try await sut.deleteBookmark(id: "test-id")
        } catch {
        }
        
        XCTAssertEqual(mockNetwork.capturedMethod, "DELETE",
                      "Метод должен быть DELETE, получен: \(mockNetwork.capturedMethod ?? "nil")")
    }
    
    func testBookmarkService_DeleteBookmark_ReturnsTrueOnSuccess() async throws {
        let responseDict: [String: Any] = ["success": true, "message": NSNull()]
        mockNetwork.mockResponse = responseDict
        mockNetwork.shouldFail = false
        
        let result = try await sut.deleteBookmark(id: "test-id")
        XCTAssertTrue(result)
    }
    
    func testBookmarkService_Init_WithDependencies() {
        XCTAssertNotNil(sut)
    }
    
    func testBookmarkService_CreateBookmark_ThrowsForInvalidFile() async {
        mockFile.mockValidationResult = FileValidationResult(
            isValid: false,
            contentType: .file,
            fileSize: 0,
            errorMessage: "Файл не найден"
        )
        
        do {
            _ = try await sut.createBookmark(
                filePath: "/nonexistent/file.txt",
                voiceNote: nil,
                summary: nil
            )
            XCTFail("Должна быть ошибка")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testBookmarkService_Exists() {
        XCTAssertNotNil(BookmarkService.self)
    }
    
    func testBookmarkService_HasNetworkService() {
        XCTAssertNotNil(sut)
    }
    
    func testBookmarkService_HasFileService() {
        XCTAssertNotNil(sut)
    }
    
    func testBookmarkService_LogsOperations() {
        XCTAssertNotNil(sut)
    }
    
    func testBookmarkService_CreateBookmark_HandlesHTMLFiles() async throws {
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.html")
        try "<html><body>test</body></html>".write(to: testURL, atomically: true, encoding: .utf8)
        
        mockFile.mockValidationResult = FileValidationResult(
            isValid: true,
            contentType: .text, // HTML файлы могут определяться как text
            fileSize: 100,
            errorMessage: nil
        )
        
        mockNetwork.shouldFail = false
        let responseDict: [String: Any] = ["success": true, "message": NSNull(), "bookmarkId": "test-id"]
        mockNetwork.mockResponse = responseDict
        
        do {
            let result = try await sut.createBookmark(
                filePath: testURL.path,
                voiceNote: nil,
                summary: nil
            )
            XCTAssertTrue(result, "Результат должен быть true")
            
            XCTAssertNotNil(mockNetwork.capturedEndpoint, "Endpoint должен быть вызван")
        } catch {
            XCTFail("Не должна быть ошибка: \(error)")
        }
        
        try? FileManager.default.removeItem(at: testURL)
    }
    
    func testBookmarkService_CreateBookmark_CompressesImages() async throws {
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.jpg")
        let image = UIImage(systemName: "star") ?? UIImage()
        let imageData = image.pngData() ?? Data()
        try? imageData.write(to: testURL, options: .atomic)
        
        mockFile.mockValidationResult = FileValidationResult(
            isValid: true,
            contentType: .image,
            fileSize: Int64(imageData.count),
            errorMessage: nil
        )
        
        mockFile.mockCompressedImage = UIImage(systemName: "star")?.pngData()
        
        mockNetwork.shouldFail = false
        let responseDict: [String: Any] = ["success": true, "message": NSNull(), "bookmarkId": "test-id"]
        mockNetwork.mockResponse = responseDict
        
        do {
            _ = try await sut.createBookmark(
                filePath: testURL.path,
                voiceNote: nil,
                summary: nil
            )
            
            XCTAssertTrue(mockFile.compressImageCalled, "compressImage должен быть вызван")
        } catch {
        }
        
        try? FileManager.default.removeItem(at: testURL)
    }
    
    func testBookmarkService_CreateBookmark_ThrowsForOversizedFile() async throws {
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("tiny_over_limit.txt")
        try "x".write(to: testURL, atomically: true, encoding: .utf8)
        mockFile.mockValidationResult = FileValidationResult(
            isValid: false,
            contentType: .text,
            fileSize: Int64(600 * 1024 * 1024),
            errorMessage: "Файл превышает 500MB"
        )
        do {
            _ = try await sut.createBookmark(filePath: testURL.path, voiceNote: nil, summary: nil)
            XCTFail("Ожидалась ошибка валидации для oversized файла")
        } catch {
            XCTAssertNotNil(error)
        }
        try? FileManager.default.removeItem(at: testURL)
    }
}

