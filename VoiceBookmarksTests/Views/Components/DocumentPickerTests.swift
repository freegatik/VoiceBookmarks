//
//  DocumentPickerTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import SwiftUI
import UniformTypeIdentifiers
@testable import VoiceBookmarks

final class DocumentPickerTests: XCTestCase {
    
    func testDocumentPicker_Init_WithURL() {
        let testURL = URL(fileURLWithPath: "/test/file.pdf")
        let picker = DocumentPicker(url: testURL) {
        }
        
        XCTAssertNotNil(picker)
    }
    
    func testDocumentPicker_DifferentURLs() {
        let urls = [
            URL(fileURLWithPath: "/test/image.jpg"),
            URL(fileURLWithPath: "/test/document.pdf"),
            URL(fileURLWithPath: "/test/video.mp4")
        ]
        
        for url in urls {
            let picker = DocumentPicker(url: url) {
            }
            XCTAssertNotNil(picker)
        }
    }
    
    func testDocumentPicker_CallsCallback() {
        let testURL = URL(fileURLWithPath: "/test/file.pdf")
        var callbackCalled = false
        
        let onComplete: () -> Void = {
            callbackCalled = true
        }
        
        let picker = DocumentPicker(url: testURL, onComplete: onComplete)
        
        XCTAssertNotNil(picker)
        onComplete()
        XCTAssertTrue(callbackCalled, "Callback должен быть вызван")
    }
    
    func testDocumentPicker_Coordinator_CallsCallback() {
        let tempDir = FileManager.default.temporaryDirectory
        let testURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        FileManager.default.createFile(atPath: testURL.path, contents: Data("test".utf8))
        var callbackCalled = false
        
        let onComplete: () -> Void = {
            callbackCalled = true
        }
        
        let picker = DocumentPicker(url: testURL, onComplete: onComplete)
        let coordinator = picker.makeCoordinator()
        
        XCTAssertNotNil(picker)
        XCTAssertNotNil(coordinator)
        
        let mockController = UIDocumentPickerViewController(forExporting: [testURL])
        coordinator.documentPicker(mockController, didPickDocumentsAt: [testURL])
        
        XCTAssertTrue(callbackCalled, "Coordinator должен вызвать callback при выборе файла")
        try? FileManager.default.removeItem(at: testURL)
    }
    
    func testDocumentPicker_Coordinator_CallsCallbackOnCancel() {
        let tempDir = FileManager.default.temporaryDirectory
        let testURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        FileManager.default.createFile(atPath: testURL.path, contents: Data("test".utf8))
        var callbackCalled = false
        
        let onComplete: () -> Void = {
            callbackCalled = true
        }
        
        let picker = DocumentPicker(url: testURL, onComplete: onComplete)
        let coordinator = picker.makeCoordinator()
        
        let mockController = UIDocumentPickerViewController(forExporting: [testURL])
        coordinator.documentPickerWasCancelled(mockController)
        
        XCTAssertTrue(callbackCalled, "Coordinator должен вызвать callback при отмене")
        try? FileManager.default.removeItem(at: testURL)
    }
}

