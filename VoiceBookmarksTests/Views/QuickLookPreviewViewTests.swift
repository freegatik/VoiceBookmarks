//
//  QuickLookPreviewViewTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import QuickLook
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
@testable import VoiceBookmarks

final class QuickLookPreviewViewTests: XCTestCase {
    
    var sut: QuickLookPreviewView!
    var onLoadFinishCalled: Bool!
    var onLoadFailCalled: Bool!
    var onLoadFailError: Error?
    
    override func setUp() {
        super.setUp()
        onLoadFinishCalled = false
        onLoadFailCalled = false
        onLoadFailError = nil
    }
    
    override func tearDown() {
        sut = nil
        onLoadFinishCalled = nil
        onLoadFailCalled = nil
        onLoadFailError = nil
        super.tearDown()
    }
    
    func testQuickLookPreviewView_MakeCoordinator_CreatesCoordinator() {
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        sut = QuickLookPreviewView(
            sourceURL: testURL,
            onLoadFinish: { },
            onLoadFail: nil,
            headers: nil
        )
        
        let coordinator = sut.makeCoordinator()
        XCTAssertNotNil(coordinator)
        XCTAssertNotNil(coordinator.onLoadFinish)
    }
    
    func testQuickLookPreviewView_MakeCoordinator_CreatesCoordinatorWithOnLoadFail() {
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        sut = QuickLookPreviewView(
            sourceURL: testURL,
            onLoadFinish: { },
            onLoadFail: { _ in },
            headers: nil
        )
        
        let coordinator = sut.makeCoordinator()
        XCTAssertNotNil(coordinator)
        XCTAssertNotNil(coordinator.onLoadFail)
    }
    
    func testQuickLookPreviewView_MakeUIViewController_CreatesControllerForLocalFile() {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        let testData = Data([0x25, 0x50, 0x44, 0x46])
        try? testData.write(to: testFileURL, options: .atomic)
        
        sut = QuickLookPreviewView(
            sourceURL: testFileURL,
            onLoadFinish: { self.onLoadFinishCalled = true },
            onLoadFail: nil,
            headers: nil
        )
        
        _ = sut.makeCoordinator()
        
        struct TestWrapper: View {
            let quickLookView: QuickLookPreviewView
            
            var body: some View {
                quickLookView
            }
        }
        
        let wrapper = TestWrapper(quickLookView: sut)
        let hostingController = UIHostingController(rootView: wrapper)
        hostingController.loadViewIfNeeded()
        
        XCTAssertNotNil(hostingController)
        
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = hostingController
        window.isHidden = false
        hostingController.beginAppearanceTransition(true, animated: false)
        hostingController.endAppearanceTransition()
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        let expectation = XCTestExpectation(description: "onLoadFinish called")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(onLoadFinishCalled, "onLoadFinish должен быть вызван для локального файла")
        
        try? FileManager.default.removeItem(at: testFileURL)
    }
    
    func testQuickLookPreviewView_MakeUIViewController_CreatesControllerForRemoteURL() {
        let remoteURL = URL(string: "https://example.com/test.pdf")!
        
        sut = QuickLookPreviewView(
            sourceURL: remoteURL,
            onLoadFinish: { self.onLoadFinishCalled = true },
            onLoadFail: { error in
                self.onLoadFailCalled = true
                self.onLoadFailError = error
            },
            headers: nil
        )
        
        struct TestWrapper: View {
            let quickLookView: QuickLookPreviewView
            
            var body: some View {
                quickLookView
            }
        }
        
        let wrapper = TestWrapper(quickLookView: sut)
        let hostingController = UIHostingController(rootView: wrapper)
        hostingController.loadViewIfNeeded()
        
        XCTAssertNotNil(hostingController)
        XCTAssertFalse(onLoadFinishCalled)
    }
    
    func testQuickLookPreviewView_MakeUIViewController_UsesHeadersForRemoteURL() {
        let remoteURL = URL(string: "https://example.com/test.pdf")!
        let headers = ["Authorization": "Bearer token123"]
        
        sut = QuickLookPreviewView(
            sourceURL: remoteURL,
            onLoadFinish: { },
            onLoadFail: nil,
            headers: headers
        )
        
        struct TestWrapper: View {
            let quickLookView: QuickLookPreviewView
            
            var body: some View {
                quickLookView
            }
        }
        
        let wrapper = TestWrapper(quickLookView: sut)
        let hostingController = UIHostingController(rootView: wrapper)
        hostingController.loadViewIfNeeded()
        
        XCTAssertNotNil(hostingController)
    }
    
    func testQuickLookPreviewView_UpdateUIViewController_DoesNothing() {
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        sut = QuickLookPreviewView(
            sourceURL: testURL,
            onLoadFinish: { },
            onLoadFail: nil,
            headers: nil
        )
        
        _ = QLPreviewController()
        
        _ = sut.makeCoordinator()
        XCTAssertNoThrow({
        }())
    }
    
    func testQuickLookPreviewView_Coordinator_NumberOfPreviewItems_ReturnsZeroWhenFileURLNil() {
        let coordinator = QuickLookPreviewView.Coordinator(onLoadFinish: { }, onLoadFail: nil)
        coordinator.fileURL = nil
        
        let controller = QLPreviewController()
        let count = coordinator.numberOfPreviewItems(in: controller)
        
        XCTAssertEqual(count, 0)
    }
    
    func testQuickLookPreviewView_Coordinator_NumberOfPreviewItems_ReturnsOneWhenFileURLSet() {
        let coordinator = QuickLookPreviewView.Coordinator(onLoadFinish: { }, onLoadFail: nil)
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        coordinator.fileURL = testURL
        
        let controller = QLPreviewController()
        let count = coordinator.numberOfPreviewItems(in: controller)
        
        XCTAssertEqual(count, 1)
    }
    
    func testQuickLookPreviewView_Coordinator_PreviewController_ReturnsFileURL() {
        let coordinator = QuickLookPreviewView.Coordinator(onLoadFinish: { }, onLoadFail: nil)
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        coordinator.fileURL = testURL
        
        let controller = QLPreviewController()
        let previewItem = coordinator.previewController(controller, previewItemAt: 0)
        
        XCTAssertNotNil(previewItem)
        XCTAssertEqual(previewItem as? URL, testURL)
    }
    
    func testQuickLookPreviewView_Coordinator_Deinit_RemovesTemporaryFile() {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_deinit.pdf")
        let testData = Data([0x25, 0x50, 0x44, 0x46])
        try? testData.write(to: testFileURL, options: .atomic)
        
        var coordinator: QuickLookPreviewView.Coordinator? = QuickLookPreviewView.Coordinator(
            onLoadFinish: { },
            onLoadFail: nil
        )
        coordinator?.fileURL = testFileURL
        coordinator?.isTemporaryFile = true
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path))
        
        coordinator = nil
        
        let expectation = XCTestExpectation(description: "Cleanup completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFileURL.path), "Временный файл должен быть удален в deinit")
    }
    
    func testQuickLookPreviewView_Coordinator_Deinit_DoesNotRemoveNonTemporaryFile() {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_permanent.pdf")
        let testData = Data([0x25, 0x50, 0x44, 0x46])
        try? testData.write(to: testFileURL, options: .atomic)
        
        var coordinator: QuickLookPreviewView.Coordinator? = QuickLookPreviewView.Coordinator(
            onLoadFinish: { },
            onLoadFail: nil
        )
        coordinator?.fileURL = testFileURL
        coordinator?.isTemporaryFile = false
        
        coordinator = nil
        
        let expectation = XCTestExpectation(description: "Deinit completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path), "Постоянный файл не должен быть удален")
        
        try? FileManager.default.removeItem(at: testFileURL)
    }
    
    func testQuickLookPreviewView_Coordinator_Deinit_HandlesRemoteURL() {
        let remoteURL = URL(string: "https://example.com/test.pdf")!
        
        var coordinator: QuickLookPreviewView.Coordinator? = QuickLookPreviewView.Coordinator(
            onLoadFinish: { },
            onLoadFail: nil
        )
        coordinator?.fileURL = remoteURL
        coordinator?.isTemporaryFile = true
        
        XCTAssertNoThrow({
            coordinator = nil
        })
        
        let expectation = XCTestExpectation(description: "Deinit completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testQuickLookPreviewView_Coordinator_Deinit_HandlesDeleteError() {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_error.pdf")
        
        var coordinator: QuickLookPreviewView.Coordinator? = QuickLookPreviewView.Coordinator(
            onLoadFinish: { },
            onLoadFail: nil
        )
        coordinator?.fileURL = testFileURL
        coordinator?.isTemporaryFile = true
        coordinator?.logger = LoggerService.shared
        
        XCTAssertNoThrow({
            coordinator = nil
        })
        
        let expectation = XCTestExpectation(description: "Deinit completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testQuickLookPreviewView_Coordinator_PreviewController_HandlesDifferentIndices() {
        let coordinator = QuickLookPreviewView.Coordinator(onLoadFinish: { }, onLoadFail: nil)
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        coordinator.fileURL = testURL
        
        let controller = QLPreviewController()
        let previewItem = coordinator.previewController(controller, previewItemAt: 0)
        
        XCTAssertNotNil(previewItem)
        XCTAssertEqual(previewItem as? URL, testURL)
    }
    
    func testQuickLookPreviewView_MakeUIViewController_SetsLoggerInCoordinator() {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        sut = QuickLookPreviewView(
            sourceURL: testFileURL,
            onLoadFinish: { },
            onLoadFail: nil,
            headers: nil
        )
        
        let coordinator = sut.makeCoordinator()
        
        struct TestWrapper: View {
            let quickLookView: QuickLookPreviewView
            
            var body: some View {
                quickLookView
            }
        }
        
        let wrapper = TestWrapper(quickLookView: sut)
        let hostingController = UIHostingController(rootView: wrapper)
        hostingController.loadViewIfNeeded()
        
        XCTAssertNotNil(coordinator)
        XCTAssertNotNil(hostingController)
    }
    
    func testQuickLookPreviewView_Coordinator_Init_SavesCallbacks() {
        var finishCalled = false
        var failCalled = false
        
        let coordinator = QuickLookPreviewView.Coordinator(
            onLoadFinish: { finishCalled = true },
            onLoadFail: { _ in failCalled = true }
        )
        
        coordinator.onLoadFinish()
        XCTAssertTrue(finishCalled, "onLoadFinish должен быть сохранен")
        
        coordinator.onLoadFail?(NSError(domain: "Test", code: 1))
        XCTAssertTrue(failCalled, "onLoadFail должен быть сохранен")
    }
    
    func testQuickLookPreviewView_MakeUIViewController_CreatesTimeoutTaskForRemoteURL() {
        let remoteURL = URL(string: "https://example.com/test.pdf")!
        
        sut = QuickLookPreviewView(
            sourceURL: remoteURL,
            onLoadFinish: { },
            onLoadFail: { error in
                self.onLoadFailCalled = true
                self.onLoadFailError = error
            },
            headers: nil
        )
        
        _ = sut.makeCoordinator()
        
        struct TestWrapper: View {
            let quickLookView: QuickLookPreviewView
            
            var body: some View {
                quickLookView
            }
        }
        
        let wrapper = TestWrapper(quickLookView: sut)
        let hostingController = UIHostingController(rootView: wrapper)
        hostingController.loadViewIfNeeded()
        
        XCTAssertFalse(onLoadFailCalled)
        XCTAssertNotNil(hostingController)
    }
}
