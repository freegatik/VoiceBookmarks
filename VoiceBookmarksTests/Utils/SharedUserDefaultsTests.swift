//
//  SharedUserDefaultsTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class SharedUserDefaultsTests: XCTestCase {
    
    var testDefaults: UserDefaults!
    var suiteName: String!
    
    override func setUp() {
        super.setUp()
        suiteName = "test.voicebookmarks.shared"
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults?.removePersistentDomain(forName: suiteName)
    }
    
    override func tearDown() {
        if let suiteName = suiteName {
            testDefaults?.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        suiteName = nil
        super.tearDown()
    }
    
    func testSharedUserDefaults_Shared_ReturnsUserDefaults() {
    }
    
    func testSharedUserDefaults_SaveUserId_SavesUserId() {
        let userId = "test-user-123"
        testDefaults?.set(userId, forKey: Constants.AppGroups.userIdKey)
        testDefaults?.synchronize()
        
        let savedUserId = testDefaults?.string(forKey: Constants.AppGroups.userIdKey)
        XCTAssertEqual(savedUserId, userId)
    }
    
    func testSharedUserDefaults_GetUserId_ReturnsSavedUserId() {
        let userId = "test-user-456"
        testDefaults?.set(userId, forKey: Constants.AppGroups.userIdKey)
        testDefaults?.synchronize()
        
        let retrievedUserId = testDefaults?.string(forKey: Constants.AppGroups.userIdKey)
        XCTAssertEqual(retrievedUserId, userId)
    }
    
    func testSharedUserDefaults_GetUserId_ReturnsNilWhenNotSaved() {
        testDefaults?.removeObject(forKey: Constants.AppGroups.userIdKey)
        
        let retrievedUserId = testDefaults?.string(forKey: Constants.AppGroups.userIdKey)
        XCTAssertNil(retrievedUserId)
    }
    
    func testSharedUserDefaults_SavePendingData_SavesData() {
        let testData: [String: Any] = [
            "key1": "value1",
            "key2": 123,
            "key3": true
        ]
        
        testDefaults?.set(testData, forKey: Constants.AppGroups.sharedDataKey)
        testDefaults?.synchronize()
        
        let savedData = testDefaults?.dictionary(forKey: Constants.AppGroups.sharedDataKey)
        XCTAssertNotNil(savedData)
        XCTAssertEqual(savedData?["key1"] as? String, "value1")
        XCTAssertEqual(savedData?["key2"] as? Int, 123)
        XCTAssertEqual(savedData?["key3"] as? Bool, true)
    }
    
    func testSharedUserDefaults_GetPendingData_ReturnsSavedData() {
        let testData: [String: Any] = [
            "content": "test content",
            "type": "text"
        ]
        
        testDefaults?.set(testData, forKey: Constants.AppGroups.sharedDataKey)
        testDefaults?.synchronize()
        
        let retrievedData = testDefaults?.dictionary(forKey: Constants.AppGroups.sharedDataKey)
        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData?["content"] as? String, "test content")
        XCTAssertEqual(retrievedData?["type"] as? String, "text")
    }
    
    func testSharedUserDefaults_GetPendingData_ReturnsNilWhenNotSaved() {
        testDefaults?.removeObject(forKey: Constants.AppGroups.sharedDataKey)
        
        let retrievedData = testDefaults?.dictionary(forKey: Constants.AppGroups.sharedDataKey)
        XCTAssertNil(retrievedData)
    }
    
    func testSharedUserDefaults_ClearPendingData_RemovesData() {
        let testData: [String: Any] = ["key": "value"]
        testDefaults?.set(testData, forKey: Constants.AppGroups.sharedDataKey)
        testDefaults?.synchronize()
        
        XCTAssertNotNil(testDefaults?.dictionary(forKey: Constants.AppGroups.sharedDataKey))
        
        testDefaults?.removeObject(forKey: Constants.AppGroups.sharedDataKey)
        testDefaults?.synchronize()
        
        let retrievedData = testDefaults?.dictionary(forKey: Constants.AppGroups.sharedDataKey)
        XCTAssertNil(retrievedData)
    }
    
    func testSharedUserDefaults_SaveUserId_OverwritesExisting() {
        let firstUserId = "user-1"
        testDefaults?.set(firstUserId, forKey: Constants.AppGroups.userIdKey)
        testDefaults?.synchronize()
        
        let secondUserId = "user-2"
        testDefaults?.set(secondUserId, forKey: Constants.AppGroups.userIdKey)
        testDefaults?.synchronize()
        
        let retrievedUserId = testDefaults?.string(forKey: Constants.AppGroups.userIdKey)
        XCTAssertEqual(retrievedUserId, secondUserId)
        XCTAssertNotEqual(retrievedUserId, firstUserId)
    }
    
    func testSharedUserDefaults_SavePendingData_OverwritesExisting() {
        let firstData: [String: Any] = ["key1": "value1"]
        testDefaults?.set(firstData, forKey: Constants.AppGroups.sharedDataKey)
        testDefaults?.synchronize()
        
        let secondData: [String: Any] = ["key2": "value2"]
        testDefaults?.set(secondData, forKey: Constants.AppGroups.sharedDataKey)
        testDefaults?.synchronize()
        
        let retrievedData = testDefaults?.dictionary(forKey: Constants.AppGroups.sharedDataKey)
        XCTAssertEqual(retrievedData?["key2"] as? String, "value2")
        XCTAssertNil(retrievedData?["key1"])
    }
    
    func testSharedUserDefaults_UsesCorrectKeys() {
        let userIdKey = Constants.AppGroups.userIdKey
        let sharedDataKey = Constants.AppGroups.sharedDataKey
        
        XCTAssertEqual(userIdKey, "shared_user_id")
        XCTAssertEqual(sharedDataKey, "shared_clipboard_data")
    }
    
    func testSharedUserDefaults_SetLastSharedItem_SavesItem() {
        let testPath = "/test/path/to/file.txt"
        SharedUserDefaults.setLastSharedItem(filePath: testPath)
        
        let lastItem = SharedUserDefaults.getLastSharedItem()
        XCTAssertNotNil(lastItem, "Последний элемент должен быть сохранен")
        XCTAssertEqual(lastItem?.filePath, testPath, "Путь должен совпадать")
    }
    
    func testSharedUserDefaults_GetLastSharedItem_ReturnsSavedItem() {
        let testPath = "/test/path/to/file2.txt"
        SharedUserDefaults.setLastSharedItem(filePath: testPath)
        
        let retrieved = SharedUserDefaults.getLastSharedItem()
        XCTAssertNotNil(retrieved, "Должен вернуться сохраненный элемент")
        XCTAssertEqual(retrieved?.filePath, testPath, "Путь должен совпадать")
    }
    
    func testSharedUserDefaults_GetLastSharedItem_ReturnsNilWhenNotSaved() {
        SharedUserDefaults.setLastSharedItem(filePath: "")
        
        let retrieved = SharedUserDefaults.getLastSharedItem()
        XCTAssertNil(retrieved, "Должен вернуться nil если элемент не сохранен")
    }
    
    func testSharedUserDefaults_SetLastSharedItem_WithEmptyString_ClearsItem() {
        SharedUserDefaults.setLastSharedItem(filePath: "/test/path.txt")
        
        SharedUserDefaults.setLastSharedItem(filePath: "")
        
        let retrieved = SharedUserDefaults.getLastSharedItem()
        XCTAssertNil(retrieved, "Элемент должен быть очищен")
    }
    
    func testSharedUserDefaults_Shared_ReturnsCachedInstance() {
        let instance1 = SharedUserDefaults.shared
        let instance2 = SharedUserDefaults.shared
        
        if let inst1 = instance1, let inst2 = instance2 {
            XCTAssertNotNil(inst1)
            XCTAssertNotNil(inst2)
        }
    }
}

