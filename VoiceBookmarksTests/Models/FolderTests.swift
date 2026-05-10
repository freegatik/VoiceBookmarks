//
//  FolderTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class FolderTests: XCTestCase {
    
    func testFolder_DisplayName_SelfReflection_ReturnsSelfReflection() {
        let folder = Folder(name: "SelfReflection")
        XCTAssertEqual(folder.displayName, "Self-reflection")
    }
    
    func testFolder_DisplayName_Tasks_ReturnsTasks() {
        let folder = Folder(name: "Tasks")
        XCTAssertEqual(folder.displayName, "Tasks")
    }
    
    func testFolder_DisplayName_ProjectResources_ReturnsProjectResources() {
        let folder = Folder(name: "ProjectResources")
        XCTAssertEqual(folder.displayName, "Project resources")
    }
    
    func testFolder_DisplayName_Uncategorised_ReturnsUncategorised() {
        let folder = Folder(name: "Uncategorised")
        XCTAssertEqual(folder.displayName, "Uncategorized")
    }
    
    func testFolder_DisplayName_Unknown_ReturnsName() {
        let folder = Folder(name: "UnknownFolder")
        XCTAssertEqual(folder.displayName, "UnknownFolder")
    }
    
    func testFolder_Icon_SelfReflection_ReturnsPerson() {
        let folder = Folder(name: "SelfReflection")
        XCTAssertEqual(folder.icon, "person.circle.fill")
    }
    
    func testFolder_Icon_Tasks_ReturnsChecklist() {
        let folder = Folder(name: "Tasks")
        XCTAssertEqual(folder.icon, "checklist")
    }
    
    func testFolder_Icon_ProjectResources_ReturnsFolder() {
        let folder = Folder(name: "ProjectResources")
        XCTAssertEqual(folder.icon, "folder.fill")
    }
    
    func testFolder_Icon_Uncategorised_ReturnsQuestionmark() {
        let folder = Folder(name: "Uncategorised")
        XCTAssertEqual(folder.icon, "questionmark.folder.fill")
    }
    
    func testFolder_Icon_Unknown_ReturnsDefault() {
        let folder = Folder(name: "UnknownFolder")
        XCTAssertEqual(folder.icon, "folder.fill")
    }
    
    func testFolder_ID_EqualsName() {
        let folder = Folder(name: "TestFolder")
        XCTAssertEqual(folder.id, "TestFolder")
    }
    
    func testFolder_Predefined_ContainsAllCategories() {
        let predefined = Folder.predefined
        XCTAssertTrue(predefined.contains("SelfReflection"))
        XCTAssertTrue(predefined.contains("Tasks"))
        XCTAssertTrue(predefined.contains("ProjectResources"))
        XCTAssertTrue(predefined.contains("Uncategorised"))
        XCTAssertEqual(predefined.count, 4)
    }
}
