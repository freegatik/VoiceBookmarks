//
//  SearchViewModelTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class SearchViewModelTests: XCTestCase {
    
    var sut: SearchViewModel!
    var mockSearchService: MockSearchService!
    var mockSpeechService: MockSpeechService!
    
    override func setUp() {
        super.setUp()
        mockSearchService = MockSearchService()
        mockSpeechService = MockSpeechService()
        sut = SearchViewModel(
            searchService: mockSearchService,
            speechService: mockSpeechService
        )
    }
    
    override func tearDown() {
        sut = nil
        mockSearchService = nil
        mockSpeechService = nil
        super.tearDown()
    }
    
    func testSearchViewModel_Init_WithDependencies() {
        XCTAssertNotNil(sut.searchService)
        XCTAssertNotNil(sut.speechService)
    }
    
    func testSearchViewModel_LoadFolders_CallsSearchService() async {
        mockSearchService.mockFolders = [Folder(name: "Test")]
        
        await sut.loadFolders()
        
        XCTAssertTrue(mockSearchService.getFoldersCalled)
    }
    
    func testSearchViewModel_LoadFolders_UpdatesFolders() async {
        let testFolders = [Folder(name: "SelfReflection"), Folder(name: "Tasks")]
        mockSearchService.mockFolders = testFolders
        
        await sut.loadFolders()
        
        XCTAssertEqual(sut.folders.count, 2)
        XCTAssertEqual(sut.folders[0].name, "SelfReflection")
    }
    
    func testSearchViewModel_Folders_UseDisplayName() async {
        let testFolders = [
            Folder(name: "SelfReflection"),
            Folder(name: "Tasks"),
            Folder(name: "ProjectResources"),
            Folder(name: "Uncategorised")
        ]
        mockSearchService.mockFolders = testFolders
        
        await sut.loadFolders()
        
        XCTAssertEqual(sut.folders[0].displayName, "Саморефлексия")
        XCTAssertEqual(sut.folders[1].displayName, "Задачи")
        XCTAssertEqual(sut.folders[2].displayName, "Ресурсы проекта")
        XCTAssertEqual(sut.folders[3].displayName, "Без категории")
    }
    
    func testSearchViewModel_LoadFolders_SetsLoadingState() async {
        mockSearchService.mockFolders = []
        
        let expectation = XCTestExpectation(description: "Loading state changes")
        
        Task {
            await sut.loadFolders()
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        XCTAssertFalse(sut.isLoading)
    }
    
    func testSearchViewModel_HandleFolderTap_SetsSelectedFolder() {
        let folder = Folder(name: "TestFolder")
        
        sut.handleFolderTap(folder)
        
        XCTAssertEqual(sut.selectedFolder?.name, folder.name)
    }
    
    func testSearchViewModel_HandleFolderTap_CallsGetBookmarksForFolder() async {
        let folder = Folder(name: "TestFolder")
        mockSearchService.mockBookmarksForFolder = []
        
        sut.handleFolderTap(folder)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(mockSearchService.getBookmarksForFolderCalled)
        XCTAssertEqual(mockSearchService.lastCategory, folder.name)
    }
    
    func testSearchViewModel_HandleFolderLongPressStarted_StartsRecording() async {
        let folder = Folder(name: "TestFolder")
        mockSpeechService.mockTranscription = "test query"
        
        sut.handleFolderLongPressStarted(folder)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(mockSpeechService.startRecordingCalled)
        XCTAssertTrue(sut.isRecording)
    }
    
    func testSearchViewModel_HandleFolderLongPressStarted_SetsRecordingState() async {
        let folder = Folder(name: "TestFolder")
        
        sut.handleFolderLongPressStarted(folder)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(sut.isRecording)
    }
    
    func testSearchViewModel_HandleFolderLongPressEnded_StopsRecording() async {
        let folder = Folder(name: "TestFolder")
        mockSpeechService.mockTranscription = "test query"
        mockSearchService.mockSearchResponse = SearchResponse(intent: "search", results: [], html: nil)
        
        sut.handleFolderLongPressStarted(folder)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        sut.handleFolderLongPressEnded()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertTrue(mockSpeechService.stopRecordingCalled,
                     "stopRecording должен быть вызван после handleFolderLongPressEnded")
    }
    
    func testSearchViewModel_HandleFolderLongPressEnded_CallsPerformSearch() async {
        let folder = Folder(name: "TestFolder")
        mockSpeechService.mockTranscription = "test query"
        mockSearchService.mockSearchResponse = SearchResponse(intent: "search", results: [], html: nil)
        
        sut.handleFolderLongPressStarted(folder)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        sut.handleFolderLongPressEnded()
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertTrue(mockSearchService.searchCalled)
    }
    
    func testSearchViewModel_HandleFolderLongPressEnded_SendsFolderIdAndText() async {
        let folder = Folder(name: "TestFolder")
        mockSpeechService.mockTranscription = "test command"
        mockSearchService.mockSearchResponse = SearchResponse(intent: "command", results: [], html: "<html>result</html>")
        
        sut.handleFolderLongPressStarted(folder)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        sut.handleFolderLongPressEnded()
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertTrue(mockSearchService.searchCalled)
        let expectedQuery = TextPostProcessor().process("test command")
        XCTAssertEqual(mockSearchService.lastQuery, expectedQuery)
        XCTAssertEqual(mockSearchService.lastFolderId, folder.id)
    }
    
    func testSearchViewModel_HandleFolderLongPressEnded_DoesNotSendOnEmptyTranscription() async {
        let folder = Folder(name: "TestFolder")
        mockSpeechService.mockTranscription = ""
        
        sut.handleFolderLongPressStarted(folder)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        sut.handleFolderLongPressEnded()
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertFalse(mockSearchService.searchCalled)
        XCTAssertNil(sut.selectedFolder)
    }
    
    func testSearchViewModel_PerformSearch_SearchIntent_SetsSearchResults() async {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.jpg",
            contentType: .image,
            category: "Tasks",
            voiceNote: nil,
            fileUrl: nil,
            summary: "Test",
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        mockSearchService.mockSearchResponse = SearchResponse(intent: "search", results: [bookmark], html: nil)
        
        sut.performSearch(query: "test", folderId: nil)
        
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(sut.searchResults.count, 1)
        XCTAssertTrue(sut.showFileList)
    }
    
    func testSearchViewModel_PerformSearch_CommandIntent_CallsExecuteCommand() async {
        mockSearchService.mockSearchResponse = SearchResponse(intent: "command", results: [], html: "<html>test</html>")
        mockSearchService.mockCommandResponse = CommandResponse(
            intent: "command",
            html: "<html>test</html>",
            results: []
        )
        
        sut.performSearch(query: "test command", folderId: nil)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertNotNil(sut.commandHTML)
        XCTAssertTrue(sut.showWebView)
        XCTAssertFalse(sut.showFileList)
    }
    
    func testSearchViewModel_PerformSearch_SearchIntent_NavigatesToFileList() async {
        let folder = Folder(name: "TestFolder")
        sut.selectedFolder = folder
        
        mockSearchService.mockSearchResponse = SearchResponse(intent: "search", results: [], html: nil)
        
        sut.performSearch(query: "test", folderId: nil)
        
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertTrue(sut.showFileList)
        XCTAssertNotNil(sut.currentDestination)
    }
    
    func testSearchViewModel_PerformSearch_CommandIntent_NavigatesToWebView() async {
        mockSearchService.mockSearchResponse = SearchResponse(intent: "command", results: [], html: "<html>test</html>")
        mockSearchService.mockCommandResponse = CommandResponse(
            intent: "command",
            html: "<html>test</html>",
            results: []
        )
        
        sut.performSearch(query: "test command", folderId: nil)
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertTrue(sut.showWebView)
    }
    
    func testSearchViewModel_ResetSearch_ClearsState() {
        sut.selectedFolder = Folder(name: "Test")
        sut.searchResults = [Bookmark(
            id: "test",
            fileName: "test.jpg",
            contentType: .image,
            category: "Tasks",
            voiceNote: nil,
            fileUrl: nil,
            summary: "Test",
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )]
        sut.transcription = "test"
        sut.isRecording = true
        
        sut.resetSearch()
        
        XCTAssertNil(sut.selectedFolder)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertTrue(sut.transcription.isEmpty)
        XCTAssertFalse(sut.isRecording)
    }
    
    func testSearchViewModel_PerformTextSearch_CallsPerformSearch() async {
        mockSearchService.mockSearchResponse = SearchResponse(intent: "search", results: [], html: nil)
        sut.searchQuery = "test query"
        
        sut.performTextSearch(query: "test query")
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertTrue(mockSearchService.searchCalled)
        XCTAssertEqual(mockSearchService.lastQuery, "test query")
    }
    
    func testSearchViewModel_PerformTextSearch_RejectsEmptyQuery() {
        sut.performTextSearch(query: "   ")
        
        XCTAssertFalse(mockSearchService.searchCalled)
    }
    
    func testSearchViewModel_PerformTextSearch_ShowsToastOnEmptyQuery() {
        sut.performTextSearch(query: "   ")
        
        XCTAssertNotNil(sut.toast)
    }
    
    func testSearchViewModel_LoadFilesForFolder_CallsGetBookmarksForFolder() async {
        let folder = Folder(name: "TestFolder")
        mockSearchService.mockBookmarksForFolder = []
        
        await sut.loadFilesForFolder(folder)
        
        XCTAssertTrue(mockSearchService.getBookmarksForFolderCalled)
        XCTAssertEqual(mockSearchService.lastCategory, folder.name)
    }
    
    func testSearchViewModel_LoadFilesForFolder_UpdatesSearchResults() async {
        let folder = Folder(name: "TestFolder")
        let bookmarks = [
            Bookmark(
                id: "1",
                fileName: "test.jpg",
                contentType: .image,
                category: "TestFolder",
                voiceNote: nil,
                fileUrl: nil,
                summary: "Test",
                content: nil,
                contentHash: nil,
                timestamp: Date(),
                totalChunks: nil,
                distance: nil
            )
        ]
        mockSearchService.mockBookmarksForFolder = bookmarks
        
        await sut.loadFilesForFolder(folder)
        
        XCTAssertEqual(sut.searchResults.count, 1)
        XCTAssertEqual(sut.selectedFolder?.name, folder.name)
    }
    
    func testSearchViewModel_NavigateBack_ResetsCurrentDestination() {
        let folder = Folder(name: "TestFolder")
        let bookmark = Bookmark(
            id: "1",
            fileName: "test.jpg",
            contentType: .image,
            category: "TestFolder",
            voiceNote: nil,
            fileUrl: nil,
            summary: "Test",
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        sut.currentDestination = .fileList(folder, [bookmark])
        XCTAssertNotNil(sut.currentDestination)
        
        sut.navigateBack()
        
        XCTAssertNil(sut.currentDestination)
    }
    
    func testSearchViewModel_NavigateBack_WorksWithWebViewDestination() {
        let html = "<html><body>Test</body></html>"
        sut.currentDestination = .webView(.command(html))
        XCTAssertNotNil(sut.currentDestination)
        
        sut.navigateBack()
        
        XCTAssertNil(sut.currentDestination)
    }
    
    func testSearchViewModel_ExecuteCommand_CallsSearchService() async {
        mockSearchService.mockCommandResponse = CommandResponse(intent: "command", html: "<html>Result</html>", results: [])
        
        await sut.executeCommand(query: "test command")
        
        XCTAssertTrue(mockSearchService.executeCommandCalled)
        XCTAssertEqual(mockSearchService.capturedCommandQuery, "test command")
    }
    
    func testSearchViewModel_ExecuteCommand_SetsCommandHTML() async {
        let html = "<html><body>Command Result</body></html>"
        mockSearchService.mockCommandResponse = CommandResponse(intent: "command", html: html, results: [])
        
        await sut.executeCommand(query: "test")
        
        XCTAssertEqual(sut.commandHTML, html)
        XCTAssertTrue(sut.showWebView)
        XCTAssertFalse(sut.showFileList)
    }
    
    func testSearchViewModel_ExecuteCommand_ShowsErrorOnFailure() async {
        mockSearchService.mockError = NSError(domain: "Test", code: 1)
        
        await sut.executeCommand(query: "test")
        
        XCTAssertNotNil(sut.toast)
    }
    
    func testSearchViewModel_CancelRecording_ClearsState() {
        sut.isRecording = true
        sut.transcription = "test"
        sut.selectedFolder = Folder(name: "Test")
        sut.selectedBookmark = Bookmark(
            id: "1",
            fileName: "test.txt",
            contentType: .text,
            category: "Test",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        sut.cancelRecording()
        let expectation = expectation(description: "State cleared after cancelRecording")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertFalse(self.sut.isRecording)
            XCTAssertEqual(self.sut.transcription, "")
            XCTAssertNil(self.sut.selectedFolder)
            XCTAssertNil(self.sut.selectedBookmark)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSearchViewModel_HandleBookmarkLongPressStarted_StartsRecording() async throws {
        let bookmark = Bookmark(
            id: "1",
            fileName: "test.txt",
            contentType: .text,
            category: "Tasks",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        sut.handleBookmarkLongPressStarted(bookmark)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(mockSpeechService.startRecordingCalled)
        XCTAssertEqual(sut.selectedBookmark?.id, bookmark.id)
        XCTAssertTrue(sut.isRecording)
    }
    
    func testSearchViewModel_HandleBookmarkLongPressStarted_SetsSelectedBookmark() {
        let bookmark = Bookmark(
            id: "1",
            fileName: "test.txt",
            contentType: .text,
            category: "Tasks",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        sut.handleBookmarkLongPressStarted(bookmark)
        
        XCTAssertNil(sut.selectedFolder)
        XCTAssertEqual(sut.selectedBookmark?.id, bookmark.id)
        XCTAssertEqual(sut.selectedBookmark?.category, bookmark.category)
    }
    
    func testSearchViewModel_HandleBookmarkLongPressEnded_PerformsNestedSearch() async throws {
        let bookmark = Bookmark(
            id: "1",
            fileName: "test.txt",
            contentType: .text,
            category: "Tasks",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        sut.selectedBookmark = bookmark
        sut.isRecording = true
        mockSpeechService.mockTranscription = "nested query"
        mockSearchService.mockSearchResponse = SearchResponse(intent: "search", results: [], html: nil)
        
        sut.handleBookmarkLongPressEnded()
        try await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertTrue(mockSpeechService.stopRecordingCalled)
        XCTAssertTrue(mockSearchService.searchCalled)
    }
    
    func testSearchViewModel_HandleBookmarkLongPressEnded_DoesNotSearchOnEmptyTranscription() async throws {
        let bookmark = Bookmark(
            id: "1",
            fileName: "test.txt",
            contentType: .text,
            category: "Tasks",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        sut.selectedBookmark = bookmark
        sut.isRecording = true
        mockSpeechService.mockTranscription = ""
        
        sut.handleBookmarkLongPressEnded()
        try await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertFalse(mockSearchService.searchCalled)
        XCTAssertNil(sut.selectedBookmark)
    }
    
    func testSearchViewModel_PerformNestedSearch_CallsPerformSearchWithBookmarkId() async {
        let bookmarkId = "bookmark-123"
        mockSearchService.mockSearchResponse = SearchResponse(intent: "search", results: [], html: nil)

        sut.performSearch(query: "nested query", folderId: nil, bookmarkId: bookmarkId)

        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(mockSearchService.searchCalled)
        XCTAssertEqual(mockSearchService.capturedBookmarkId, bookmarkId)
    }
    
    func testSearchViewModel_PerformSearch_CommandIntent_NoHTML_ShowsError() async {
        mockSearchService.mockSearchResponse = SearchResponse(intent: "command", results: [], html: nil)
        
        sut.performSearch(query: "test", folderId: nil)
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNotNil(sut.toast)
        XCTAssertNil(sut.selectedFolder)
    }
    
    func testSearchViewModel_PerformSearch_UnknownIntent_ShowsError() async {
        mockSearchService.mockSearchResponse = SearchResponse(intent: "unknown", results: [], html: nil)
        
        sut.performSearch(query: "test", folderId: nil)
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNotNil(sut.toast)
    }
    
    func testSearchViewModel_PerformSearch_HandlesError() async {
        mockSearchService.mockError = NSError(domain: "Test", code: 1)
        
        sut.performSearch(query: "test", folderId: nil)
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNotNil(sut.toast)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testSearchViewModel_LoadFolders_HandlesError() async {
        mockSearchService.mockError = NSError(domain: "Test", code: 1)
        
        await sut.loadFolders()
        
        XCTAssertNotNil(sut.toast)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testSearchViewModel_LoadFilesForFolder_HandlesError() async {
        let folder = Folder(name: "Test")
        mockSearchService.mockError = NSError(domain: "Test", code: 1)
        
        await sut.loadFilesForFolder(folder)
        
        XCTAssertNotNil(sut.toast)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testSearchViewModel_HandleFolderLongPressStarted_HandlesRecordingError() async throws {
        let folder = Folder(name: "Test")
        mockSpeechService.mockError = NSError(domain: "Test", code: 1)
        
        sut.handleFolderLongPressStarted(folder)
        
        try await Task.sleep(nanoseconds: 800_000_000)
        
        await MainActor.run {
            XCTAssertFalse(sut.isRecording)
            XCTAssertNotNil(sut.toast)
        }
    }
    
    func testSearchViewModel_HandleBookmarkLongPressStarted_HandlesRecordingError() async throws {
        let bookmark = Bookmark(
            id: "1",
            fileName: "test.txt",
            contentType: .text,
            category: "Tasks",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        mockSpeechService.mockError = NSError(domain: "Test", code: 1)
        
        sut.handleBookmarkLongPressStarted(bookmark)
        
        try await Task.sleep(nanoseconds: 800_000_000)
        
        await MainActor.run {
            XCTAssertFalse(sut.isRecording)
            XCTAssertNotNil(sut.toast)
        }
    }
    
    func testWebViewContent_File_ReturnsCorrectTitle() {
        let bookmark = Bookmark(
            id: "1",
            fileName: "test.txt",
            contentType: .text,
            category: "Tasks",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        let content = WebViewContent.file(bookmark)
        
        XCTAssertEqual(content.title, "test.txt")
        XCTAssertTrue(content.canDelete)
    }
    
    func testWebViewContent_Command_ReturnsCorrectTitle() {
        let content = WebViewContent.command( "<html></html>")
        
        XCTAssertEqual(content.title, "Результат команды")
        XCTAssertFalse(content.canDelete)
    }
    
    func testSearchDestination_Equality_WorksCorrectly() {
        let folder1 = Folder(name: "Test")
        let folder2 = Folder(name: "Test")
        let results1: [Bookmark] = []
        let results2: [Bookmark] = []
        
        let dest1 = SearchDestination.fileList(folder1, results1)
        let dest2 = SearchDestination.fileList(folder2, results2)
        
        XCTAssertEqual(dest1, dest2)
    }
    
    func testSearchDestination_WebViewEquality_WorksCorrectly() {
        let html1 = "<html>Test</html>"
        let html2 = "<html>Test</html>"
        
        let dest1 = SearchDestination.webView(.command(html1))
        let dest2 = SearchDestination.webView(.command(html2))
        
        XCTAssertEqual(dest1, dest2)
    }
    
    func testSearchViewModel_PerformSearch_ClearsSearchQuery() async {
        sut.searchQuery = "test query"
        mockSearchService.mockSearchResponse = SearchResponse(intent: "search", results: [], html: nil)
        
        sut.performSearch(query: "test query", folderId: nil)
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(sut.searchQuery, "")
    }
    
    func testSearchViewModel_PerformSearch_Command_ClearsSearchQuery() async {
        sut.searchQuery = "test command"
        mockSearchService.mockSearchResponse = SearchResponse(intent: "command", results: [], html: "<html></html>")
        
        sut.performSearch(query: "test command", folderId: nil)
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(sut.searchQuery, "")
    }
    
    func testSearchViewModel_HandleFolderLongPressEnded_NoFolder_DoesNotSearch() async throws {
        sut.selectedFolder = nil
        sut.isRecording = true
        
        sut.handleFolderLongPressEnded()
        try await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertFalse(mockSearchService.searchCalled)
    }
    
    func testSearchViewModel_NavigateToFileList_SetsDestination() {
        let folder = Folder(name: "Test")
        let results: [Bookmark] = []
        
        sut.navigateToFileList(folder: folder, results: results)
        
        XCTAssertNotNil(sut.currentDestination)
        if case .fileList(let f, let r) = sut.currentDestination {
            XCTAssertEqual(f.id, folder.id)
            XCTAssertEqual(r.count, results.count)
        } else {
            XCTFail("Destination должен быть fileList")
        }
    }
    
    func testSearchViewModel_NavigateToWebView_SetsDestination() {
        let html = "<html>Test</html>"
        
        sut.navigateToWebView(content: .command(html))
        
        XCTAssertNotNil(sut.currentDestination)
        if case .webView(let content) = sut.currentDestination {
            if case .command(let h) = content {
                XCTAssertEqual(h, html)
            } else {
                XCTFail("Content должен быть command")
            }
        } else {
            XCTFail("Destination должен быть webView")
        }
    }
}

