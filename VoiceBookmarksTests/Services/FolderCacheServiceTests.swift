//
//  FolderCacheServiceTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class FolderCacheServiceTests: XCTestCase {
    
    var sut: FolderCacheService!
    
    override func setUp() {
        super.setUp()
        sut = FolderCacheService.shared
        sut.clearCache()
    }
    
    override func tearDown() {
        sut.clearCache()
        super.tearDown()
    }
    
    func testFolderCacheService_Singleton_IsAccessible() {
        XCTAssertNotNil(FolderCacheService.shared)
    }
    
    func testFolderCacheService_Singleton_ReturnsSameInstance() {
        let instance1 = FolderCacheService.shared
        let instance2 = FolderCacheService.shared
        XCTAssertTrue(instance1 === instance2)
    }
    
    func testFolderCacheService_SaveFolders_SavesFolders() {
        let folders = [
            Folder(name: "SelfReflection"),
            Folder(name: "Tasks")
        ]
        
        sut.saveFolders(folders)
        
        let cached = sut.getCachedFolders()
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 2)
    }
    
    func testFolderCacheService_GetCachedFolders_ReturnsNilWhenEmpty() {
        let cached = sut.getCachedFolders()
        XCTAssertNil(cached)
    }
    
    func testFolderCacheService_GetCachedFolders_ReturnsSavedFolders() {
        let folders = [
            Folder(name: "SelfReflection"),
            Folder(name: "Tasks"),
            Folder(name: "ProjectResources")
        ]
        
        sut.saveFolders(folders)
        
        let cached = sut.getCachedFolders()
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 3)
        XCTAssertEqual(cached?[0].name, "SelfReflection")
        XCTAssertEqual(cached?[1].name, "Tasks")
        XCTAssertEqual(cached?[2].name, "ProjectResources")
    }
    
    func testFolderCacheService_GetCachedFolders_ReturnsNilWhenExpired() {
        let folders = [Folder(name: "Test")]
        sut.saveFolders(folders)
        
        let expiredTime = Date().timeIntervalSince1970 - 7200 // 2 часа назад
        UserDefaults.standard.set(expiredTime, forKey: "cached_folders_expiration")
        
        let cached = sut.getCachedFolders()
        XCTAssertNil(cached, "Кеш должен быть истекшим")
    }
    
    func testFolderCacheService_GetCachedFolders_ReturnsFoldersWhenValid() {
        sut.clearCache()
        
        let folders = [Folder(name: "Test")]
        sut.saveFolders(folders)
        
        let cached = sut.getCachedFolders()
        XCTAssertNotNil(cached, "Кеш должен быть валиден сразу после сохранения")
        XCTAssertEqual(cached?.count, 1, "Должна быть одна папка в кеше")
    }
    
    func testFolderCacheService_ClearCache_RemovesCache() {
        let folders = [Folder(name: "Test")]
        sut.saveFolders(folders)
        
        sut.clearCache()
        
        let cached = sut.getCachedFolders()
        XCTAssertNil(cached)
    }
    
    func testFolderCacheService_ClearCache_RemovesBothKeys() {
        let folders = [Folder(name: "Test")]
        sut.saveFolders(folders)
        
        sut.clearCache()
        
        let folderNames = UserDefaults.standard.array(forKey: "cached_folders")
        let expiration = UserDefaults.standard.object(forKey: "cached_folders_expiration")
        
        XCTAssertNil(folderNames)
        XCTAssertNil(expiration)
    }
    
    func testFolderCacheService_SaveFolders_OverwritesPreviousCache() {
        let firstFolders = [Folder(name: "First")]
        sut.saveFolders(firstFolders)
        
        let secondFolders = [
            Folder(name: "Second"),
            Folder(name: "Third")
        ]
        sut.saveFolders(secondFolders)
        
        let cached = sut.getCachedFolders()
        XCTAssertEqual(cached?.count, 2)
        XCTAssertEqual(cached?[0].name, "Second")
        XCTAssertEqual(cached?[1].name, "Third")
    }
    
    func testFolderCacheService_GetCachedFolders_ReturnsNilWhenInvalidData() {
        UserDefaults.standard.set([1, 2, 3], forKey: "cached_folders")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "cached_folders_expiration")
        
        let cached = sut.getCachedFolders()
        XCTAssertNil(cached)
    }
    
    func testFolderCacheService_GetCachedFolders_CreatesFoldersFromNames() {
        let folders = [
            Folder(name: "SelfReflection"),
            Folder(name: "Uncategorised")
        ]
        sut.saveFolders(folders)
        
        let cached = sut.getCachedFolders()
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?[0].displayName, "Саморефлексия")
        XCTAssertEqual(cached?[1].displayName, "Без категории")
    }
}

