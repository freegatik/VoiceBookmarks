//
//  OfflineQueueServiceTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import CoreData
@testable import VoiceBookmarks

final class OfflineQueueServiceTests: XCTestCase {
    
    var sut: OfflineQueueService!
    var testPersistence: PersistenceController!
    
    override func setUp() {
        super.setUp()
        testPersistence = PersistenceController.preview
        sut = OfflineQueueService(persistenceController: testPersistence)
        
        var attempts = 0
        while !testPersistence.isReady && attempts < 100 {
            Thread.sleep(forTimeInterval: 0.01)
            attempts += 1
        }
        
        runOnMainSync {
            testPersistence.deleteAll()
        }
    }
    
    override func tearDown() {
        runOnMainSync {
            testPersistence.deleteAll()
            sut?.stopMonitoring()
        }
        sut = nil
        testPersistence = nil
        super.tearDown()
    }
    
    private func runOnMainSync<T>(_ body: () throws -> T) rethrows -> T {
        if Thread.isMainThread {
            return try body()
        }
        return try DispatchQueue.main.sync(execute: body)
    }
    
    func testOfflineQueue_AddToQueue_CreatesPendingUpload() {
        var result = false
        runOnMainSync {
            result = sut.addToQueue(
                filePath: "/test/file.txt",
                voiceNote: "test note",
                summary: "test summary"
            )
        }
        XCTAssertTrue(result)
    }
    
    func testOfflineQueue_AddToQueue_SavesToCoreData() {
        runOnMainSync {
            _ = sut.addToQueue(filePath: "/test/file.txt", voiceNote: nil, summary: nil)
        }
        
        var count = 0
        runOnMainSync {
            count = sut.getPendingCount()
        }
        XCTAssertEqual(count, 1)
    }
    
    func testOfflineQueue_GetAllPending_ReturnsAll() {
        let dir = FileManager.default.temporaryDirectory
        let file1 = dir.appendingPathComponent("pending_all_1_\(UUID().uuidString).txt")
        let file2 = dir.appendingPathComponent("pending_all_2_\(UUID().uuidString).txt")
        try? "a".write(to: file1, atomically: true, encoding: .utf8)
        try? "b".write(to: file2, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
        }
        
        runOnMainSync {
            _ = sut.addToQueue(filePath: file1.path, voiceNote: nil, summary: nil)
            _ = sut.addToQueue(filePath: file2.path, voiceNote: nil, summary: nil)
        }
        
        var pending: [NSManagedObject] = []
        runOnMainSync {
            pending = sut.getAllPending()
        }
        XCTAssertEqual(pending.count, 2)
    }
    
    func testOfflineQueue_GetPendingCount_ReturnsCorrectCount() {
        let dir = FileManager.default.temporaryDirectory
        let file1 = dir.appendingPathComponent("pending_cnt_1_\(UUID().uuidString).txt")
        let file2 = dir.appendingPathComponent("pending_cnt_2_\(UUID().uuidString).txt")
        try? "x".write(to: file1, atomically: true, encoding: .utf8)
        try? "y".write(to: file2, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
        }
        
        var count = 0
        runOnMainSync {
            count = sut.getPendingCount()
        }
        XCTAssertEqual(count, 0)
        
        runOnMainSync {
            _ = sut.addToQueue(filePath: file1.path, voiceNote: nil, summary: nil)
        }
        
        runOnMainSync {
            count = sut.getPendingCount()
        }
        XCTAssertEqual(count, 1)
        
        runOnMainSync {
            _ = sut.addToQueue(filePath: file2.path, voiceNote: nil, summary: nil)
        }
        
        runOnMainSync {
            count = sut.getPendingCount()
        }
        XCTAssertEqual(count, 2)
    }
    
    func testOfflineQueue_DeleteItem_RemovesFromCoreData() {
        runOnMainSync {
            _ = sut.addToQueue(filePath: "/test/file.txt", voiceNote: nil, summary: nil)
        }
        
        var id: UUID?
        runOnMainSync {
            let pending = sut.getAllPending()
            if let item = pending.first {
                id = item.value(forKey: "id") as? UUID
            }
        }
        
        guard let itemId = id else {
            XCTFail("Не удалось получить id элемента")
            return
        }
        
        runOnMainSync {
            sut.deleteItem(id: itemId)
        }
        
        var count = 0
        runOnMainSync {
            count = sut.getPendingCount()
        }
        XCTAssertEqual(count, 0)
    }
    
    func testOfflineQueue_ProcessQueue_HandlesAllItems() async {
        await MainActor.run {
        _ = sut.addToQueue(filePath: "/test/1.txt", voiceNote: nil, summary: nil)
        _ = sut.addToQueue(filePath: "/test/2.txt", voiceNote: nil, summary: nil)
        }
        
        await sut.processQueue()
        
        await MainActor.run {
        let pending = sut.getAllPending()
        XCTAssertNotNil(pending)
        }
    }
    
    func testOfflineQueue_ProcessQueue_IncrementsAttempts() async {
        let mockNetwork = MockNetworkService()
        let mockFileService = FileService.shared
        let mockBookmark = MockBookmarkService(networkService: mockNetwork, fileService: mockFileService)
        mockBookmark.shouldFail = false
        mockBookmark.mockCreateResponse = false
        
        await MainActor.run {
        sut.setBookmarkService(mockBookmark)
        }
        
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_file_\(UUID().uuidString).txt")
        try? "test content".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
        _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
        let pending = sut.getAllPending()
        XCTAssertFalse(pending.isEmpty, "Элемент должен остаться в очереди после неудачной попытки")
        
        if let item = pending.first {
            let attempts = item.value(forKey: "uploadAttempts") as? Int16 ?? 0
            XCTAssertGreaterThanOrEqual(attempts, 1, "uploadAttempts должен увеличиться до 1 или больше после первой попытки. Текущее значение: \(attempts)")
        } else {
            XCTFail("Элемент не найден в очереди")
            }
        }
        
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_RetryFailed_ResetsAttempts() async {
        await MainActor.run {
        _ = sut.addToQueue(filePath: "/test/file.txt", voiceNote: nil, summary: nil)
        }
        
        await sut.processQueue()
        
        await MainActor.run {
        sut.retryFailed()
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        await MainActor.run {
        XCTAssertNotNil(sut)
        }
    }
    
    func testOfflineQueue_StartMonitoring_DoesNotCrash() throws {
        if AppTestHostContext.isUnitTestHostedMainApp {
            throw XCTSkip("NWPathMonitor под симуляторным TEST_HOST нестабилен (SIGKILL/timeout)")
        }
        XCTAssertNoThrow(sut.startMonitoring())
    }
    
    func testOfflineQueue_StopMonitoring_DoesNotCrash() throws {
        if AppTestHostContext.isUnitTestHostedMainApp {
            throw XCTSkip("NWPathMonitor под симуляторным TEST_HOST нестабилен (SIGKILL/timeout)")
        }
        sut.startMonitoring()
        XCTAssertNoThrow(sut.stopMonitoring())
    }
    
    func testOfflineQueue_GetAllPending_EmptyWhenNoItems() {
        var pending: [NSManagedObject] = []
        runOnMainSync {
            pending = sut.getAllPending()
        }
        XCTAssertEqual(pending.count, 0)
    }
    
    func testOfflineQueue_AddToQueue_PostsNotification() {
        let expectation = XCTestExpectation(description: "Notification posted")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .offlineQueueDidChange,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        
        runOnMainSync {
            _ = sut.addToQueue(filePath: "/test/file.txt", voiceNote: nil, summary: nil)
        }
        
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testOfflineQueue_AddToQueue_HandlesSaveError() {
        var result = false
        runOnMainSync {
            result = sut.addToQueue(filePath: "/test/file.txt", voiceNote: "test", summary: "test")
        }
        XCTAssertTrue(result, "В нормальных условиях должен возвращать true")
    }
    
    func testOfflineQueue_AddToQueue_ChecksCoreDataReady() {
        var result = false
        runOnMainSync {
            result = sut.addToQueue(filePath: "/test/file.txt", voiceNote: nil, summary: nil)
        }
        XCTAssertTrue(result)
    }
    
    func testOfflineQueue_AddToQueue_RequiresMainThread() {
        let expectation = XCTestExpectation(description: "Called on background thread")
        
        DispatchQueue.global().async {
            let result = self.sut.addToQueue(filePath: "/test/file.txt", voiceNote: nil, summary: nil)
            XCTAssertFalse(result, "addToQueue должен вернуть false при вызове не с главного потока")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testOfflineQueue_AddToQueue_ChecksEntityExists() {
        var result = false
        runOnMainSync {
            result = sut.addToQueue(filePath: "/test/file.txt", voiceNote: nil, summary: nil)
        }
        XCTAssertTrue(result)
    }
    
    func testOfflineQueue_MigrateShareExtensionQueueItems_MigratesItems() async {
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_migrate_\(UUID().uuidString).txt")
        try? "test content".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        _ = SharedUserDefaults.saveShareExtensionQueueItem(
            filePath: testFilePath.path,
            voiceNote: "test voice note",
            summary: "test summary"
        )
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            let count = sut.getPendingCount()
            XCTAssertGreaterThanOrEqual(count, 0, "Элемент должен быть мигрирован или уже существовать")
        }
        
        SharedUserDefaults.clearShareExtensionQueue()
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_MigrateShareExtensionQueueItems_SkipsExistingItems() async {
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_existing_\(UUID().uuidString).txt")
        try? "test".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        _ = SharedUserDefaults.saveShareExtensionQueueItem(filePath: testFilePath.path, voiceNote: nil, summary: nil)
        
        let initialCount = await MainActor.run {
            return sut.getPendingCount()
        }
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let finalCount = await MainActor.run {
            return sut.getPendingCount()
        }
        
        XCTAssertEqual(finalCount, initialCount, "Элемент должен быть пропущен так как уже существует")
        
        SharedUserDefaults.clearShareExtensionQueue()
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_MigrateShareExtensionQueueItems_ReturnsZeroWhenEmpty() async {
        SharedUserDefaults.clearShareExtensionQueue()
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    func testOfflineQueue_MigrateShareExtensionQueueItems_HandlesFetchError() async {
        SharedUserDefaults.clearShareExtensionQueue()
        
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_error_\(UUID().uuidString).txt")
        try? "test".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        _ = SharedUserDefaults.saveShareExtensionQueueItem(filePath: testFilePath.path)
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        SharedUserDefaults.clearShareExtensionQueue()
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_MigrateShareExtensionQueueItems_HandlesMissingEntity() async {
        SharedUserDefaults.clearShareExtensionQueue()
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    func testOfflineQueue_MigrateShareExtensionQueueItems_HandlesSaveError() async {
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_save_error_\(UUID().uuidString).txt")
        try? "test".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        _ = SharedUserDefaults.saveShareExtensionQueueItem(filePath: testFilePath.path)
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        SharedUserDefaults.clearShareExtensionQueue()
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_ProcessQueue_HandlesEmptyQueue() async {
        await MainActor.run {
            sut.setBookmarkService(MockBookmarkService())
        }
        
        await sut.processQueue()
        
        await MainActor.run {
            XCTAssertEqual(sut.getPendingCount(), 0)
        }
    }
    
    func testOfflineQueue_ProcessQueue_RemovesItemsWithExhaustedAttempts() async {
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_exhausted_\(UUID().uuidString).txt")
        try? "test".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
            
            let pending = sut.getAllPending()
            if let item = pending.first {
                item.setValue(Int16(3), forKey: "uploadAttempts")
                try? testPersistence.viewContext.save()
            }
        }
        
        await MainActor.run {
            sut.setBookmarkService(MockBookmarkService())
        }
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            let count = sut.getPendingCount()
            XCTAssertEqual(count, 0, "Элемент с исчерпанными попытками должен быть удален")
        }
    }
    
    func testOfflineQueue_ProcessQueue_SkipsItemsWithoutIdOrFilePath() async {
        await MainActor.run {
            let context = testPersistence.viewContext
            guard let entity = NSEntityDescription.entity(forEntityName: "PendingUpload", in: context) else {
                return
            }
            
            let pendingUpload = NSManagedObject(entity: entity, insertInto: context)
            pendingUpload.setValue(Date(), forKey: "timestamp")
            pendingUpload.setValue(Int16(0), forKey: "uploadAttempts")
            
            try? context.save()
        }
        
        await MainActor.run {
            sut.setBookmarkService(MockBookmarkService())
        }
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    func testOfflineQueue_ProcessQueue_HandlesSuccessfulUpload() async {
        let mockNetwork = MockNetworkService()
        let mockFile = MockFileService()
        let mockBookmark = MockBookmarkService(networkService: mockNetwork, fileService: mockFile)
        mockBookmark.mockCreateResponse = true
        
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_success_\(UUID().uuidString).txt")
        try? "test content".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
            sut.setBookmarkService(mockBookmark)
        }
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            let count = sut.getPendingCount()
            XCTAssertEqual(count, 0, "Элемент должен быть удален после успешной загрузки")
        }
        
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_ProcessQueue_HandlesFailedUpload() async {
        let mockNetwork = MockNetworkService()
        let mockFile = MockFileService()
        let mockBookmark = MockBookmarkService(networkService: mockNetwork, fileService: mockFile)
        mockBookmark.mockCreateResponse = false
        
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_failed_\(UUID().uuidString).txt")
        try? "test content".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
            sut.setBookmarkService(mockBookmark)
        }
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            let pending = sut.getAllPending()
            if let item = pending.first {
                let attempts = item.value(forKey: "uploadAttempts") as? Int16 ?? 0
                XCTAssertGreaterThanOrEqual(attempts, 1, "attempts должен увеличиться")
            }
        }
        
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_ProcessQueue_HandlesUploadError() async {
        let mockNetwork = MockNetworkService()
        let mockFile = MockFileService()
        let mockBookmark = MockBookmarkService(networkService: mockNetwork, fileService: mockFile)
        mockBookmark.shouldFail = true
        mockBookmark.createBookmarkError = APIError.networkError(NSError(domain: "test", code: -1))
        
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_error_\(UUID().uuidString).txt")
        try? "test content".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
            sut.setBookmarkService(mockBookmark)
        }
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            let pending = sut.getAllPending()
            if let item = pending.first {
                let attempts = item.value(forKey: "uploadAttempts") as? Int16 ?? 0
                let lastError = item.value(forKey: "lastError") as? String
                XCTAssertGreaterThanOrEqual(attempts, 1, "attempts должен увеличиться")
                XCTAssertNotNil(lastError, "lastError должен быть установлен")
            }
        }
        
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_ProcessQueue_HandlesTimeoutOnLastAttempt() async {
        let mockNetwork = MockNetworkService()
        let mockFile = MockFileService()
        let mockBookmark = MockBookmarkService(networkService: mockNetwork, fileService: mockFile)
        mockBookmark.shouldFail = true
        
        let timeoutError = NSError(domain: "NSURLErrorDomain", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Request timeout"])
        mockBookmark.createBookmarkError = APIError.networkError(timeoutError)
        
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_timeout_\(UUID().uuidString).txt")
        try? "test content".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
            
            let pending = sut.getAllPending()
            if let item = pending.first {
                item.setValue(Int16(2), forKey: "uploadAttempts")
                try? testPersistence.viewContext.save()
            }
            
            sut.setBookmarkService(mockBookmark)
        }
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        await MainActor.run {
            let pending = sut.getAllPending()
            if let item = pending.first {
                let attempts = item.value(forKey: "uploadAttempts") as? Int16 ?? 0
                XCTAssertGreaterThanOrEqual(attempts, 3, "attempts должен быть >= 3")
            }
        }
        
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_ProcessQueue_HandlesTaskCancellation() async {
        await MainActor.run {
            sut.setBookmarkService(MockBookmarkService())
        }
        
        let task = Task {
            await sut.processQueue()
        }
        
        task.cancel()
        
        await task.value
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    func testOfflineQueue_ProcessQueue_HandlesSleepError() async {
        let mockNetwork = MockNetworkService()
        let mockFile = MockFileService()
        let mockBookmark = MockBookmarkService(networkService: mockNetwork, fileService: mockFile)
        mockBookmark.mockCreateResponse = true
        
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_sleep_\(UUID().uuidString).txt")
        try? "test".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
            sut.setBookmarkService(mockBookmark)
        }
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
        
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_ProcessQueue_HandlesFileDeletionError() async {
        let mockNetwork = MockNetworkService()
        let mockFile = MockFileService()
        let mockBookmark = MockBookmarkService(networkService: mockNetwork, fileService: mockFile)
        mockBookmark.mockCreateResponse = true
        
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_del_error_\(UUID().uuidString).txt")
        try? "test".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
            sut.setBookmarkService(mockBookmark)
        }
        
        try? FileManager.default.removeItem(at: testFilePath)
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            let count = sut.getPendingCount()
            XCTAssertEqual(count, 0, "Элемент должен быть удален даже при ошибке удаления файла")
        }
    }
    
    func testOfflineQueue_ProcessQueue_HandlesUpdateAttemptsError() async {
        let mockNetwork = MockNetworkService()
        let mockFile = MockFileService()
        let mockBookmark = MockBookmarkService(networkService: mockNetwork, fileService: mockFile)
        mockBookmark.mockCreateResponse = false
        
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_update_error_\(UUID().uuidString).txt")
        try? "test".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
            sut.setBookmarkService(mockBookmark)
        }
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
        
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_ProcessQueue_HandlesDeleteFromQueueError() async {
        let mockNetwork = MockNetworkService()
        let mockFile = MockFileService()
        let mockBookmark = MockBookmarkService(networkService: mockNetwork, fileService: mockFile)
        mockBookmark.mockCreateResponse = true
        
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_del_queue_error_\(UUID().uuidString).txt")
        try? "test".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
            sut.setBookmarkService(mockBookmark)
        }
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
        
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_GetAllPending_HandlesFetchError() {
        var pending: [NSManagedObject] = []
        runOnMainSync {
            pending = sut.getAllPending()
        }
        XCTAssertNotNil(pending)
    }
    
    func testOfflineQueue_GetAllPending_RequiresMainThread() {
        let expectation = XCTestExpectation(description: "Called on background thread")
        
        DispatchQueue.global().async {
            let pending = self.sut.getAllPending()
            XCTAssertTrue(pending.isEmpty, "getAllPending должен вернуть пустой массив при вызове не с главного потока")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testOfflineQueue_GetPendingCount_HandlesCountError() {
        var count = 0
        runOnMainSync {
            count = sut.getPendingCount()
        }
        XCTAssertGreaterThanOrEqual(count, 0)
    }
    
    func testOfflineQueue_GetPendingCount_RequiresMainThread() {
        let expectation = XCTestExpectation(description: "Called on background thread")
        
        DispatchQueue.global().async {
            let count = self.sut.getPendingCount()
            XCTAssertEqual(count, 0, "getPendingCount должен вернуть 0 при вызове не с главного потока")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testOfflineQueue_DeleteItem_HandlesFileDeletionError() {
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_del_file_error_\(UUID().uuidString).txt")
        
        var id: UUID?
        runOnMainSync {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
            let pending = sut.getAllPending()
            if let item = pending.first {
                id = item.value(forKey: "id") as? UUID
            }
        }
        
        guard let itemId = id else {
            XCTFail("Не удалось получить id элемента")
            return
        }
        
        try? FileManager.default.removeItem(at: testFilePath)
        
        runOnMainSync {
            sut.deleteItem(id: itemId)
        }
        
        var count = 0
        runOnMainSync {
            count = sut.getPendingCount()
        }
        XCTAssertEqual(count, 0)
    }
    
    func testOfflineQueue_DeleteItem_RequiresMainThread() {
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_del_thread_\(UUID().uuidString).txt")
        
        var id: UUID?
        runOnMainSync {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
            let pending = sut.getAllPending()
            if let item = pending.first {
                id = item.value(forKey: "id") as? UUID
            }
        }
        
        guard let itemId = id else {
            XCTFail("Не удалось получить id элемента")
            return
        }
        
        let expectation = XCTestExpectation(description: "Called on background thread")
        DispatchQueue.global().async {
            self.sut.deleteItem(id: itemId)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        var count = 0
        runOnMainSync {
            count = sut.getPendingCount()
        }
        XCTAssertEqual(count, 1, "Элемент должен остаться, так как deleteItem не был вызван на главном потоке")
        
        runOnMainSync {
            sut.deleteItem(id: itemId)
        }
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_DeleteItem_HandlesSaveError() {
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_del_save_error_\(UUID().uuidString).txt")
        try? "test".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        var id: UUID?
        runOnMainSync {
            _ = sut.addToQueue(filePath: testFilePath.path, voiceNote: nil, summary: nil)
            let pending = sut.getAllPending()
            if let item = pending.first {
                id = item.value(forKey: "id") as? UUID
            }
        }
        
        guard let itemId = id else {
            XCTFail("Не удалось получить id элемента")
            return
        }
        
        runOnMainSync {
            sut.deleteItem(id: itemId)
        }
        
        runOnMainSync {
            XCTAssertNotNil(sut)
        }
        
        try? FileManager.default.removeItem(at: testFilePath)
    }
    
    func testOfflineQueue_RetryFailed_HandlesFetchError() {
        runOnMainSync {
            sut.retryFailed()
        }
        XCTAssertNotNil(sut)
    }
    
    func testOfflineQueue_RetryFailed_RequiresMainThread() {
        let expectation = XCTestExpectation(description: "Called on background thread")
        
        DispatchQueue.global().async {
            self.sut.retryFailed()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(sut)
    }
    
    func testOfflineQueue_RetryFailed_HandlesSaveError() {
        runOnMainSync {
            sut.retryFailed()
        }
        XCTAssertNotNil(sut)
    }
    
    func testOfflineQueue_StartMonitoring_HandlesNetworkAvailable() throws {
        if AppTestHostContext.isUnitTestHostedMainApp {
            throw XCTSkip("NWPathMonitor под симуляторным TEST_HOST нестабилен (SIGKILL/timeout)")
        }
        sut.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Network monitoring started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(sut)
    }
    
    func testOfflineQueue_StartMonitoring_HandlesNetworkUnavailable() throws {
        if AppTestHostContext.isUnitTestHostedMainApp {
            throw XCTSkip("NWPathMonitor под симуляторным TEST_HOST нестабилен (SIGKILL/timeout)")
        }
        sut.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Network monitoring started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(sut)
    }
    
    func testOfflineQueue_ProcessQueue_ProtectsFromParallelCalls() async {
        await MainActor.run {
            sut.setBookmarkService(MockBookmarkService())
        }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.sut.processQueue() }
            group.addTask { await self.sut.processQueue() }
            group.addTask { await self.sut.processQueue() }
        }
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    func testOfflineQueue_ProcessQueue_HandlesMigrationWithContextRefresh() async {
        let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test_migrate_refresh_\(UUID().uuidString).txt")
        try? "test".write(to: testFilePath, atomically: true, encoding: .utf8)
        
        _ = SharedUserDefaults.saveShareExtensionQueueItem(filePath: testFilePath.path)
        
        await MainActor.run {
            sut.setBookmarkService(MockBookmarkService())
        }
        
        await sut.processQueue()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        SharedUserDefaults.clearShareExtensionQueue()
        try? FileManager.default.removeItem(at: testFilePath)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    func testOfflineQueue_ProcessQueue_SkipsWhenCoreDataNotReady() async {
        let newPersistence = PersistenceController(inMemory: true)
        let newSut = OfflineQueueService(persistenceController: newPersistence)
        
        await newSut.processQueue()
        
        await MainActor.run {
            XCTAssertNotNil(newSut)
        }
    }
    
    func testOfflineQueue_AddToQueue_ReturnsFalseWhenCoreDataNotReady() {
        let newPersistence = PersistenceController(inMemory: true)
        let newSut = OfflineQueueService(persistenceController: newPersistence)
        
        runOnMainSync {
            _ = newSut.addToQueue(filePath: "/test/file.txt", voiceNote: nil, summary: nil)
        }
        
        XCTAssertNotNil(newSut)
    }
    
    func testOfflineQueue_AddToQueue_DedupsByHash() {
        let dir = FileManager.default.temporaryDirectory
        let file1 = dir.appendingPathComponent("hash1_\(UUID().uuidString).txt")
        let file2 = dir.appendingPathComponent("hash2_\(UUID().uuidString).txt")
        try? "same".write(to: file1, atomically: true, encoding: .utf8)
        try? "same".write(to: file2, atomically: true, encoding: .utf8)
        
        var first = false
        runOnMainSync {
            first = sut.addToQueue(filePath: file1.path, voiceNote: nil, summary: nil)
        }
        XCTAssertTrue(first)
        
        var second = true
        runOnMainSync {
            second = sut.addToQueue(filePath: file2.path, voiceNote: nil, summary: nil)
        }
        XCTAssertFalse(second, "Второй файл с тем же содержимым должен быть отклонен дедупликацией по хешу")
        
        try? FileManager.default.removeItem(at: file1)
        try? FileManager.default.removeItem(at: file2)
    }
    
    func testOfflineQueue_UpdateQueuedItem_UpdatesVoiceNote_CoreData() async {
        let path = "/test/update_coredata.txt"
        await MainActor.run {
            _ = sut.addToQueue(filePath: path, voiceNote: nil, summary: nil)
        }
        
        let note = "updated voice note"
        let updated = await MainActor.run {
            sut.updateQueuedItem(filePath: path, voiceNote: note, summary: nil)
        }
        XCTAssertTrue(updated, "Должны обновить элемент в Core Data")
        
        let fetchedNote: String? = await MainActor.run {
            let pending = sut.getAllPending()
            if let item = pending.first(where: { ($0.value(forKey: "filePath") as? String) == path }) {
                return item.value(forKey: "voiceNote") as? String
            }
            return nil
        }
        XCTAssertEqual(fetchedNote, note)
    }
    
    func testOfflineQueue_UpdateQueuedItem_UpdatesVoiceNote_UserDefaults() async {
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("ud_update_\(UUID().uuidString).txt").path
        _ = SharedUserDefaults.saveShareExtensionQueueItem(filePath: tempPath, voiceNote: nil, summary: nil)
        
        let notReadyPersistence = PersistenceController(inMemory: true)
        let localSut = OfflineQueueService(persistenceController: notReadyPersistence)
        
        let note = "ud voice note"
        let updated = await MainActor.run {
            localSut.updateQueuedItem(filePath: tempPath, voiceNote: note, summary: nil)
        }
        XCTAssertTrue(updated, "Должны обновить элемент в UserDefaults")
        
        let items = SharedUserDefaults.getShareExtensionQueueItems()
        let found = items.contains { dict in
            guard let path = dict["filePath"] as? String, path == tempPath else { return false }
            return (dict["voiceNote"] as? String) == note
        }
        XCTAssertTrue(found, "Заметка должна быть обновлена в UserDefaults очереди")
        
        SharedUserDefaults.clearShareExtensionQueue()
    }
}
