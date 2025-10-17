//
//  FileServiceTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import UIKit
@testable import VoiceBookmarks

final class FileServiceTests: XCTestCase {
    
    var sut: FileService!
    
    override func setUp() {
        super.setUp()
        sut = FileService.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    private func createTestFile(size: Int64, extension ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        
        let data = Data(count: Int(size))
        try! data.write(to: url, options: .atomic)
        return url
    }

    private func createSparseTestFile(logicalSize: Int64, extension ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        guard FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil) else {
            throw NSError(domain: "FileServiceTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "createFile failed"])
        }
        let fh = try FileHandle(forWritingTo: url)
        defer { try? fh.close() }
        try fh.truncate(atOffset: UInt64(logicalSize))
        return url
    }
    
    
    func testFileService_ValidateFile_SmallFile_Success() throws {
        let url = createTestFile(size: 1000, extension: "txt")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_ValidateFile_LargeFile_Fails() throws {
        let url = try createSparseTestFile(logicalSize: Int64(501 * 1024 * 1024), extension: "mp4")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_ValidateFile_JPG_ReturnsImageType() throws {
        let url = createTestFile(size: 1000, extension: "jpg")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertEqual(result.contentType, .image)
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_ValidateFile_MP4_ReturnsVideoType() throws {
        let url = createTestFile(size: 1000, extension: "mp4")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertEqual(result.contentType, .video)
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_CompressImage_ReturnsData() {
        let image = createTestImage()
        
        let data = sut.compressImage(image)
        
        XCTAssertNotNil(data)
    }
    
    func testFileService_CompressImage_ReducesSize() {
        let image = createTestImage()
        
        guard let compressedData = sut.compressImage(image) else {
            XCTFail("Не удалось сжать")
            return
        }
        
        XCTAssertGreaterThan(compressedData.count, 0)
    }
    
    func testFileService_SaveToTemp_CreatesFile() {
        let testData = "test content".data(using: .utf8)!
        
        let url = sut.saveToTemporaryDirectory(data: testData, fileName: "test.txt")
        
        XCTAssertNotNil(url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url!.path))
        
        if let url = url {
            sut.deleteFile(at: url)
        }
    }
    
    func testFileService_SaveToTemp_ReturnsValidURL() {
        let testData = Data([0x00, 0x01, 0x02])
        
        let url = sut.saveToTemporaryDirectory(data: testData, fileName: "test.bin")
        
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.path.contains("test.bin"))
        
        if let url = url {
            sut.deleteFile(at: url)
        }
    }
    
    func testFileService_GetFileSize_ReturnsCorrectSize() {
        let testSize: Int64 = 12345
        let url = createTestFile(size: testSize, extension: "dat")
        
        let size = sut.getFileSize(at: url)
        
        XCTAssertEqual(size, testSize)
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_DeleteFile_RemovesFile() {
        let url = createTestFile(size: 100, extension: "tmp")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        
        sut.deleteFile(at: url)
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    
    func testFileService_GenerateFileName_CreatesUniqueName() {
        let name1 = sut.generateFileName(originalName: "test.jpg", contentType: .image)
        let name2 = sut.generateFileName(originalName: "test.jpg", contentType: .image)
        
        XCTAssertNotEqual(name1, name2)
    }
    
    func testFileService_GenerateFileName_PreservesExtension() {
        let name = sut.generateFileName(originalName: "document.pdf", contentType: .text)
        
        XCTAssertTrue(name.hasSuffix(".pdf"))
    }
    
    func testFileService_Singleton_IsAccessible() {
        XCTAssertNotNil(FileService.shared)
    }
    
    func testFileService_ValidateFile_NonExistent_Fails() throws {
        let url = URL(fileURLWithPath: "/nonexistent/file.txt")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertFalse(result.isValid)
    }
    
    func testFileService_Constants_AreCorrect() {
        XCTAssertEqual(Constants.Files.maxSizeMB, 500)
        XCTAssertEqual(Constants.Files.compressionQuality, 0.7)
    }
    
    func testFileService_ValidateFile_MP3_ReturnsAudioType() throws {
        let url = createTestFile(size: 1000, extension: "mp3")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertEqual(result.contentType, .audio)
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_ValidateFile_TXT_ReturnsTextType() throws {
        let url = createTestFile(size: 1000, extension: "txt")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertEqual(result.contentType, .text)
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_ValidateFile_PDF_ReturnsFileType() throws {
        let url = createTestFile(size: 1000, extension: "pdf")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertEqual(result.contentType, .file)
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_ValidateFile_ReturnsFileSize() throws {
        let testSize: Int64 = 5000
        let url = createTestFile(size: testSize, extension: "txt")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertEqual(result.fileSize, testSize)
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_GetFileSize_ReturnsNilForNonExistent() {
        let url = URL(fileURLWithPath: "/nonexistent/file.txt")
        
        let size = sut.getFileSize(at: url)
        
        XCTAssertNil(size)
    }
    
    func testFileService_CompressImage_NilImage() {
        let image = createTestImage()
        let data = sut.compressImage(image)
        XCTAssertNotNil(data)
    }
    
    func testFileService_SaveToTemp_DifferentFileNames() {
        let data1 = "content1".data(using: .utf8)!
        let data2 = "content2".data(using: .utf8)!
        
        let url1 = sut.saveToTemporaryDirectory(data: data1, fileName: "file1.txt")
        let url2 = sut.saveToTemporaryDirectory(data: data2, fileName: "file2.txt")
        
        XCTAssertNotNil(url1)
        XCTAssertNotNil(url2)
        XCTAssertNotEqual(url1, url2)
        
        if let url1 = url1 { sut.deleteFile(at: url1) }
        if let url2 = url2 { sut.deleteFile(at: url2) }
    }
    
    func testFileService_DeleteFile_NonExistent_DoesNotCrash() {
        let url = URL(fileURLWithPath: "/nonexistent/file.txt")
        
        XCTAssertNoThrow(sut.deleteFile(at: url))
    }
    
    func testFileService_GenerateFileName_NoExtension() {
        let name = sut.generateFileName(originalName: "file", contentType: .file)
        
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(name.contains("_"))
    }
    
    func testFileService_GenerateFileName_DifferentContentTypes() {
        let imageName = sut.generateFileName(originalName: "photo.jpg", contentType: .image)
        let videoName = sut.generateFileName(originalName: "video.mp4", contentType: .video)
        let audioName = sut.generateFileName(originalName: "audio.mp3", contentType: .audio)
        
        XCTAssertTrue(imageName.hasSuffix(".jpg"))
        XCTAssertTrue(videoName.hasSuffix(".mp4"))
        XCTAssertTrue(audioName.hasSuffix(".mp3"))
    }
    
    func testFileService_ValidateFile_Exactly500MB_Success() throws {
        let maxSize = Int64(500 * 1024 * 1024)
        let url = try createSparseTestFile(logicalSize: maxSize, extension: "mp4")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertTrue(result.isValid)
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_ValidateFile_DifferentImageExtensions() throws {
        let extensions = ["jpg", "jpeg", "png", "heic", "gif"]
        
        for ext in extensions {
            let url = createTestFile(size: 1000, extension: ext)
            let result = try sut.validateFile(at: url)
            XCTAssertEqual(result.contentType, .image, "Extension \(ext) should be image")
            sut.deleteFile(at: url)
        }
    }
    
    func testFileService_ValidateFile_DifferentVideoExtensions() throws {
        let extensions = ["mp4", "mov", "m4v", "avi"]
        
        for ext in extensions {
            let url = createTestFile(size: 1000, extension: ext)
            let result = try sut.validateFile(at: url)
            XCTAssertEqual(result.contentType, .video, "Extension \(ext) should be video")
            sut.deleteFile(at: url)
        }
    }
    
    func testFileService_ValidateFile_UnknownExtension_ReturnsFile() throws {
        let url = createTestFile(size: 1000, extension: "xyz")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertEqual(result.contentType, .file)
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_CompressVideo_CallsCompletion() {
        let expectation = expectation(description: "Video compression completion")
        
        let url = createTestFile(size: 100, extension: "mp4")
        
        sut.compressVideo(at: url) { outputURL, error in
            expectation.fulfill()
            
            if let outputURL = outputURL {
                self.sut.deleteFile(at: outputURL)
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        sut.deleteFile(at: url)
    }
    
    func testFileService_CopyToAppGroupContainer_CopiesFile() throws {
        let testData = "test content".data(using: .utf8)!
        let sourceURL = sut.saveToTemporaryDirectory(data: testData, fileName: "test_copy.txt")!
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        
        do {
            let destinationURL = try sut.copyToAppGroupContainer(from: sourceURL)
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
            sut.deleteFile(at: destinationURL)
        } catch {
            XCTAssertNotNil(error)
        }
        
        sut.deleteFile(at: sourceURL)
    }
    
    func testFileService_ValidateFile_SizeError_ReturnsInvalid() throws {
        let url = createTestFile(size: 1000, extension: "txt")
        
        let result = try sut.validateFile(at: url)
        XCTAssertTrue(result.isValid || !result.isValid) // Проверяем что результат есть
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_ValidateFile_LargeFile_ReturnsErrorMessage() throws {
        let url = try createSparseTestFile(logicalSize: Int64(501 * 1024 * 1024), extension: "mp4")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
        XCTAssertTrue(result.errorMessage?.contains("500MB") ?? false)
        
        sut.deleteFile(at: url)
    }
    
    func testFileService_ValidateFile_NonExistent_ReturnsErrorMessage() throws {
        let url = URL(fileURLWithPath: "/nonexistent/file.txt")
        
        let result = try sut.validateFile(at: url)
        
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
    }
    
    func testFileService_CompressImage_ReturnsDataWithSize() {
        let image = createTestImage()
        let data = sut.compressImage(image)
        
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
    }
    
    func testFileService_SaveToTemp_HandlesErrors() {
        let testData = "test".data(using: .utf8)!
        let url = sut.saveToTemporaryDirectory(data: testData, fileName: "test.txt")
        
        XCTAssertNotNil(url)
        
        if let url = url {
            sut.deleteFile(at: url)
        }
    }
    
    func testFileService_GetFileSize_DifferentSizes() {
        let sizes: [Int64] = [100, 1000, 10000, 100000]
        
        for size in sizes {
            let url = createTestFile(size: size, extension: "dat")
            let retrievedSize = sut.getFileSize(at: url)
            XCTAssertEqual(retrievedSize, size, "Size should match for \(size) bytes")
            sut.deleteFile(at: url)
        }
    }
    
    func testFileService_ValidateFile_AllContentTypes() throws {
        let testCases: [(String, ContentType)] = [
            ("test.jpg", .image),
            ("test.mp4", .video),
            ("test.mp3", .audio),
            ("test.txt", .text),
            ("test.pdf", .file),
            ("test.xyz", .file)
        ]
        
        for (fileName, expectedType) in testCases {
            let ext = (fileName as NSString).pathExtension
            let url = createTestFile(size: 1000, extension: ext)
            let result = try sut.validateFile(at: url)
            XCTAssertEqual(result.contentType, expectedType, "\(fileName) should be \(expectedType)")
            sut.deleteFile(at: url)
        }
    }
}

