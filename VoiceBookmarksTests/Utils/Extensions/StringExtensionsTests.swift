//
//  StringExtensionsTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import UIKit
@testable import VoiceBookmarks

final class StringExtensionsTests: XCTestCase {
    
    func testString_IsNotEmpty_EmptyString() {
        let emptyString = ""
        XCTAssertFalse(emptyString.isNotEmpty)
    }
    
    func testString_IsNotEmpty_WhitespaceOnly() {
        let whitespaceString = "   "
        XCTAssertFalse(whitespaceString.isNotEmpty)
    }
    
    func testString_IsNotEmpty_WhitespaceAndNewlines() {
        let whitespaceNewlineString = " \n \t "
        XCTAssertFalse(whitespaceNewlineString.isNotEmpty)
    }
    
    func testString_IsNotEmpty_NonEmptyString() {
        let nonEmptyString = "Hello"
        XCTAssertTrue(nonEmptyString.isNotEmpty)
    }
    
    func testString_IsNotEmpty_StringWithWhitespace() {
        let stringWithWhitespace = "  Hello  "
        XCTAssertTrue(stringWithWhitespace.isNotEmpty)
    }
    
    func testString_Trimmed_EmptyString() {
        let emptyString = ""
        XCTAssertEqual(emptyString.trimmed, "")
    }
    
    func testString_Trimmed_WhitespaceOnly() {
        let whitespaceString = "   "
        XCTAssertEqual(whitespaceString.trimmed, "")
    }
    
    func testString_Trimmed_LeadingAndTrailingWhitespace() {
        let string = "  Hello World  "
        XCTAssertEqual(string.trimmed, "Hello World")
    }
    
    func testString_Trimmed_WhitespaceAndNewlines() {
        let string = "\n\t Hello \n\t "
        XCTAssertEqual(string.trimmed, "Hello")
    }
    
    func testString_Trimmed_NoWhitespace() {
        let string = "Hello"
        XCTAssertEqual(string.trimmed, "Hello")
    }
    
    func testString_IsValidURL_ValidHTTPURL() {
        let url = "https://example.com"
        XCTAssertTrue(url.isValidURL)
    }
    
    func testString_IsValidURL_ValidHTTPSURL() {
        let url = "https://example.com/path"
        XCTAssertTrue(url.isValidURL)
    }
    
    func testString_IsValidURL_ValidURLWithQuery() {
        let url = "https://example.com?param=value"
        XCTAssertTrue(url.isValidURL)
    }
    
    func testString_IsValidURL_InvalidNoScheme() {
        let url = "example.com"
        XCTAssertFalse(url.isValidURL)
    }
    
    func testString_IsValidURL_InvalidNoHost() {
        let url = "https://"
        XCTAssertFalse(url.isValidURL)
    }
    
    func testString_IsValidURL_EmptyString() {
        let url = ""
        XCTAssertFalse(url.isValidURL)
    }
    
    func testString_IsValidURL_InvalidFormat() {
        let url = "not a url"
        XCTAssertFalse(url.isValidURL)
    }
    
    func testString_Height_ShortString() {
        let string = "Hello"
        let font = UIFont.systemFont(ofSize: 16)
        let width: CGFloat = 200
        
        let height = string.height(withConstrainedWidth: width, font: font)
        
        XCTAssertGreaterThan(height, 0)
        XCTAssertLessThan(height, 50)

    }
    
    func testString_Height_LongString() {
        let string = "This is a very long string that should wrap to multiple lines when constrained to a specific width"
        let font = UIFont.systemFont(ofSize: 16)
        let width: CGFloat = 100
        
        let height = string.height(withConstrainedWidth: width, font: font)
        
        XCTAssertGreaterThan(height, 50)

    }
    
    func testString_Height_EmptyString() {
        let string = ""
        let font = UIFont.systemFont(ofSize: 16)
        let width: CGFloat = 200
        
        let height = string.height(withConstrainedWidth: width, font: font)
        
        XCTAssertGreaterThanOrEqual(height, 0)
    }
    
    func testString_Height_StringWithNewlines() {
        let string = "Line 1\nLine 2\nLine 3"
        let font = UIFont.systemFont(ofSize: 16)
        let width: CGFloat = 200
        
        let height = string.height(withConstrainedWidth: width, font: font)
        
        XCTAssertGreaterThan(height, 50)

    }
    
    func testString_Height_DifferentFontSizes() {
        let string = "Test string"
        let width: CGFloat = 200
        
        let smallFont = UIFont.systemFont(ofSize: 12)
        let largeFont = UIFont.systemFont(ofSize: 24)
        
        let smallHeight = string.height(withConstrainedWidth: width, font: smallFont)
        let largeHeight = string.height(withConstrainedWidth: width, font: largeFont)
        
        XCTAssertGreaterThan(largeHeight, smallHeight)
    }
}
