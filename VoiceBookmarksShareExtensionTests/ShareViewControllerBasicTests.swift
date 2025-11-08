//
//  ShareViewControllerBasicTests.swift
//  VoiceBookmarksShareExtensionTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class ShareViewControllerBasicTests: XCTestCase {
    func testShareViewController_InitializesUI() {
        let vc = ShareViewController()
        _ = vc.view
        XCTAssertNotNil(vc.view)
    }
}


