//
//  ShareExtensionViewModelTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import Combine
@testable import VoiceBookmarks

final class ShareExtensionViewModelTests: XCTestCase {
    
    var sut: ShareExtensionViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = ShareExtensionViewModel()
        cancellables = []
    }
    
    override func tearDown() {
        sut = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testShareExtensionViewModel_Init_DefaultValues() {
        XCTAssertTrue(sut.isLoading)
        XCTAssertEqual(sut.statusMessage, "Adding content...")
        XCTAssertFalse(sut.showSuccess)
        XCTAssertFalse(sut.showError)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testShareExtensionViewModel_UpdateStatus_Success() {
        let expectation = expectation(description: "State updated")
        
        sut.$showSuccess
            .dropFirst()
            .sink { success in
                if success {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        sut.updateStatus(message: "Успешно добавлено", isSuccess: true)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.statusMessage, "Успешно добавлено")
        XCTAssertTrue(sut.showSuccess)
        XCTAssertFalse(sut.showError)
    }
    
    func testShareExtensionViewModel_UpdateStatus_Failure() {
        sut.updateStatus(message: "Processing content...", isSuccess: false)
        
        let expectation = expectation(description: "Message updated")
        DispatchQueue.main.async {
            XCTAssertEqual(self.sut.statusMessage, "Processing content...")
            XCTAssertTrue(self.sut.isLoading)
            XCTAssertFalse(self.sut.showSuccess)
            XCTAssertFalse(self.sut.showError)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShareExtensionViewModel_ShowError_SetsErrorState() {
        let expectation = expectation(description: "Error state set")
        
        sut.$showError
            .dropFirst()
            .sink { error in
                if error {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let errorMessage = "Произошла ошибка"
        sut.showError(errorMessage)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.statusMessage, errorMessage)
        XCTAssertEqual(sut.errorMessage, errorMessage)
        XCTAssertTrue(sut.showError)
        XCTAssertFalse(sut.showSuccess)
    }
    
    func testShareExtensionViewModel_ShowError_DifferentMessages() {
        let messages = [
            "Error сети",
            "Файл слишком большой",
            "Неверный формат",
            "Не удалось загрузить"
        ]
        
        for message in messages {
            sut.showError(message)
            let expectation = expectation(description: "Error state set for message \(message)")
            DispatchQueue.main.async {
                XCTAssertEqual(self.sut.statusMessage, message)
                XCTAssertEqual(self.sut.errorMessage, message)
                XCTAssertTrue(self.sut.showError)
                XCTAssertFalse(self.sut.isLoading)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testShareExtensionViewModel_UpdateStatus_MainThread() {
        let expectation = expectation(description: "Updated on main thread")
        
        DispatchQueue.global().async {
            self.sut.updateStatus(message: "Test", isSuccess: true)
            
            DispatchQueue.main.async {
                XCTAssertTrue(self.sut.showSuccess)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testShareExtensionViewModel_ShowError_MainThread() {
        let expectation = expectation(description: "Error set on main thread")
        
        DispatchQueue.global().async {
            self.sut.showError("Test error")
            
            DispatchQueue.main.async {
                XCTAssertTrue(self.sut.showError)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testShareExtensionViewModel_UpdateStatus_MultipleCalls() {
        sut.updateStatus(message: "Processing content...", isSuccess: false)
        sut.updateStatus(message: "Processing image...", isSuccess: false)
        sut.updateStatus(message: "Content added successfully", isSuccess: true)
        
        let expectation = expectation(description: "Final status applied")
        DispatchQueue.main.async {
            XCTAssertTrue(self.sut.showSuccess)
            XCTAssertEqual(self.sut.statusMessage, "Content added successfully")
            XCTAssertFalse(self.sut.isLoading)
            XCTAssertFalse(self.sut.showError)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShareExtensionViewModel_ShowError_MultipleCalls() {
        sut.showError("Первая ошибка")
        sut.showError("Вторая ошибка")
        sut.showError("Третья ошибка")
        
        let expectation = expectation(description: "Last error applied")
        DispatchQueue.main.async {
            XCTAssertEqual(self.sut.statusMessage, "Третья ошибка")
            XCTAssertEqual(self.sut.errorMessage, "Третья ошибка")
            XCTAssertTrue(self.sut.showError)
            XCTAssertFalse(self.sut.isLoading)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShareExtensionViewModel_UpdateStatus_EmptyMessage() {
        sut.updateStatus(message: "", isSuccess: true)
        let expectation = expectation(description: "Empty message status applied")
        DispatchQueue.main.async {
            XCTAssertEqual(self.sut.statusMessage, "")
            XCTAssertTrue(self.sut.showSuccess)
            XCTAssertFalse(self.sut.isLoading)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShareExtensionViewModel_ShowError_EmptyMessage() {
        sut.showError("")
        let expectation = expectation(description: "Empty error applied")
        DispatchQueue.main.async {
            XCTAssertEqual(self.sut.statusMessage, "")
            XCTAssertEqual(self.sut.errorMessage, "")
            XCTAssertTrue(self.sut.showError)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShareExtensionViewModel_IntermediateStates_KeepLoading() {
        XCTAssertTrue(sut.isLoading)
        
        sut.updateStatus(message: "Processing content...", isSuccess: false)
        let expectation1 = expectation(description: "Intermediate state 1")
        DispatchQueue.main.async {
            XCTAssertTrue(self.sut.isLoading)
            XCTAssertEqual(self.sut.statusMessage, "Processing content...")
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)
        
        sut.updateStatus(message: "Processing image...", isSuccess: false)
        let expectation2 = expectation(description: "Intermediate state 2")
        DispatchQueue.main.async {
            XCTAssertTrue(self.sut.isLoading)
            XCTAssertEqual(self.sut.statusMessage, "Processing image...")
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)
        
        sut.updateStatus(message: "Успешно", isSuccess: true)
        let expectation3 = expectation(description: "Final success")
        DispatchQueue.main.async {
            XCTAssertFalse(self.sut.isLoading)
            XCTAssertTrue(self.sut.showSuccess)
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 1.0)
    }
    
    func testShareExtensionViewModel_IntermediateStates_NoFlags() {
        sut.updateStatus(message: "Processing video...", isSuccess: false)
        let expectation = expectation(description: "No flags set")
        DispatchQueue.main.async {
            XCTAssertFalse(self.sut.showSuccess)
            XCTAssertFalse(self.sut.showError)
            XCTAssertTrue(self.sut.isLoading)
            XCTAssertEqual(self.sut.statusMessage, "Processing video...")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
