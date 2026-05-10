//
//  ImagePreviewViewTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import SwiftUI
@testable import VoiceBookmarks

final class ImagePreviewViewTests: XCTestCase {
    
    func testImagePreviewView_Init_WithImageURL() {
        let testURL = URL(string: "https://example.com/image.jpg")!
        let view = ImagePreviewView(imageURL: testURL)
        
        XCTAssertNotNil(view)
    }
    
    func testImagePreviewView_Init_WithCallbacks() {
        let testURL = URL(string: "https://example.com/image.jpg")!
        var onFinishCalled = false
        var onFailCalled = false
        
        let onFinish: () -> Void = {
            onFinishCalled = true
        }
        let onFail: (Error) -> Void = { _ in
            onFailCalled = true
        }
        
        let view = ImagePreviewView(
            imageURL: testURL,
            onLoadFinish: onFinish,
            onLoadFail: onFail
        )
        
        XCTAssertNotNil(view)
        onFinish()
        onFail(NSError(domain: "Test", code: -1))
        XCTAssertTrue(onFinishCalled)
        XCTAssertTrue(onFailCalled)
    }
    
    func testImagePreviewView_DifferentURLs() {
        let urls = [
            URL(string: "https://example.com/image1.jpg")!,
            URL(string: "https://example.com/image2.png")!,
            URL(string: "https://example.com/image3.heic")!
        ]
        
        for url in urls {
            let view = ImagePreviewView(imageURL: url)
            XCTAssertNotNil(view)
        }
    }
    
    func testImagePreviewView_Init_WithoutCallbacks() {
        let testURL = URL(string: "https://example.com/image.jpg")!
        
        let view = ImagePreviewView(imageURL: testURL)
        
        XCTAssertNotNil(view)
    }
    
    func testImagePreviewView_SupportsImageFormats() {
        let formats = ["jpg", "jpeg", "png", "gif", "heic", "webp"]
        
        for format in formats {
            let url = URL(string: "https://example.com/image.\(format)")!
            let view = ImagePreviewView(imageURL: url)
            XCTAssertNotNil(view, "Должен поддерживать формат \(format)")
        }
    }
}
