//
//  KeychainServiceTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class KeychainServiceTests: XCTestCase {
    
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }
    
    var sut: KeychainService!
    
    private static let serialQueue = DispatchQueue(label: "com.voicebookmarks.keychain.test.serial")
    
    override func setUp() {
        super.setUp()
        sut = KeychainService.shared
        
        Self.serialQueue.sync {
            for _ in 0..<3 {
        _ = sut.deleteUserId()
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }
    
    override func tearDown() {
        Self.serialQueue.sync {
            for _ in 0..<3 {
        _ = sut.deleteUserId()
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        sut = nil
        super.tearDown()
    }
    
    func testKeychainService_Singleton_IsAccessible() {
        XCTAssertNotNil(KeychainService.shared)
    }
    
    func testKeychainService_Singleton_ReturnsSameInstance() {
        let instance1 = KeychainService.shared
        let instance2 = KeychainService.shared
        XCTAssertTrue(instance1 === instance2)
    }
    
    func testSaveUserId_ValidUserId_ReturnsTrue() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Keychain тесты нестабильны в симуляторе. Используйте реальное устройство для полного тестирования Keychain.")
        #else
            let testUserId = "test-user-id-123-\(UUID().uuidString)"
            
            var result = false
            for _ in 0..<5 {
            result = await sut.saveUserId(testUserId)
                if result {
                    break
                }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            
            XCTAssertTrue(result, "saveUserId должна вернуть true")
            
        try? await Task.sleep(nanoseconds: 200_000_000)
            var retrieved: String? = nil
            for _ in 0..<10 {
                retrieved = sut.getUserId()
                if retrieved == testUserId {
                    break
                }
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 секунды
        }
        XCTAssertEqual(retrieved, testUserId)
        #endif
    }
    
    func testGetUserId_AfterSave_ReturnsCorrectUserId() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Keychain тесты нестабильны в симуляторе. Используйте реальное устройство для полного тестирования Keychain.")
        #else
            let testUserId = "test-user-id-456-\(UUID().uuidString)"
            
            var saveResult = false
            for _ in 0..<5 {
            saveResult = await sut.saveUserId(testUserId)
                if saveResult {
                    break
                }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            XCTAssertTrue(saveResult, "Сохранение должно быть успешным")
            
        try? await Task.sleep(nanoseconds: 250_000_000)
            
            var retrievedUserId: String? = nil
            for attempt in 0..<15 {
                retrievedUserId = sut.getUserId()
                if retrievedUserId == testUserId {
                    break
                }
                if attempt < 14 {
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 секунды
            }
        }
        
        XCTAssertEqual(retrievedUserId, testUserId)
        #endif
    }
    
    func testGetUserId_NothingSaved_ReturnsNil() {
        Self.serialQueue.sync {
            for _ in 0..<3 {
                _ = sut.deleteUserId()
                Thread.sleep(forTimeInterval: 0.05)
            }
            
        let userId = sut.getUserId()
            XCTAssertNil(userId, "Если ничего не сохранено, должно вернуться nil")
        }
    }
    
    func testDeleteUserId_AfterSave_ReturnsTrue() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Keychain тесты нестабильны в симуляторе. Используйте реальное устройство для полного тестирования Keychain.")
        #else
            let testId = "test-id-\(UUID().uuidString)"
            
            var saveResult = false
            for _ in 0..<5 {
            saveResult = await sut.saveUserId(testId)
                if saveResult {
                    break
                }
            try? await Task.sleep(nanoseconds: 100_000_000)
            }
            XCTAssertTrue(saveResult)
            
        try? await Task.sleep(nanoseconds: 250_000_000)
            
            var beforeDelete = sut.getUserId()
            for _ in 0..<10 {
                if beforeDelete == testId {
                    break
                }
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 секунды
                beforeDelete = sut.getUserId()
            }
            XCTAssertEqual(beforeDelete, testId)
            
            var result = false
            for _ in 0..<5 {
                result = sut.deleteUserId()
                if result {
                    break
                }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            XCTAssertTrue(result)
            
        try? await Task.sleep(nanoseconds: 250_000_000)
            
            var afterDelete = sut.getUserId()
            for _ in 0..<10 {
                if afterDelete == nil {
                    break
                }
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 секунды
                afterDelete = sut.getUserId()
            }
            XCTAssertNil(afterDelete)
        #endif
    }
    
    func testGetUserId_AfterDelete_ReturnsNil() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Keychain тесты нестабильны в симуляторе. Используйте реальное устройство для полного тестирования Keychain.")
        #else
            let testId = "test-id-\(UUID().uuidString)"
            
            var saveResult = false
            for _ in 0..<5 {
            saveResult = await sut.saveUserId(testId)
                if saveResult {
                    break
                }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            XCTAssertTrue(saveResult, "Сохранение должно быть успешным")
            
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 секунды
            
            var beforeDelete = sut.getUserId()
            for _ in 0..<10 {
                if beforeDelete == testId {
                    break
                }
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 секунды
                beforeDelete = sut.getUserId()
            }
            XCTAssertEqual(beforeDelete, testId, "Значение должно быть сохранено перед удалением")
            
            var deleteResult = false
            for _ in 0..<5 {
                deleteResult = sut.deleteUserId()
                if deleteResult {
                    break
                }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            XCTAssertTrue(deleteResult, "Удаление должно быть успешным")
            
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 секунды
            
            var userId: String? = "not-nil"
            for attempt in 0..<15 {
                userId = sut.getUserId()
                if userId == nil {
                    break
                }
                if attempt < 14 {
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 секунды
            }
        }
        
        XCTAssertNil(userId, "После удаления userId должен быть nil")
        #endif
    }
    
    func testSaveUserId_CalledTwice_OverwritesValue() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Keychain тесты нестабильны в симуляторе. Используйте реальное устройство для полного тестирования Keychain.")
        #else
            var firstResult = false
            for _ in 0..<5 {
            firstResult = await sut.saveUserId("first-id")
                if firstResult {
                    break
                }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            XCTAssertTrue(firstResult, "Первое сохранение должно быть успешным")
            
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 секунды
            
            var firstValue = sut.getUserId()
            for _ in 0..<10 {
                if firstValue == "first-id" {
                    break
                }
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 секунды
                firstValue = sut.getUserId()
            }
            XCTAssertEqual(firstValue, "first-id", "Первое значение должно быть сохранено")
            
            var secondResult = false
            for _ in 0..<5 {
            secondResult = await sut.saveUserId("second-id")
                if secondResult {
                    break
                }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            XCTAssertTrue(secondResult, "Второе сохранение должно быть успешным")
            
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 секунды
            
            var retrievedUserId = sut.getUserId()
            for attempt in 0..<15 {
                if retrievedUserId == "second-id" {
                    break
                }
                if attempt < 14 {
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 секунды
                    retrievedUserId = sut.getUserId()
                }
            }
            
            XCTAssertEqual(retrievedUserId, "second-id", "Повторное сохранение должно перезаписать значение. Получено: \(retrievedUserId ?? "nil")")
        #endif
    }
    
    func testSaveUserId_DifferentUserIds_WorksCorrectly() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Keychain тесты нестабильны в симуляторе. Используйте реальное устройство для полного тестирования Keychain.")
        #else
            let userId1 = "user-1-\(UUID().uuidString)"
            let userId2 = "user-2-\(UUID().uuidString)"
        
            var save1Result = false
            for _ in 0..<5 {
            save1Result = await sut.saveUserId(userId1)
                if save1Result {
                    break
                }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            XCTAssertTrue(save1Result, "Сохранение первого userId должно быть успешным")
            
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 секунды
            
            var retrieved1 = sut.getUserId()
            for _ in 0..<10 {
                if retrieved1 == userId1 {
                    break
                }
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 секунды
                retrieved1 = sut.getUserId()
            }
            XCTAssertEqual(retrieved1, userId1, "Первый userId должен быть сохранен")
        
            var save2Result = false
            for _ in 0..<5 {
            save2Result = await sut.saveUserId(userId2)
                if save2Result {
                    break
                }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            XCTAssertTrue(save2Result, "Сохранение второго userId должно быть успешным")
            
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 секунды
            
            var retrieved2 = sut.getUserId()
            for attempt in 0..<15 {
                if retrieved2 == userId2 {
                    break
                }
                if attempt < 14 {
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 секунды
                    retrieved2 = sut.getUserId()
                }
            }
            XCTAssertEqual(retrieved2, userId2, "Второй userId должен перезаписать первый. Получено: \(retrieved2 ?? "nil")")
        #endif
    }
    
    func testSaveUserId_EmptyString_HandlesCorrectly() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Keychain тесты нестабильны в симуляторе. Используйте реальное устройство для полного тестирования Keychain.")
        #else
            var result = false
            for _ in 0..<5 {
            result = await sut.saveUserId("")
                if result {
                    break
                }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            XCTAssertTrue(result, "Сохранение пустой строки должно вернуть true")
        
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 секунды
            
            var retrievedUserId: String? = nil
            for attempt in 0..<15 {
                retrievedUserId = sut.getUserId()
                if retrievedUserId != nil {
                    break
                }
                if attempt < 14 {
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 секунды
                }
            }
            
            XCTAssertNotNil(retrievedUserId, "Пустая строка должна быть сохранена")
            XCTAssertEqual(retrievedUserId, "", "Пустая строка должна быть корректно сохранена и получена")
        #endif
    }
}

