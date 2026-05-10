//
//  WKWebViewRepresentableTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import WebKit
@testable import VoiceBookmarks

final class WKWebViewRepresentableTests: XCTestCase {
    func testMakeUIView_CreatesWebViewWithConfig() {
        let config = WKWebViewConfiguration()
        let url = URL(string: "https://example.com")!
        let view = WKWebViewRepresentable(
            url: url,
            configuration: config,
            onLoadFinish: {},
            onLoadFail: { _ in }
        )
        XCTAssertNotNil(view)
    }

    func testCoordinator_CallsOnLoadFinish() {
        var finished = false
        let url = URL(string: "https://example.com")!
        let sut = WKWebViewRepresentable(
            url: url,
            configuration: WKWebViewConfiguration(),
            onLoadFinish: { finished = true },
            onLoadFail: { _ in }
        )
        let coordinator = sut.makeCoordinator()
        coordinator.webView(WKWebView(), didFinish: nil)
        XCTAssertTrue(finished)
    }

    func testCoordinator_CallsOnLoadFail() {
        var failed = false
        let url = URL(string: "https://example.com")!
        let sut = WKWebViewRepresentable(
            url: url,
            configuration: WKWebViewConfiguration(),
            onLoadFinish: {},
            onLoadFail: { _ in failed = true }
        )
        let coordinator = sut.makeCoordinator()
        let error = NSError(domain: "test", code: 1)
        coordinator.webView(WKWebView(), didFail: nil, withError: error)
        XCTAssertTrue(failed)
    }
}

