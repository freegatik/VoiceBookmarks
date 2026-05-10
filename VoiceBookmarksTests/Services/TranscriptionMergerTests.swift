//
//  TranscriptionMergerTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class TranscriptionMergerTests: XCTestCase {
    private var sut: TranscriptionMerger!

    override func setUp() {
        super.setUp()
        sut = TranscriptionMerger()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testRemoveInternalDuplicatesCollapsesRepeatedWords() {
        let input = "привет привет мир"
        let out = sut.removeInternalDuplicates(from: input)
        XCTAssertFalse(out.contains("привет привет"))
    }

    func testRemoveInternalDuplicatesPreservesShortInput() {
        XCTAssertEqual(sut.removeInternalDuplicates(from: "одно"), "одно")
    }

    func testMergeCombinesSegments() {
        let merged = sut.merge(accumulated: "первая", new: " вторая", logger: nil)
        XCTAssertNotNil(merged)
        XCTAssertTrue(merged!.contains("первая"))
        XCTAssertTrue(merged!.contains("вторая"))
    }
}
