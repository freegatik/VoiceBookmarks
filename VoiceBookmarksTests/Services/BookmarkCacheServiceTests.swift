//
//  BookmarkCacheServiceTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class BookmarkCacheServiceTests: XCTestCase {
    
    var sut: BookmarkCacheService!
    
    override func setUp() {
        super.setUp()
        sut = BookmarkCacheService.shared
        
        sut.clearAllCache()
    }
    
    override func tearDown() {
        sut.clearAllCache()
        sut = nil
        super.tearDown()
    }
    
    func testBookmarkCacheService_Singleton_IsAccessible() {
        XCTAssertNotNil(BookmarkCacheService.shared)
    }
    
    func testBookmarkCacheService_Singleton_ReturnsSameInstance() {
        let instance1 = BookmarkCacheService.shared
        let instance2 = BookmarkCacheService.shared
        XCTAssertTrue(instance1 === instance2)
    }
    
    func testBookmarkCacheService_SaveBookmarks_SavesBookmarks() {
        let testBookmarks = createTestBookmarks(count: 3, category: "SelfReflection")
        
        sut.saveBookmarks(testBookmarks, for: "SelfReflection")
        
        let cached = sut.getCachedBookmarks(for: "SelfReflection")
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 3)
        XCTAssertEqual(cached?.first?.category, "SelfReflection")
    }
    
    func testBookmarkCacheService_SaveBookmarks_OverwritesExisting() {
        let firstBookmarks = createTestBookmarks(count: 2, category: "SelfReflection")
        sut.saveBookmarks(firstBookmarks, for: "SelfReflection")
        
        let secondBookmarks = createTestBookmarks(count: 5, category: "SelfReflection")
        sut.saveBookmarks(secondBookmarks, for: "SelfReflection")
        
        let cached = sut.getCachedBookmarks(for: "SelfReflection")
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 5, "Должны быть сохранены новые закладки")
    }
    
    func testBookmarkCacheService_SaveBookmarks_SavesEmptyArray() {
        let emptyBookmarks: [Bookmark] = []
        sut.saveBookmarks(emptyBookmarks, for: "Tasks")
        
        let cached = sut.getCachedBookmarks(for: "Tasks")
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 0)
    }
    
    func testBookmarkCacheService_GetCachedBookmarks_ReturnsNilWhenNoCache() {
        let cached = sut.getCachedBookmarks(for: "Uncategorised")
        XCTAssertNil(cached, "Должен вернуться nil если кеш отсутствует")
    }
    
    func testBookmarkCacheService_GetCachedBookmarks_ReturnsBookmarksWhenValid() {
        let testBookmarks = createTestBookmarks(count: 2, category: "ProjectResources")
        sut.saveBookmarks(testBookmarks, for: "ProjectResources")
        
        let cached = sut.getCachedBookmarks(for: "ProjectResources")
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 2)
        XCTAssertEqual(cached?.first?.category, "ProjectResources")
    }
    
    func testBookmarkCacheService_GetCachedBookmarks_ReturnsNilWhenExpired() {
        let testBookmarks = createTestBookmarks(count: 1, category: "SelfReflection")
        sut.saveBookmarks(testBookmarks, for: "SelfReflection")
        
        let expiredTime = Date().timeIntervalSince1970 - 400

        UserDefaults.standard.set(expiredTime, forKey: "cached_bookmarks_expiration_SelfReflection")
        
        let cached = sut.getCachedBookmarks(for: "SelfReflection")
        XCTAssertNil(cached, "Должен вернуться nil если кеш истек")
    }
    
    func testBookmarkCacheService_GetCachedBookmarks_ReturnsNilWhenDataCorrupted() {
        let invalidData = "invalid json".data(using: .utf8)!
        UserDefaults.standard.set(invalidData, forKey: "cached_bookmarks_SelfReflection")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "cached_bookmarks_expiration_SelfReflection")
        
        let cached = sut.getCachedBookmarks(for: "SelfReflection")
        XCTAssertNil(cached, "Должен вернуться nil если данные повреждены")
    }
    
    func testBookmarkCacheService_GetCachedBookmarks_ReturnsNilWhenDataMissing() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "cached_bookmarks_expiration_Tasks")
        
        let cached = sut.getCachedBookmarks(for: "Tasks")
        XCTAssertNil(cached, "Должен вернуться nil если данные отсутствуют")
    }
    
    func testBookmarkCacheService_ClearCache_RemovesCacheForCategory() {
        let testBookmarks = createTestBookmarks(count: 2, category: "SelfReflection")
        sut.saveBookmarks(testBookmarks, for: "SelfReflection")
        
        let cachedBefore = sut.getCachedBookmarks(for: "SelfReflection")
        XCTAssertNotNil(cachedBefore)
        
        sut.clearCache(for: "SelfReflection")
        
        let cachedAfter = sut.getCachedBookmarks(for: "SelfReflection")
        XCTAssertNil(cachedAfter, "Кеш должен быть удален")
    }
    
    func testBookmarkCacheService_ClearCache_DoesNotRemoveOtherCategories() {
        let bookmarks1 = createTestBookmarks(count: 2, category: "SelfReflection")
        let bookmarks2 = createTestBookmarks(count: 3, category: "Tasks")
        
        sut.saveBookmarks(bookmarks1, for: "SelfReflection")
        sut.saveBookmarks(bookmarks2, for: "Tasks")
        
        sut.clearCache(for: "SelfReflection")
        
        let cachedTasks = sut.getCachedBookmarks(for: "Tasks")
        XCTAssertNotNil(cachedTasks)
        XCTAssertEqual(cachedTasks?.count, 3)
        
        let cachedSelfReflection = sut.getCachedBookmarks(for: "SelfReflection")
        XCTAssertNil(cachedSelfReflection)
    }
    
    func testBookmarkCacheService_ClearAllCache_RemovesAllCache() {
        let bookmarks1 = createTestBookmarks(count: 2, category: "SelfReflection")
        let bookmarks2 = createTestBookmarks(count: 3, category: "Tasks")
        let bookmarks3 = createTestBookmarks(count: 1, category: "ProjectResources")
        
        sut.saveBookmarks(bookmarks1, for: "SelfReflection")
        sut.saveBookmarks(bookmarks2, for: "Tasks")
        sut.saveBookmarks(bookmarks3, for: "ProjectResources")
        
        XCTAssertNotNil(sut.getCachedBookmarks(for: "SelfReflection"))
        XCTAssertNotNil(sut.getCachedBookmarks(for: "Tasks"))
        XCTAssertNotNil(sut.getCachedBookmarks(for: "ProjectResources"))
        
        sut.clearAllCache()
        
        XCTAssertNil(sut.getCachedBookmarks(for: "SelfReflection"))
        XCTAssertNil(sut.getCachedBookmarks(for: "Tasks"))
        XCTAssertNil(sut.getCachedBookmarks(for: "ProjectResources"))
    }
    
    func testBookmarkCacheService_GetCachedBookmarks_WorksWithDifferentCategories() {
        let bookmarks1 = createTestBookmarks(count: 2, category: "SelfReflection")
        let bookmarks2 = createTestBookmarks(count: 3, category: "Tasks")
        
        sut.saveBookmarks(bookmarks1, for: "SelfReflection")
        sut.saveBookmarks(bookmarks2, for: "Tasks")
        
        let cached1 = sut.getCachedBookmarks(for: "SelfReflection")
        let cached2 = sut.getCachedBookmarks(for: "Tasks")
        
        XCTAssertNotNil(cached1)
        XCTAssertNotNil(cached2)
        XCTAssertEqual(cached1?.count, 2)
        XCTAssertEqual(cached2?.count, 3)
    }
    
    func testBookmarkCacheService_GetCachedBookmarks_ReturnsCorrectData() {
        let testBookmarks = createTestBookmarks(count: 2, category: "SelfReflection")
        sut.saveBookmarks(testBookmarks, for: "SelfReflection")
        
        let cached = sut.getCachedBookmarks(for: "SelfReflection")
        XCTAssertNotNil(cached)
        
        if let cached = cached, cached.count >= 2 {
            XCTAssertEqual(cached[0].category, "SelfReflection")
            XCTAssertEqual(cached[1].category, "SelfReflection")
            XCTAssertNotNil(cached[0].id)
            XCTAssertNotNil(cached[1].id)
        }
    }
    
    func testBookmarkCacheService_GetCachedBookmarks_ReturnsNilForNonExistentCategory() {
        let cached = sut.getCachedBookmarks(for: "NonExistentCategory")
        XCTAssertNil(cached)
    }
    
    func testBookmarkCacheService_SaveBookmarks_HandlesEncodingError() {
        let testBookmarks = createTestBookmarks(count: 1, category: "SelfReflection")
        
        XCTAssertNoThrow(sut.saveBookmarks(testBookmarks, for: "SelfReflection"))
    }
    
    func testBookmarkCacheService_Cache_ValidFor5Minutes() {
        let testBookmarks = createTestBookmarks(count: 1, category: "SelfReflection")
        sut.saveBookmarks(testBookmarks, for: "SelfReflection")
        
        let recentTime = Date().timeIntervalSince1970 - 60

        UserDefaults.standard.set(recentTime, forKey: "cached_bookmarks_expiration_SelfReflection")
        
        let cached = sut.getCachedBookmarks(for: "SelfReflection")
        XCTAssertNotNil(cached, "Кеш должен быть валиден в течение 5 минут")
    }
    
    func testBookmarkCacheService_ClearCache_WorksWithNonExistentCategory() {
        XCTAssertNoThrow(sut.clearCache(for: "NonExistentCategory"))
    }
    
    func testBookmarkCacheService_ClearAllCache_WorksWhenEmpty() {
        XCTAssertNoThrow(sut.clearAllCache())
        
        XCTAssertNil(sut.getCachedBookmarks(for: "SelfReflection"))
        XCTAssertNil(sut.getCachedBookmarks(for: "Tasks"))
    }
    
    func testBookmarkCacheService_Cache_ValidWhenLessThan300Seconds() {
        let testBookmarks = createTestBookmarks(count: 1, category: "SelfReflection")
        
        let almost300SecondsAgo = Date().timeIntervalSince1970 - 299
        UserDefaults.standard.set(almost300SecondsAgo, forKey: "cached_bookmarks_expiration_SelfReflection")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(testBookmarks) {
            UserDefaults.standard.set(data, forKey: "cached_bookmarks_SelfReflection")
        }
        
        let cached = sut.getCachedBookmarks(for: "SelfReflection")
        XCTAssertNotNil(cached, "Кеш должен быть валиден если возраст меньше 300 секунд")
    }
    
    func testBookmarkCacheService_Cache_ExpiresWhenOlderThan300Seconds() {
        let testBookmarks = createTestBookmarks(count: 1, category: "SelfReflection")
        sut.saveBookmarks(testBookmarks, for: "SelfReflection")
        
        let moreThan300SecondsAgo = Date().timeIntervalSince1970 - 300.1
        UserDefaults.standard.set(moreThan300SecondsAgo, forKey: "cached_bookmarks_expiration_SelfReflection")
        
        let cached = sut.getCachedBookmarks(for: "SelfReflection")
        XCTAssertNil(cached, "Кеш должен истечь если возраст больше 300 секунд")
    }
    
    func testBookmarkCacheService_ClearAllCache_OnlyRemovesBookmarkCaches() {
        let testBookmarks = createTestBookmarks(count: 1, category: "SelfReflection")
        sut.saveBookmarks(testBookmarks, for: "SelfReflection")
        
        UserDefaults.standard.set("test_value", forKey: "test_other_key")
        
        sut.clearAllCache()
        
        XCTAssertNil(sut.getCachedBookmarks(for: "SelfReflection"))
        
        let otherValue = UserDefaults.standard.string(forKey: "test_other_key")
        XCTAssertEqual(otherValue, "test_value", "Другие ключи не должны быть удалены")
        
        UserDefaults.standard.removeObject(forKey: "test_other_key")
    }
    
    private func createTestBookmarks(count: Int, category: String) -> [Bookmark] {
        var bookmarks: [Bookmark] = []
        for i in 0..<count {
            let bookmark = Bookmark(
                id: UUID().uuidString,
                fileName: "test_file_\(i).txt",
                contentType: .text,
                category: category,
                voiceNote: nil,
                fileUrl: nil,
                summary: "Test summary \(i)",
                content: "Test content \(i)",
                contentHash: nil,
                timestamp: Date(),
                totalChunks: nil,
                distance: nil
            )
            bookmarks.append(bookmark)
        }
        return bookmarks
    }
}
