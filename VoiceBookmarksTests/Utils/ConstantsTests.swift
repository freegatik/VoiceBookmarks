//
//  ConstantsTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class ConstantsTests: XCTestCase {
    
    func testConstants_API_BaseURL() {
        XCTAssertEqual(Constants.API.baseURL, "https://minds.myapp.fund/weaviate")
    }
    
    func testConstants_API_Timeout() {
        XCTAssertEqual(Constants.API.timeout, 30.0)
    }
    
    func testConstants_API_RetryCount() {
        XCTAssertEqual(Constants.API.retryCount, 3)
    }
    
    func testConstants_API_RetryDelay() {
        XCTAssertEqual(Constants.API.retryDelay, 1.0)
    }
    
    func testConstants_API_Endpoints_Auth() {
        XCTAssertEqual(Constants.API.Endpoints.auth, "/api/auth/anonymous")
    }
    
    func testConstants_API_Endpoints_Folders() {
        XCTAssertEqual(Constants.API.Endpoints.folders, "/api/folders")
    }
    
    func testConstants_API_Endpoints_Bookmarks() {
        XCTAssertEqual(Constants.API.Endpoints.bookmarks, "/api/bookmarks")
    }
    
    func testConstants_API_Endpoints_Search() {
        XCTAssertEqual(Constants.API.Endpoints.search, "/api/search")
    }
    
    func testConstants_API_Endpoints_Download() {
        XCTAssertEqual(Constants.API.Endpoints.download, "/api/download")
    }
    
    func testConstants_API_Endpoints_CategoryBookmarks() {
        let category = "SelfReflection"
        let expected = "/api/categories/\(category)/bookmarks"
        XCTAssertEqual(Constants.API.Endpoints.categoryBookmarks(category: category), expected)
    }
    
    func testConstants_API_Headers_UserID() {
        XCTAssertEqual(Constants.API.Headers.userID, "X-User-ID")
    }
    
    func testConstants_API_Headers_ContentType() {
        XCTAssertEqual(Constants.API.Headers.contentType, "Content-Type")
    }
    
    func testConstants_API_Headers_ContentTypeJSON() {
        XCTAssertEqual(Constants.API.Headers.contentTypeJSON, "application/json")
    }
    
    func testConstants_API_Headers_ContentTypeMultipart() {
        XCTAssertEqual(Constants.API.Headers.contentTypeMultipart, "multipart/form-data")
    }
    
    func testConstants_Speech_Locale() {
        XCTAssertEqual(Constants.Speech.locale, "ru-RU")
    }
    
    func testConstants_Speech_TimeoutNoSpeech() {
        XCTAssertEqual(Constants.Speech.timeoutNoSpeech, 60.0)
    }
    
    func testConstants_Speech_MaxDuration() {
        XCTAssertEqual(Constants.Speech.maxDuration, 300.0)
    }
    
    func testConstants_Speech_LongPressDuration() {
        XCTAssertEqual(Constants.Speech.longPressDuration, 0.5)
    }
    
    func testConstants_Files_MaxSizeMB() {
        XCTAssertEqual(Constants.Files.maxSizeMB, 500)
    }
    
    func testConstants_Files_MaxSizeBytes() {
        let expected = 500 * 1024 * 1024
        XCTAssertEqual(Constants.Files.maxSizeBytes, expected)
    }
    
    func testConstants_Files_CompressionQuality() {
        XCTAssertEqual(Constants.Files.compressionQuality, 0.7)
    }
    
    func testConstants_UI_AnimationDuration() {
        XCTAssertEqual(Constants.UI.animationDuration, 0.3)
    }
    
    func testConstants_UI_ToastDuration() {
        XCTAssertEqual(Constants.UI.toastDuration, 4.0)
    }
    
    func testConstants_UI_CardPadding() {
        XCTAssertEqual(Constants.UI.cardPadding, 16.0)
    }
    
    func testConstants_UI_CardCornerRadius() {
        XCTAssertEqual(Constants.UI.cardCornerRadius, 12.0)
    }
    
    func testConstants_UI_IconSizeDefault() {
        XCTAssertEqual(Constants.UI.iconSizeDefault, 40.0)
    }
    
    func testConstants_UI_Colors_Gold() {
        XCTAssertEqual(Constants.UI.Colors.gold, "#FFD700")
    }
    
    func testConstants_UI_Colors_White() {
        XCTAssertEqual(Constants.UI.Colors.white, "#FFFFFF")
    }
    
    func testConstants_UI_Colors_Black() {
        XCTAssertEqual(Constants.UI.Colors.black, "#000000")
    }
    
    func testConstants_UI_Colors_LightGray() {
        XCTAssertEqual(Constants.UI.Colors.lightGray, "#F5F5F5")
    }
    
    func testConstants_UI_IconSizes_Text() {
        XCTAssertEqual(Constants.UI.IconSizes.text, 36.0)
    }
    
    func testConstants_UI_IconSizes_Audio() {
        XCTAssertEqual(Constants.UI.IconSizes.audio, 40.0)
    }
    
    func testConstants_UI_IconSizes_Image() {
        XCTAssertEqual(Constants.UI.IconSizes.image, 44.0)
    }
    
    func testConstants_UI_IconSizes_Video() {
        XCTAssertEqual(Constants.UI.IconSizes.video, 48.0)
    }
    
    func testConstants_UI_IconSizes_File() {
        XCTAssertEqual(Constants.UI.IconSizes.file, 40.0)
    }
    
    func testConstants_Keychain_UserIdKey() {
        XCTAssertEqual(Constants.Keychain.userIdKey, "voice_bookmarks_user_id")
    }
    
    func testConstants_Keychain_Service() {
        XCTAssertEqual(Constants.Keychain.service, "com.yourcompany.yourapp.keychain")
    }
    
    func testConstants_AppGroups_Identifier() {
        XCTAssertEqual(Constants.AppGroups.identifier, "group.com.yourcompany.yourapp")
    }
    
    func testConstants_AppGroups_SharedDataKey() {
        XCTAssertEqual(Constants.AppGroups.sharedDataKey, "shared_clipboard_data")
    }
    
    func testConstants_AppGroups_UserIdKey() {
        XCTAssertEqual(Constants.AppGroups.userIdKey, "shared_user_id")
    }
    
    func testConstants_CoreData_ModelName() {
        XCTAssertEqual(Constants.CoreData.modelName, "VoiceBookmarks")
    }
    
    func testConstants_CoreData_ContainerName() {
        XCTAssertEqual(Constants.CoreData.containerName, "VoiceBookmarks")
    }
    
    func testConstants_Categories_All() {
        let expected = ["SelfReflection", "Tasks", "ProjectResources", "Uncategorised"]
        XCTAssertEqual(Constants.Categories.all, expected)
    }
    
    func testConstants_Categories_DefaultCategory() {
        XCTAssertEqual(Constants.Categories.defaultCategory, "Uncategorised")
    }
}
