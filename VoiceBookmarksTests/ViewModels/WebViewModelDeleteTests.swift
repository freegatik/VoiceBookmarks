//
//  WebViewModelDeleteTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class WebViewModelDeleteTests: XCTestCase {
    func testHandleDeleteAction_SetsConfirmation() {
        let bookmark = Bookmark(
            id: "1", fileName: "a.txt", contentType: .file, category: "Test",
            voiceNote: nil, fileUrl: "file:///tmp/a.txt", summary: nil, content: nil, contentHash: nil, timestamp: Date(), totalChunks: nil, distance: nil
        )
        let vm = WebViewModel(content: .file(bookmark), bookmarkService: BookmarkService())
        vm.handleDeleteAction()
        XCTAssertTrue(vm.showDeleteConfirmation)
    }

    func testConfirmDelete_Success_Dismisses() async {
        let bookmark = Bookmark(
            id: "1", fileName: "a.txt", contentType: .file, category: "Test",
            voiceNote: nil, fileUrl: "file:///tmp/a.txt", summary: nil, content: nil, contentHash: nil, timestamp: Date(), totalChunks: nil, distance: nil
        )
        let vm = WebViewModel(content: .file(bookmark), bookmarkService: MockBookmarkServiceSuccess())
        await vm.confirmDelete()
        XCTAssertTrue(vm.shouldDismiss)
        XCTAssertFalse(vm.isDeleting)
    }

    func testConfirmDelete_Failure_SetsError() async {
        let bookmark = Bookmark(
            id: "1", fileName: "a.txt", contentType: .file, category: "Test",
            voiceNote: nil, fileUrl: "file:///tmp/a.txt", summary: nil, content: nil, contentHash: nil, timestamp: Date(), totalChunks: nil, distance: nil
        )
        let vm = WebViewModel(content: .file(bookmark), bookmarkService: MockBookmarkServiceFailure())
        await vm.confirmDelete()
        XCTAssertNotNil(vm.loadError)
        XCTAssertFalse(vm.shouldDismiss)
    }
}

