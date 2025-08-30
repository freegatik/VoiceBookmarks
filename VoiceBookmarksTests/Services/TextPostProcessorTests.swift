//
//  TextPostProcessorTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class TextPostProcessorTests: XCTestCase {
    private var sut: TextPostProcessor!

    override func setUp() {
        super.setUp()
        sut = TextPostProcessor()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testProcessReturnsEmptyForWhitespaceOnly() {
        XCTAssertEqual(sut.process("   \n\t  "), "   \n\t  ")
    }

    func testApplyBasicPostProcessingLeavesEmptyInput() {
        XCTAssertEqual(sut.applyBasicPostProcessing(""), "")
    }

    func testAddPunctuationAppendsPeriodWhenMissing() {
        let out = sut.addPunctuation(to: "просто текст без точки")
        XCTAssertTrue(out.hasSuffix("."), "expected terminal punctuation, got: \(out)")
    }

    func testAddPunctuationNormalizesSpaceBeforeComma() {
        let out = sut.addPunctuation(to: "слово , другое")
        XCTAssertFalse(out.contains(" ,"), "got: \(out)")
    }
}
