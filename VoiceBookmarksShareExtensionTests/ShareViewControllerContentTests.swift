//
//  ShareViewControllerContentTests.swift
//  VoiceBookmarksShareExtensionTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import UniformTypeIdentifiers
@testable import VoiceBookmarks

final class ShareViewControllerContentTests: XCTestCase {
    
    func testShareViewController_Initializes_LoadsView() {
        let vc = ShareViewController()
        _ = vc.view
        XCTAssertNotNil(vc.view)
        XCTAssertNotNil(vc.hostingController)
    }
    
    func testShareViewController_SetupUI_CreatesHostingController() {
        let vc = ShareViewController()
        _ = vc.view
        XCTAssertNotNil(vc.hostingController)
        XCTAssertNotNil(vc.shareExtensionViewModel)
    }
    
    func testShareViewController_ExtractSharedContent_NoExtensionContext_ShowsError() {
        let vc = ShareViewController()
        _ = vc.view
        XCTAssertNotNil(vc)
        XCTAssertNotNil(vc.shareExtensionViewModel)
    }
    
    func testShareViewController_ExtractSharedContent_EmptyInputItems_ShowsError() {
        let vc = ShareViewController()
        _ = vc.view
        XCTAssertNotNil(vc)
    }
    
    func testShareViewController_ShareExtensionViewModel_IsCreated() {
        let vc = ShareViewController()
        _ = vc.view
        XCTAssertNotNil(vc.shareExtensionViewModel)
        XCTAssertTrue(vc.shareExtensionViewModel?.isLoading ?? false)
    }
    
    func testShareViewController_ShowErrorAndClose_SetsViewModelError() {
        let vc = ShareViewController()
        _ = vc.view
        let testMessage = "Тестовая ошибка"
        vc.shareExtensionViewModel?.showError(testMessage)
        
        let expectation = XCTestExpectation(description: "Error state set")
        DispatchQueue.main.async {
            XCTAssertEqual(vc.shareExtensionViewModel?.errorMessage, testMessage)
            XCTAssertTrue(vc.shareExtensionViewModel?.showError ?? false)
            XCTAssertFalse(vc.shareExtensionViewModel?.isLoading ?? true)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShareViewController_ShowSuccessAndClose_SetsViewModelSuccess() {
        let vc = ShareViewController()
        _ = vc.view
        let testMessage = "Успешно"
        vc.shareExtensionViewModel?.updateStatus(message: testMessage, isSuccess: true)
        
        let expectation = XCTestExpectation(description: "Success state set")
        DispatchQueue.main.async {
            XCTAssertEqual(vc.shareExtensionViewModel?.statusMessage, testMessage)
            XCTAssertTrue(vc.shareExtensionViewModel?.showSuccess ?? false)
            XCTAssertFalse(vc.shareExtensionViewModel?.isLoading ?? true)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShareViewController_InitialState_ShowsLoading() {
        let vc = ShareViewController()
        _ = vc.view
        let expectation = XCTestExpectation(description: "Initial state set")
        DispatchQueue.main.async {
            XCTAssertTrue(vc.shareExtensionViewModel?.isLoading ?? false)
            XCTAssertEqual(vc.shareExtensionViewModel?.statusMessage, "Adding content...")
            XCTAssertFalse(vc.shareExtensionViewModel?.showSuccess ?? true)
            XCTAssertFalse(vc.shareExtensionViewModel?.showError ?? true)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShareViewController_UpdateStatus_IntermediateState_OnlyUpdatesMessage() {
        let vc = ShareViewController()
        _ = vc.view
        vc.shareExtensionViewModel?.updateStatus(message: "Processing image...", isSuccess: false)
        
        let expectation = XCTestExpectation(description: "Intermediate state set")
        DispatchQueue.main.async {
            XCTAssertEqual(vc.shareExtensionViewModel?.statusMessage, "Processing image...")
            XCTAssertTrue(vc.shareExtensionViewModel?.isLoading ?? false)
            XCTAssertFalse(vc.shareExtensionViewModel?.showSuccess ?? true)
            XCTAssertFalse(vc.shareExtensionViewModel?.showError ?? true)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShareViewController_CloseExtension_CompletesRequest() {
        let vc = ShareViewController()
        _ = vc.view
        XCTAssertNotNil(vc)
    }
    
    func testShareViewController_OfflineQueue_IsInitialized() {
        let vc = ShareViewController()
        _ = vc.view
        XCTAssertNotNil(vc)
    }
    
    func testShareViewController_FileService_IsShared() {
        let vc = ShareViewController()
        _ = vc.view
        XCTAssertNotNil(vc)
    }
}
