//
//  MockFileService.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import UIKit
@testable import VoiceBookmarks

class MockFileService: FileServiceProtocol {
    
    var mockValidationResult: FileValidationResult?
    var mockCompressedData: Data?
    var mockCompressedImage: Data?
    var validateFileCalled = false
    var compressImageCalled = false
    
    func validateFile(at url: URL) throws -> FileValidationResult {
        validateFileCalled = true
        
        if let result = mockValidationResult {
            return result
        }
        
        return FileValidationResult(
            isValid: true,
            contentType: .file,
            fileSize: 1000,
            errorMessage: nil
        )
    }
    
    func compressImage(_ image: UIImage) -> Data? {
        compressImageCalled = true
        return mockCompressedImage ?? mockCompressedData ?? Data([0x00, 0x01])
    }
    
    func compressVideo(at url: URL, completion: @escaping (URL?, Error?) -> Void) {
        completion(nil, nil)
    }
    
    func saveToTemporaryDirectory(data: Data, fileName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url, options: .atomic)
        return url
    }
    
    func copyToAppGroupContainer(from url: URL) throws -> URL {
        return url
    }
    
    func getFileSize(at url: URL) -> Int64? {
        return 1000
    }
    
    func deleteFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    func generateFileName(originalName: String, contentType: ContentType) -> String {
        return originalName
    }
}
