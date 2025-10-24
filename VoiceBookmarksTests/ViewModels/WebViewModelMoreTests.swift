//
//  WebViewModelMoreTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class WebViewModelMoreTests: XCTestCase {
    func testHandleSaveToFiles_CommandContent_SetsDocumentPicker() async {
        let vm = WebViewModel(content: .command("<html>t</html>"), bookmarkService: BookmarkService(networkService: NetworkService(), fileService: FileService.shared))
        vm.handleSaveToFiles()
        try? await Task.sleep(nanoseconds: 100_000_000)
        await MainActor.run {
            XCTAssertTrue(vm.showDocumentPicker)
            XCTAssertNotNil(vm.urlToSave)
        }
    }

    func testHandleSaveToFiles_FileContent_InvalidURL_SetsError() async {
        let bookmark = Bookmark(
            id: "1", fileName: "broken", contentType: .file, category: "Test",
            voiceNote: nil, fileUrl: "", summary: nil, content: nil, contentHash: nil, timestamp: Date(), totalChunks: nil, distance: nil
        )
        let vm = WebViewModel(content: .file(bookmark), bookmarkService: BookmarkService(networkService: NetworkService(), fileService: FileService.shared))
        vm.handleSaveToFiles()
        try? await Task.sleep(nanoseconds: 100_000_000)
        await MainActor.run {
            XCTAssertNotNil(vm.loadError)
            XCTAssertFalse(vm.showDocumentPicker)
        }
    }
}


