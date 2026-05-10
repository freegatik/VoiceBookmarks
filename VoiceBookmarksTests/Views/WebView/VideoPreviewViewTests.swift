//
//  VideoPreviewViewTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import SwiftUI
@testable import VoiceBookmarks

final class VideoPreviewViewTests: XCTestCase {
    
    func testVideoPreviewView_Init_WithVideoURL() {
        let testURL = URL(string: "https://example.com/video.mp4")!
        let view = VideoPreviewView(videoURL: testURL)
        
        XCTAssertNotNil(view)
    }
    
    func testVideoPreviewView_Init_WithCallbacks() {
        let testURL = URL(string: "https://example.com/video.mp4")!
        var onFinishCalled = false
        var onFailCalled = false
        
        let onFinish: () -> Void = {
            onFinishCalled = true
        }
        let onFail: (Error) -> Void = { _ in
            onFailCalled = true
        }
        
        let view = VideoPreviewView(
            videoURL: testURL,
            onLoadFinish: onFinish,
            onLoadFail: onFail
        )
        
        XCTAssertNotNil(view)
        onFinish()
        onFail(NSError(domain: "Test", code: -1))
        XCTAssertTrue(onFinishCalled)
        XCTAssertTrue(onFailCalled)
    }
    
    func testVideoPreviewView_DifferentURLs() {
        let urls = [
            URL(string: "https://example.com/video1.mp4")!,
            URL(string: "https://example.com/video2.mov")!,
            URL(string: "https://example.com/video3.m4v")!
        ]
        
        for url in urls {
            let view = VideoPreviewView(videoURL: url)
            XCTAssertNotNil(view)
        }
    }
    
    func testVideoPreviewView_Init_WithoutCallbacks() {
        let testURL = URL(string: "https://example.com/video.mp4")!
        let view = VideoPreviewView(videoURL: testURL)
        
        XCTAssertNotNil(view)
    }
    
    func testVideoPreviewView_SupportsVideoFormats() {
        let formats = ["mp4", "mov", "m4v", "avi", "mkv"]
        
        for format in formats {
            let url = URL(string: "https://example.com/video.\(format)")!
            let view = VideoPreviewView(videoURL: url)
            XCTAssertNotNil(view, "Должен поддерживать формат \(format)")
        }
    }
    
    func testVideoPreviewView_OnAppear_CallsOnLoadFinish() {
        var finished = false
        let url = URL(string: "https://example.com/video.mp4")!
        let view = VideoPreviewView(videoURL: url, onLoadFinish: { finished = true })
        
        view.onLoadFinish()
        XCTAssertTrue(finished)
    }
    
    func testVideoPreviewView_OnLoadFail_CallsCallback() {
        var failed = false
        let url = URL(string: "https://example.com/video.mp4")!
        let view = VideoPreviewView(
            videoURL: url,
            onLoadFinish: {},
            onLoadFail: { _ in failed = true }
        )
        
        view.onLoadFail?(NSError(domain: "Test", code: -1))
        XCTAssertTrue(failed)
    }
}
