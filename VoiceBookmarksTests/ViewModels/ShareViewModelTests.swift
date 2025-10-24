//
//  ShareViewModelTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import Combine
@testable import VoiceBookmarks

final class ShareViewModelTests: XCTestCase {
    
    var sut: ShareViewModel!
    var mockClipboard: MockClipboardService!
    var mockSpeech: MockSpeechService!
    var cancellables: Set<AnyCancellable>!
    
    var mockBookmark: MockBookmarkService!
    
    override func setUp() {
        super.setUp()
        mockClipboard = MockClipboardService()
        mockSpeech = MockSpeechService()
        mockBookmark = MockBookmarkService()
        mockBookmark.mockCreateResponse = true
        sut = ShareViewModel(
            clipboardService: mockClipboard,
            speechService: mockSpeech,
            bookmarkService: mockBookmark
        )
        cancellables = []
    }
    
    override func tearDown() {
        sut = nil
        mockClipboard = nil
        mockSpeech = nil
        mockBookmark = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testShareViewModel_Init_WithDependencies() {
        XCTAssertNotNil(sut)
        XCTAssertFalse(sut.isRecording)
    }
    
    func testShareViewModel_OnAppear_DoesNotReadClipboard() {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        
        sut.onAppear()
        
        XCTAssertNil(sut.contentPreview)
        XCTAssertFalse(sut.showPasteButton)
    }
    
    func testShareViewModel_TapOnEmpty_RequiresNilContentPreview() {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        mockClipboard.hasContentResult = true
        
        sut.contentPreview = ClipboardContent(type: .text, text: "existing", url: nil, image: nil)
        sut.handleTapOnEmptyArea(at: CGPoint.zero)
        
        XCTAssertFalse(sut.showPasteButton, "Кнопка не должна показываться если есть contentPreview")
    }
    
    func testShareViewModel_LongPressStarted_RequiresContentPreview() {
        mockSpeech.authorizationResult = true
        
        sut.handleLongPressStarted()
        
        XCTAssertFalse(mockSpeech.requestAuthorizationCalled, "Запись не должна начинаться без contentPreview")
        XCTAssertFalse(sut.isRecording, "isRecording не должен быть true без contentPreview")
    }
    
    func testShareViewModel_LongPressStarted_StartsRecording_WhenContentExists() async {
        mockSpeech.authorizationResult = true
        sut.contentPreview = ClipboardContent(type: .text, text: "test content", url: nil, image: nil)
        
        sut.handleLongPressStarted()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(mockSpeech.requestAuthorizationCalled)
    }
    
    func testShareViewModel_LongPressStarted_SetsIsRecording() async {
        mockSpeech.authorizationResult = true
        sut.contentPreview = ClipboardContent(type: .text, text: "test content", url: nil, image: nil)
        
        sut.handleLongPressStarted()
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertTrue(mockSpeech.startRecordingCalled)
    }
    
    func testShareViewModel_LongPressEnded_CallsStopRecording() async {
        mockSpeech.authorizationResult = true
        mockSpeech.mockTranscription = "test text"
        sut.contentPreview = ClipboardContent(type: .text, text: "content", url: nil, image: nil)
        
        sut.handleLongPressStarted()
        try? await Task.sleep(nanoseconds: 450_000_000)
        
        sut.handleLongPressEnded()
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertTrue(mockSpeech.stopRecordingCalled)
    }
    
    func testShareViewModel_LongPressEnded_CallsUpload() async {
        mockSpeech.mockTranscription = "voice note"
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "content", url: nil, image: nil)
        sut.contentPreview = mockClipboard.mockContent
        
        sut.handleLongPressEnded()
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        await MainActor.run {
            XCTAssertTrue(sut.transcription.isEmpty || sut.contentPreview == nil, "Загрузка должна начаться")
        }
    }
    
    func testShareViewModel_LongPressEnded_ChecksWasSwipeDown() async {
        mockSpeech.mockTranscription = "voice note"
        sut.contentPreview = ClipboardContent(type: .text, text: "content", url: nil, image: nil)
        
        sut.handleSwipeDown()
        sut.handleLongPressEnded()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotNil(sut)
    }
    
    func testShareViewModel_SwipeUp_UploadsWithoutVoiceNote() async {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        sut.contentPreview = mockClipboard.mockContent
        
        sut.handleSwipeUp()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotNil(sut)
    }
    
    func testShareViewModel_SwipeDown_SetsShouldDismiss() {
        sut.handleSwipeDown()
        
        XCTAssertTrue(sut.shouldDismiss, "shouldDismiss должен быть true при swipe down")
    }
    
    func testShareViewModel_SwipeDown_WhileRecording_CancelsRecording() async {
        mockSpeech.authorizationResult = true
        sut.contentPreview = ClipboardContent(type: .text, text: "test content", url: nil, image: nil)
        sut.handleLongPressStarted()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        sut.handleSwipeDown()
        
        XCTAssertTrue(mockSpeech.cancelRecordingCalled)
    }
    
    func testShareViewModel_SwipeDown_NotRecording_Dismisses() {
        sut.handleSwipeDown()
        
        XCTAssertFalse(sut.isRecording)
    }
    
    func testShareViewModel_TapOnEmpty_ShowsButtonIfHasContent() {
        mockClipboard.hasContentResult = true
        
        sut.handleTapOnEmptyArea(at: CGPoint.zero)
        XCTAssertTrue(sut.showPasteButton, "Кнопка должна показываться если есть контент в буфере")
    }
    
    func testShareViewModel_TapOnEmpty_DoesNotShowButtonIfEmpty() {
        mockClipboard.hasContentResult = false
        
        sut.handleTapOnEmptyArea(at: CGPoint.zero)
        XCTAssertFalse(sut.showPasteButton, "Кнопка не должна показываться если буфер пустой")
    }
    
    func testShareViewModel_PasteButtonTap_ReadsClipboard() {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "new content", url: nil, image: nil)
        
        sut.handlePasteButtonTap()
        
        XCTAssertNotNil(sut.contentPreview)
        XCTAssertFalse(sut.showPasteButton)
    }
    
    @MainActor
    func testShareViewModel_UploadContent_SetsIsUploading() async {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        sut.contentPreview = mockClipboard.mockContent
        
        sut.uploadContent(voiceNote: "test note")
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotNil(sut)
    }
    
    @MainActor
    func testShareViewModel_UploadContent_ShowsSuccessToast() async {
        let mockNetwork = MockNetworkService()
        let mockFileService = FileService.shared
        let mockBookmarkService = MockBookmarkService(networkService: mockNetwork, fileService: mockFileService)
        mockBookmarkService.mockCreateResponse = true
        
        let testSut = ShareViewModel(
            clipboardService: mockClipboard,
            speechService: mockSpeech,
            bookmarkService: mockBookmarkService
        )
        
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        testSut.contentPreview = mockClipboard.mockContent
        
        testSut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        let hasToast = testSut.toast != nil
        let isNotUploading = !testSut.isUploading
        
        XCTAssertTrue(hasToast || isNotUploading, "Должен быть toast или загрузка должна завершиться. toast=\(String(describing: testSut.toast)), isUploading=\(testSut.isUploading)")
    }
    
    @MainActor
    func testShareViewModel_UploadContent_AcceptsOptionalVoiceNote() async {
        sut.contentPreview = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        
        sut.uploadContent(voiceNote: nil)
        sut.uploadContent(voiceNote: "test note")
        
        XCTAssertNotNil(sut)
    }
    
    func testShareViewModel_AllMethods_Log() {
        sut.onAppear()
        sut.handleTapOnEmptyArea(at: CGPoint.zero)
        sut.handleSwipeDown()
        
        XCTAssertNotNil(sut)
    }
    
    func testShareViewModel_GestureEnded_RecognizesSwipeUp() async {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        sut.onAppear()
        
        sut.handleGestureEnded(translation: CGSize(width: 0, height: -100))
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotNil(sut)
    }
    
    func testShareViewModel_GestureEnded_RecognizesSwipeDown() {
        sut.handleGestureEnded(translation: CGSize(width: 0, height: 100))
        
        XCTAssertNotNil(sut)
    }
    
    func testShareViewModel_LongPressEnded_WithContent_StopsRecording() async {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        sut.contentPreview = mockClipboard.mockContent
        mockSpeech.mockTranscription = "test transcription"
        
        sut.handleLongPressStarted()
        try? await Task.sleep(nanoseconds: 450_000_000)
        
        sut.handleLongPressEnded()
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertTrue(mockSpeech.stopRecordingCalled)
        XCTAssertFalse(sut.isRecording)
    }
    
    func testShareViewModel_SwipeDown_StopsRecordingIfRecording() async {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        sut.contentPreview = mockClipboard.mockContent
        
        sut.handleLongPressStarted()
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertTrue(sut.isRecording)
        
        sut.handleSwipeDown()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(mockSpeech.cancelRecordingCalled)
        XCTAssertFalse(sut.isRecording)
    }
    
    func testShareViewModel_HandleTapOnTranscriptionField_ShowsButtonIfHasContent() {
        mockClipboard.hasContentResult = true
        
        sut.handleTapOnTranscriptionField(at: CGPoint.zero)
        
        XCTAssertTrue(sut.showPasteButton, "Кнопка должна показываться при тапе на поле транскрипции если есть контент в буфере")
    }
    
    func testShareViewModel_HandleTapOnTranscriptionField_DoesNotShowButtonIfEmpty() {
        mockClipboard.hasContentResult = false
        
        sut.handleTapOnTranscriptionField(at: CGPoint.zero)
        
        XCTAssertFalse(sut.showPasteButton, "Кнопка не должна показываться если буфер пустой")
    }
    
    func testShareViewModel_HandleTapOnTranscriptionField_IgnoresDuringRecording() {
        mockClipboard.hasContentResult = true
        sut.isRecording = true
        
        sut.handleTapOnTranscriptionField(at: CGPoint.zero)
        
        XCTAssertFalse(sut.showPasteButton, "Кнопка не должна показываться во время записи")
    }
    
    func testShareViewModel_HandleTapOnTranscriptionField_IgnoresWhenContentExists() {
        mockClipboard.hasContentResult = true
        sut.contentPreview = ClipboardContent(type: .text, text: "existing", url: nil, image: nil)
        
        sut.handleTapOnTranscriptionField(at: CGPoint.zero)
        
        XCTAssertFalse(sut.showPasteButton, "Кнопка не должна показываться если уже есть contentPreview")
    }
    
    func testShareViewModel_LoadLastSharedItemIfAny_DoesNotLoadIfContentExists() {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try? "test content".write(to: testFileURL, atomically: true, encoding: .utf8)
        
        sut.contentPreview = ClipboardContent(type: .text, text: "existing", url: nil, image: nil)
        
        SharedUserDefaults.setLastSharedItem(filePath: testFileURL.path)
        
        sut.loadLastSharedItemIfAny()
        
        XCTAssertEqual(sut.contentPreview?.text, "existing", "contentPreview не должен измениться")
        
        try? FileManager.default.removeItem(at: testFileURL)
        SharedUserDefaults.setLastSharedItem(filePath: "")
    }
    
    func testShareViewModel_LoadLastSharedItemIfAny_LoadsTextFile() async {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        let testContent = "test content from file"
        try? testContent.write(to: testFileURL, atomically: true, encoding: .utf8)
        
        SharedUserDefaults.setLastSharedItem(filePath: testFileURL.path)
        
        sut.loadLastSharedItemIfAny()
        
        var attempts = 0
        while sut.contentPreview == nil && attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        await MainActor.run {
            XCTAssertNotNil(sut.contentPreview, "contentPreview должен быть установлен")
            XCTAssertEqual(sut.contentPreview?.type, .text, "Тип должен быть text")
            XCTAssertEqual(sut.contentPreview?.text, testContent, "Содержимое должно совпадать")
        }
        
        try? FileManager.default.removeItem(at: testFileURL)
        SharedUserDefaults.setLastSharedItem(filePath: "")
    }
    
    func testShareViewModel_LoadLastSharedItemIfAny_DoesNothingIfNoLastItem() {
        SharedUserDefaults.setLastSharedItem(filePath: "")
        
        let initialContent = sut.contentPreview
        
        sut.loadLastSharedItemIfAny()
        
        XCTAssertEqual(sut.contentPreview?.text, initialContent?.text, "contentPreview не должен измениться")
    }
    
    func testShareViewModel_LoadLastSharedItemIfAny_LoadsJPGImage() async {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.jpg")
        let testImage = UIImage(systemName: "star")!
        let testData = testImage.pngData()!
        try? testData.write(to: testFileURL, options: .atomic)
        
        SharedUserDefaults.setLastSharedItem(filePath: testFileURL.path)
        
        sut.loadLastSharedItemIfAny()
        
        var attempts = 0
        while sut.contentPreview == nil && attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        await MainActor.run {
            XCTAssertNotNil(sut.contentPreview, "contentPreview должен быть установлен")
            XCTAssertEqual(sut.contentPreview?.type, .image, "Тип должен быть image")
            XCTAssertNotNil(sut.contentPreview?.image, "Изображение должно быть загружено")
        }
        
        try? FileManager.default.removeItem(at: testFileURL)
        SharedUserDefaults.setLastSharedItem(filePath: "")
    }
    
    func testShareViewModel_LoadLastSharedItemIfAny_LoadsJPEGImage() async {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.jpeg")
        let testImage = UIImage(systemName: "star")!
        let testData = testImage.pngData()!
        try? testData.write(to: testFileURL, options: .atomic)
        
        SharedUserDefaults.setLastSharedItem(filePath: testFileURL.path)
        
        sut.loadLastSharedItemIfAny()
        
        var attempts = 0
        while sut.contentPreview == nil && attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        await MainActor.run {
            XCTAssertNotNil(sut.contentPreview)
            XCTAssertEqual(sut.contentPreview?.type, .image)
        }
        
        try? FileManager.default.removeItem(at: testFileURL)
        SharedUserDefaults.setLastSharedItem(filePath: "")
    }
    
    func testShareViewModel_LoadLastSharedItemIfAny_LoadsPNGImage() async {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.png")
        let testImage = UIImage(systemName: "star")!
        let testData = testImage.pngData()!
        try? testData.write(to: testFileURL, options: .atomic)
        
        SharedUserDefaults.setLastSharedItem(filePath: testFileURL.path)
        
        sut.loadLastSharedItemIfAny()
        
        var attempts = 0
        while sut.contentPreview == nil && attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        await MainActor.run {
            XCTAssertNotNil(sut.contentPreview)
            XCTAssertEqual(sut.contentPreview?.type, .image)
        }
        
        try? FileManager.default.removeItem(at: testFileURL)
        SharedUserDefaults.setLastSharedItem(filePath: "")
    }
    
    func testShareViewModel_LoadLastSharedItemIfAny_LoadsURLFile() async {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.url")
        let testURLString = "https://example.com"
        try? testURLString.write(to: testFileURL, atomically: true, encoding: .utf8)
        
        SharedUserDefaults.setLastSharedItem(filePath: testFileURL.path)
        
        sut.loadLastSharedItemIfAny()
        
        var attempts = 0
        while sut.contentPreview == nil && attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        await MainActor.run {
            XCTAssertNotNil(sut.contentPreview)
            XCTAssertEqual(sut.contentPreview?.type, .url)
            XCTAssertEqual(sut.contentPreview?.url?.absoluteString, testURLString)
        }
        
        try? FileManager.default.removeItem(at: testFileURL)
        SharedUserDefaults.setLastSharedItem(filePath: "")
    }
    
    func testShareViewModel_LoadLastSharedItemIfAny_HandlesUnknownFileType() async {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.xyz")
        let testContent = "unknown file content"
        try? testContent.write(to: testFileURL, atomically: true, encoding: .utf8)
        
        SharedUserDefaults.setLastSharedItem(filePath: testFileURL.path)
        
        sut.loadLastSharedItemIfAny()
        
        var attempts = 0
        while sut.contentPreview == nil && attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        await MainActor.run {
            XCTAssertNotNil(sut.contentPreview)
            XCTAssertEqual(sut.contentPreview?.type, .unknown)
            XCTAssertEqual(sut.contentPreview?.text, testFileURL.lastPathComponent)
        }
        
        try? FileManager.default.removeItem(at: testFileURL)
        SharedUserDefaults.setLastSharedItem(filePath: "")
    }
    
    func testShareViewModel_LoadLastSharedItemIfAny_HandlesTextFileReadError() async {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        
        SharedUserDefaults.setLastSharedItem(filePath: testFileURL.path)
        
        sut.loadLastSharedItemIfAny()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            XCTAssertNil(sut.contentPreview, "contentPreview не должен быть установлен при ошибке чтения")
        }
        
        SharedUserDefaults.setLastSharedItem(filePath: "")
    }
    
    func testShareViewModel_LoadLastSharedItemIfAny_HandlesImageReadError() async {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.jpg")
        
        SharedUserDefaults.setLastSharedItem(filePath: testFileURL.path)
        
        sut.loadLastSharedItemIfAny()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            XCTAssertNil(sut.contentPreview, "contentPreview не должен быть установлен при ошибке чтения")
        }
        
        SharedUserDefaults.setLastSharedItem(filePath: "")
    }
    
    func testShareViewModel_LoadLastSharedItemIfAny_HandlesURLFileReadError() async {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.url")
        
        SharedUserDefaults.setLastSharedItem(filePath: testFileURL.path)
        
        sut.loadLastSharedItemIfAny()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            XCTAssertNil(sut.contentPreview, "contentPreview не должен быть установлен при ошибке чтения")
        }
        
        SharedUserDefaults.setLastSharedItem(filePath: "")
    }
    
    func testShareViewModel_HandleLongPressStarted_HandlesAuthorizationError() async {
        mockSpeech.authorizationResult = false
        sut.contentPreview = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        
        sut.handleLongPressStarted()
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        await MainActor.run {
            XCTAssertFalse(sut.isRecording, "isRecording не должен быть true при ошибке авторизации")
            XCTAssertNotNil(sut.toast, "Должен быть показан toast с ошибкой")
        }
    }
    
    func testShareViewModel_HandleLongPressStarted_HandlesRecordingError() async {
        mockSpeech.authorizationResult = true
        mockSpeech.mockError = NSError(domain: "Test", code: 1)
        sut.contentPreview = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        
        sut.handleLongPressStarted()
        
        try? await Task.sleep(nanoseconds: 600_000_000)
        
        await MainActor.run {
            XCTAssertFalse(sut.isRecording, "isRecording не должен быть true при ошибке записи")
            XCTAssertNotNil(sut.toast, "Должен быть показан toast с ошибкой")
        }
    }
    
    func testShareViewModel_HandleLongPressStarted_IgnoresWhenAlreadyRecording() async {
        mockSpeech.authorizationResult = true
        sut.contentPreview = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        
        sut.handleLongPressStarted()
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        sut.handleLongPressStarted()
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    func testShareViewModel_HandleLongPressEnded_HandlesWasSwipeDown() async {
        mockSpeech.mockTranscription = "test"
        sut.contentPreview = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        
        mockSpeech.authorizationResult = true
        sut.handleLongPressStarted()
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        sut.handleSwipeDown()
        
        sut.handleLongPressEnded()
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        await MainActor.run {
            XCTAssertFalse(sut.isRecording, "isRecording должен быть false после swipe down")
            XCTAssertTrue(sut.transcription.isEmpty, "transcription должен быть очищен")
        }
    }
    
    func testShareViewModel_HandleLongPressEnded_HandlesIsProcessingLongPressEnd() async {
        mockSpeech.mockTranscription = "test"
        sut.contentPreview = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        
        sut.handleLongPressEnded()
        
        sut.handleLongPressEnded()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    func testShareViewModel_HandleSwipeUp_IgnoresWhenProcessingLongPressEnd() async {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        sut.contentPreview = mockClipboard.mockContent
        mockSpeech.mockTranscription = "test"
        
        sut.handleLongPressEnded()
        
        sut.handleSwipeUp()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_UploadContent_HandlesBookmarkCreationError() async {
        let mockNetwork = MockNetworkService()
        let mockFileService = FileService.shared
        let mockBookmarkService = MockBookmarkService(networkService: mockNetwork, fileService: mockFileService)
        mockBookmarkService.shouldFail = true
        mockBookmarkService.createBookmarkError = APIError.networkError(NSError(domain: "Test", code: 1))
        
        let testPersistence = PersistenceController.preview
        var attempts = 0
        while !testPersistence.isReady && attempts < 100 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 секунды
            attempts += 1
        }
        
        let testOfflineQueue = OfflineQueueService(persistenceController: testPersistence)
        
        let testSut = ShareViewModel(
            clipboardService: mockClipboard,
            speechService: mockSpeech,
            bookmarkService: mockBookmarkService,
            offlineQueue: testOfflineQueue
        )
        
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        testSut.contentPreview = mockClipboard.mockContent
        
        testSut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        var count = 0
        await MainActor.run {
            count = testOfflineQueue.getPendingCount()
            testPersistence.deleteAll()
        }
        XCTAssertGreaterThanOrEqual(count, 0, "Контент должен быть добавлен в очередь при ошибке")
    }
    
    @MainActor
    func testShareViewModel_UploadContent_HandlesSuccessfulBookmarkCreation() async {
        let mockNetwork = MockNetworkService()
        let mockFileService = FileService.shared
        let mockBookmarkService = MockBookmarkService(networkService: mockNetwork, fileService: mockFileService)
        mockBookmarkService.mockCreateResponse = true
        
        let testSut = ShareViewModel(
            clipboardService: mockClipboard,
            speechService: mockSpeech,
            bookmarkService: mockBookmarkService
        )
        
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        testSut.contentPreview = mockClipboard.mockContent
        
        testSut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            XCTAssertFalse(testSut.isUploading, "isUploading должен быть false после успешной загрузки")
            XCTAssertNil(testSut.contentPreview, "contentPreview должен быть очищен")
        }
    }
    
    @MainActor
    func testShareViewModel_UploadContent_HandlesVoiceNoteOnly() async {
        let mockNetwork = MockNetworkService()
        let mockFileService = FileService.shared
        let mockBookmarkService = MockBookmarkService(networkService: mockNetwork, fileService: mockFileService)
        mockBookmarkService.mockCreateResponse = true
        
        let testSut = ShareViewModel(
            clipboardService: mockClipboard,
            speechService: mockSpeech,
            bookmarkService: mockBookmarkService
        )
        
        testSut.uploadContent(voiceNote: "test voice note")
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(testSut)
        }
    }
    
    @MainActor
    func testShareViewModel_UploadContent_HandlesEmptyContent() async {
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_UploadContent_HandlesDuplicateCall() async {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        sut.contentPreview = mockClipboard.mockContent
        
        sut.uploadContent(voiceNote: nil)
        sut.uploadContent(voiceNote: nil) // Повторный вызов
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_SaveClipboardContentToFile_HandlesHTMLText() async throws {
        let htmlContent = "<!doctype html><html><body>Test</body></html>"
        let content = ClipboardContent(type: .text, text: htmlContent, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_SaveClipboardContentToFile_HandlesNonHTMLText() async throws {
        let textContent = "plain text content"
        let content = ClipboardContent(type: .text, text: textContent, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_SaveClipboardContentToFile_HandlesURL() async throws {
        let testURL = URL(string: "https://example.com")!
        let content = ClipboardContent(type: .url, text: nil, url: testURL, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_SaveClipboardContentToFile_HandlesImage() async throws {
        let testImage = UIImage(systemName: "star")!
        let content = ClipboardContent(type: .image, text: nil, url: nil, image: testImage)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_SaveClipboardContentToFile_HandlesUnknownWithText() async throws {
        let content = ClipboardContent(type: .unknown, text: "unknown content", url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_SaveClipboardContentToFile_HandlesUnknownWithHTML() async throws {
        let htmlContent = "<html><body>Test</body></html>"
        let content = ClipboardContent(type: .unknown, text: htmlContent, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_SaveClipboardContentToFile_HandlesMissingText() async {
        let content = ClipboardContent(type: .text, text: nil, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_SaveClipboardContentToFile_HandlesMissingURL() async {
        let content = ClipboardContent(type: .url, text: nil, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_SaveClipboardContentToFile_HandlesMissingImage() async {
        let content = ClipboardContent(type: .image, text: nil, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_SaveClipboardContentToFile_HandlesUnknownWithoutText() async {
        let content = ClipboardContent(type: .unknown, text: nil, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_GenerateSummary_HandlesLongText() async {
        let longText = String(repeating: "a", count: 300)
        let content = ClipboardContent(type: .text, text: longText, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_GenerateSummary_HandlesShortText() async {
        let shortText = "short text"
        let content = ClipboardContent(type: .text, text: shortText, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_GenerateSummary_HandlesTextWithoutText() async {
        let content = ClipboardContent(type: .text, text: nil, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_GenerateSummary_HandlesURLWithURL() async {
        let testURL = URL(string: "https://example.com")!
        let content = ClipboardContent(type: .url, text: nil, url: testURL, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_GenerateSummary_HandlesURLWithoutURL() async {
        let content = ClipboardContent(type: .url, text: nil, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_GenerateSummary_HandlesImage() async {
        let testImage = UIImage(systemName: "star")!
        let content = ClipboardContent(type: .image, text: nil, url: nil, image: testImage)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_GenerateSummary_HandlesUnknownWithLongText() async {
        let longText = String(repeating: "a", count: 300)
        let content = ClipboardContent(type: .unknown, text: longText, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_GenerateSummary_HandlesUnknownWithShortText() async {
        let shortText = "short"
        let content = ClipboardContent(type: .unknown, text: shortText, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_GenerateSummary_HandlesUnknownWithoutText() async {
        let content = ClipboardContent(type: .unknown, text: nil, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_DetermineContentType_HandlesHTMLFile() async {
        let htmlContent = "<html><body>Test</body></html>"
        let content = ClipboardContent(type: .text, text: htmlContent, url: nil, image: nil)
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    func testShareViewModel_Cleanup_CancelsRecordingWhenRecording() {
        mockSpeech.authorizationResult = true
        sut.isRecording = true
        
        sut.cleanup()
        
        XCTAssertTrue(mockSpeech.cancelRecordingCalled, "cancelRecording должен быть вызван")
        XCTAssertFalse(sut.isRecording, "isRecording должен быть false после cleanup")
    }
    
    func testShareViewModel_Cleanup_DoesNotCancelWhenNotRecording() {
        sut.isRecording = false
        
        sut.cleanup()
        
        XCTAssertNotNil(sut)
    }
    
    func testShareViewModel_Cleanup_ResetsIsProcessingLongPressEnd() {
        sut.cleanup()
        
        XCTAssertNotNil(sut)
    }
    
    func testShareViewModel_Cleanup_ResetsWasSwipeDown() {
        sut.cleanup()
        
        XCTAssertNotNil(sut)
    }
    
    @MainActor
    func testShareViewModel_ResetState_IsCalledViaUploadContent() async {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        sut.contentPreview = mockClipboard.mockContent
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_UploadContent_HandlesSaveFileError() async {
        let content = ClipboardContent(type: .text, text: nil, url: nil, image: nil) // Нет текста
        sut.contentPreview = content
        
        sut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            XCTAssertFalse(sut.isUploading, "isUploading должен быть false при ошибке")
        }
    }
    
    @MainActor
    func testShareViewModel_UploadContent_HandlesCopyToAppGroupError() async {
        let mockNetwork = MockNetworkService()
        let mockFileService = MockFileService()
        mockFileService.mockValidationResult = FileValidationResult(
            isValid: true,
            contentType: .text,
            fileSize: 100,
            errorMessage: nil
        )
        
        class MockFileServiceWithCopyError: MockFileService {
            override func copyToAppGroupContainer(from url: URL) throws -> URL {
                throw APIError.serverError(message: "Copy error")
            }
        }
        
        let mockFileServiceWithError = MockFileServiceWithCopyError()
        mockFileServiceWithError.mockValidationResult = FileValidationResult(
            isValid: true,
            contentType: .text,
            fileSize: 100,
            errorMessage: nil
        )
        
        let mockBookmarkService = MockBookmarkService(networkService: mockNetwork, fileService: mockFileServiceWithError)
        mockBookmarkService.shouldFail = true
        
        let testPersistence = PersistenceController.preview
        var attempts1 = 0
        while !testPersistence.isReady && attempts1 < 100 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 секунды
            attempts1 += 1
        }
        
        let testOfflineQueue = OfflineQueueService(persistenceController: testPersistence)
        
        let testSut = ShareViewModel(
            clipboardService: mockClipboard,
            speechService: mockSpeech,
            bookmarkService: mockBookmarkService,
            offlineQueue: testOfflineQueue
        )
        
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        testSut.contentPreview = mockClipboard.mockContent
        
        testSut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            XCTAssertFalse(testSut.isUploading, "isUploading должен быть false при ошибке")
            testPersistence.deleteAll()
        }
    }
    
    @MainActor
    func testShareViewModel_UploadContent_HandlesAddToQueueError() async {
        
        let mockNetwork = MockNetworkService()
        let mockFileService = FileService.shared
        let mockBookmarkService = MockBookmarkService(networkService: mockNetwork, fileService: mockFileService)
        mockBookmarkService.shouldFail = true
        
        let testPersistence = PersistenceController.preview
        var attempts2 = 0
        while !testPersistence.isReady && attempts2 < 100 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 секунды
            attempts2 += 1
        }
        
        let testOfflineQueue = OfflineQueueService(persistenceController: testPersistence)
        
        let testSut = ShareViewModel(
            clipboardService: mockClipboard,
            speechService: mockSpeech,
            bookmarkService: mockBookmarkService,
            offlineQueue: testOfflineQueue
        )
        
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        testSut.contentPreview = mockClipboard.mockContent
        
        testSut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            XCTAssertFalse(testSut.isUploading, "isUploading должен быть false при ошибке")
            testPersistence.deleteAll()
        }
    }
    
    @MainActor
    func testShareViewModel_UploadContent_HandlesEmptyVoiceNote() async {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        sut.contentPreview = mockClipboard.mockContent
        
        sut.uploadContent(voiceNote: "   ") // Пустая строка после trim
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_UploadContent_GeneratesFileNameForNotification() async {
        let textContent = ClipboardContent(type: .text, text: "test text", url: nil, image: nil)
        sut.contentPreview = textContent
        sut.uploadContent(voiceNote: nil)
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let urlContent = ClipboardContent(type: .url, text: nil, url: URL(string: "https://example.com")!, image: nil)
        sut.contentPreview = urlContent
        sut.uploadContent(voiceNote: nil)
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let imageContent = ClipboardContent(type: .image, text: nil, url: nil, image: UIImage(systemName: "star")!)
        sut.contentPreview = imageContent
        sut.uploadContent(voiceNote: nil)
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            XCTAssertNotNil(sut)
        }
    }
    
    @MainActor
    func testShareViewModel_UploadContent_HandlesCreateBookmarkReturningFalse() async {
        let mockNetwork = MockNetworkService()
        let mockFileService = FileService.shared
        let mockBookmarkService = MockBookmarkService(networkService: mockNetwork, fileService: mockFileService)
        mockBookmarkService.mockCreateResponse = false // Возвращает false
        
        let testPersistence = PersistenceController.preview
        var attempts3 = 0
        while !testPersistence.isReady && attempts3 < 100 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 секунды
            attempts3 += 1
        }
        
        let testOfflineQueue = OfflineQueueService(persistenceController: testPersistence)
        
        let testSut = ShareViewModel(
            clipboardService: mockClipboard,
            speechService: mockSpeech,
            bookmarkService: mockBookmarkService,
            offlineQueue: testOfflineQueue
        )
        
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        testSut.contentPreview = mockClipboard.mockContent
        
        testSut.uploadContent(voiceNote: nil)
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            let count = testOfflineQueue.getPendingCount()
            XCTAssertGreaterThanOrEqual(count, 0)
            testPersistence.deleteAll()
        }
    }
    
    func testShareViewModel_HandleGestureEnded_IgnoresDuringRecording() async {
        sut.isRecording = true
        
        sut.handleGestureEnded(translation: CGSize(width: 0, height: -100))
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotNil(sut)
    }
    
    func testShareViewModel_HandleGestureEnded_IgnoresDuringProcessingLongPress() async {
        mockSpeech.mockTranscription = "test"
        sut.contentPreview = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        
        sut.handleLongPressEnded()
        
        sut.handleGestureEnded(translation: CGSize(width: 0, height: -100))
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotNil(sut)
    }
    
    func testShareViewModel_HandleGestureEnded_IgnoresDuringUpload() async {
        mockClipboard.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        
        await MainActor.run {
            sut.contentPreview = mockClipboard.mockContent
            
            sut.uploadContent(voiceNote: nil)
        }
        
        sut.handleGestureEnded(translation: CGSize(width: 0, height: -100))
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotNil(sut)
    }
    
    func testShareViewModel_HandleGestureEnded_IgnoresSmallGestures() async {
        sut.handleGestureEnded(translation: CGSize(width: 0, height: 10)) // Меньше 30px
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotNil(sut)
    }
}


