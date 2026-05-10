//
//  PDFPreviewViewTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import SwiftUI
@testable import VoiceBookmarks

final class PDFPreviewViewTests: XCTestCase {
    
    func testPDFPreviewView_Init_WithPDFURL() {
        let testURL = URL(string: "https://example.com/document.pdf")!
        let view = PDFPreviewView(pdfURL: testURL)
        
        XCTAssertNotNil(view)
    }
    
    func testPDFPreviewView_Init_WithCallbacks() {
        let testURL = URL(string: "https://example.com/document.pdf")!
        var onFinishCalled = false
        var onFailCalled = false
        
        let onFinish: () -> Void = {
            onFinishCalled = true
        }
        let onFail: (Error) -> Void = { _ in
            onFailCalled = true
        }
        
        let view = PDFPreviewView(
            pdfURL: testURL,
            onLoadFinish: onFinish,
            onLoadFail: onFail
        )
        
        XCTAssertNotNil(view)
        onFinish()
        onFail(NSError(domain: "Test", code: -1))
        XCTAssertTrue(onFinishCalled)
        XCTAssertTrue(onFailCalled)
    }
    
    func testPDFPreviewView_DifferentURLs() {
        let urls = [
            URL(string: "https://example.com/doc1.pdf")!,
            URL(string: "https://example.com/doc2.pdf")!,
            URL(string: "file:///path/to/doc.pdf")!
        ]
        
        for url in urls {
            let view = PDFPreviewView(pdfURL: url)
            XCTAssertNotNil(view)
        }
    }
    
    func testPDFPreviewView_Init_WithoutCallbacks() {
        let testURL = URL(string: "https://example.com/document.pdf")!
        let view = PDFPreviewView(pdfURL: testURL)
        
        XCTAssertNotNil(view)
    }
    
    func testPDFPreviewView_MakesPDFView() {
        let tempDir = FileManager.default.temporaryDirectory
        let testPDFURL = tempDir.appendingPathComponent("test.pdf")
        
        let pdfData = Data()
        try? pdfData.write(to: testPDFURL, options: .atomic)
        
        let view = PDFPreviewView(pdfURL: testPDFURL)
        
        XCTAssertNotNil(view)
        
        try? FileManager.default.removeItem(at: testPDFURL)
    }
    
    func testPDFPreviewView_OnLoadFinish_CallsCallback() {
        var finished = false
        let url = URL(string: "https://example.com/document.pdf")!
        let view = PDFPreviewView(pdfURL: url, onLoadFinish: { finished = true })
        
        view.onLoadFinish()
        XCTAssertTrue(finished)
    }
    
    func testPDFPreviewView_OnLoadFail_CallsCallback() {
        var failed = false
        let url = URL(string: "https://example.com/document.pdf")!
        let view = PDFPreviewView(
            pdfURL: url,
            onLoadFinish: {},
            onLoadFail: { _ in failed = true }
        )
        
        view.onLoadFail?(NSError(domain: "PDFPreviewView", code: -1))
        XCTAssertTrue(failed)
    }
    
    func testPDFPreviewView_InvalidPDFURL() {
        let invalidURL = URL(string: "https://example.com/not-a-pdf.txt")!
        let view = PDFPreviewView(pdfURL: invalidURL)
        XCTAssertNotNil(view)
    }
}
