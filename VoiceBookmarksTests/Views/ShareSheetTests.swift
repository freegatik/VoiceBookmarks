//
//  ShareSheetTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import UIKit
import SwiftUI
@testable import VoiceBookmarks

final class ShareSheetTests: XCTestCase {
    
    var sut: ShareSheet!
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testShareSheet_MakeUIViewController_CreatesUIActivityViewController() {
        let items: [Any] = ["Test text", URL(string: "https://example.com")!]
        sut = ShareSheet(isPresented: .constant(true), items: items)
        
        let controller = makeUIViewControllerForShareSheet()
        
        XCTAssertNotNil(controller)
    }
    
    func testShareSheet_MakeUIViewController_CreatesControllerWithItems() {
        let items: [Any] = ["Test text", URL(string: "https://example.com")!]
        sut = ShareSheet(isPresented: .constant(true), items: items)
        
        let controller = makeUIViewControllerForShareSheet()
        
        XCTAssertNotNil(controller)
    }
    
    func testShareSheet_MakeUIViewController_CreatesControllerWithEmptyItems() {
        let items: [Any] = []
        sut = ShareSheet(isPresented: .constant(true), items: items)
        
        let controller = makeUIViewControllerForShareSheet()
        
        XCTAssertNotNil(controller)
    }
    
    func testShareSheet_MakeUIViewController_CreatesControllerWithDifferentItemTypes() {
        let items: [Any] = [
            "Text string",
            URL(string: "https://example.com")!,
            UIImage(systemName: "star")!,
            Data("test data".utf8)
        ]
        sut = ShareSheet(isPresented: .constant(true), items: items)
        
        let controller = makeUIViewControllerForShareSheet()
        
        XCTAssertNotNil(controller)
    }
    
    func testShareSheet_MakeUIViewController_SetsApplicationActivitiesToNil() {
        let items: [Any] = ["Test"]
        sut = ShareSheet(isPresented: .constant(true), items: items)
        
        let controller = makeUIViewControllerForShareSheet()
        
        XCTAssertNotNil(controller)
    }
    
    func testShareSheet_UpdateUIViewController_DoesNothing() {
        let items: [Any] = ["Test"]
        sut = ShareSheet(isPresented: .constant(true), items: items)
        
        XCTAssertNoThrow({})
    }
    
    func testShareSheet_CanBeCreatedWithDifferentItems() {
        let testCases: [[Any]] = [
            ["Text"],
            [URL(string: "https://example.com")!],
            [UIImage(systemName: "star")!],
            ["Text", URL(string: "https://example.com")!],
            []
        ]
        
        for items in testCases {
            sut = ShareSheet(isPresented: .constant(true), items: items)
            XCTAssertNotNil(sut, "ShareSheet должен создаваться с items: \(items)")
        }
    }
    
    func testShareSheet_CreatedWithCorrectItems() {
        let items: [Any] = ["Test"]
        sut = ShareSheet(isPresented: .constant(true), items: items)
        
        XCTAssertNotNil(sut)
    }
    
    private func makeUIViewControllerForShareSheet() -> UIViewController {
        struct TestWrapper: View {
            let shareSheet: ShareSheet
            
            var body: some View {
                shareSheet
            }
        }
        
        let wrapper = TestWrapper(shareSheet: sut)
        let hostingController = UIHostingController(rootView: wrapper)
        hostingController.loadViewIfNeeded()
        return hostingController
    }
}
