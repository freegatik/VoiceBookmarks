//
//  ShareExtensionViewModelTests.swift
//  VoiceBookmarksShareExtensionTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class ShareExtensionViewModelTests: XCTestCase {
    
    var sut: ShareExtensionViewModel!
    
    override func setUp() {
        super.setUp()
        sut = ShareExtensionViewModel()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testShareExtensionViewModel_InitialState() {
        XCTAssertTrue(sut.isLoading)
        XCTAssertEqual(sut.statusMessage, "Добавление контента...")
        XCTAssertFalse(sut.showSuccess)
        XCTAssertFalse(sut.showError)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testShareExtensionViewModel_UpdateStatus_Success() {
        let expectation = XCTestExpectation(description: "Status updated")
        
        sut.updateStatus(message: "Успешно добавлено", isSuccess: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.sut.isLoading)
            XCTAssertEqual(self.sut.statusMessage, "Успешно добавлено")
            XCTAssertTrue(self.sut.showSuccess)
            XCTAssertFalse(self.sut.showError)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShareExtensionViewModel_UpdateStatus_Error() {
        let expectation = XCTestExpectation(description: "Status updated")
        
        sut.updateStatus(message: "Ошибка", isSuccess: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.sut.isLoading)
            XCTAssertEqual(self.sut.statusMessage, "Ошибка")
            XCTAssertFalse(self.sut.showSuccess)
            XCTAssertTrue(self.sut.showError)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShareExtensionViewModel_ShowError() {
        let expectation = XCTestExpectation(description: "Error shown")
        let errorMessage = "Произошла ошибка"
        
        sut.showError(errorMessage)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.sut.isLoading)
            XCTAssertEqual(self.sut.statusMessage, errorMessage)
            XCTAssertTrue(self.sut.showError)
            XCTAssertEqual(self.sut.errorMessage, errorMessage)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
