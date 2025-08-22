//
//  Constants.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import CoreGraphics

enum Constants {
    
    
    enum API {
        static let baseURL = "https://your-api-server.com"
        static let timeout: TimeInterval = 30
        static let retryCount = 3
        static let retryDelay: TimeInterval = 1
        
        enum Endpoints {
            static let auth = "/api/auth/anonymous"
            static let folders = "/api/folders"
            static let bookmarks = "/api/bookmarks"
            static let search = "/api/search"
            static let download = "/api/download"
            static func categoryBookmarks(category: String) -> String {
                return "/api/categories/\(category)/bookmarks"
            }
        }
        
        enum Headers {
            static let userID = "X-User-ID"
            static let contentType = "Content-Type"
            static let contentTypeJSON = "application/json"
            static let contentTypeMultipart = "multipart/form-data"
        }
    }
    
    
    enum Speech {
        static let locale = "ru-RU"
        static let timeoutNoSpeech: TimeInterval = 60
        static let timeoutNoSpeechForSearch: TimeInterval = 10
        static let timeoutNoSpeechForDictation: TimeInterval = 120
        static let maxDuration: TimeInterval = 300
        static let longPressDuration: TimeInterval = 0.5
    }
    
    
    enum Files {
        static let maxSizeMB = 500
        static let maxSizeBytes = maxSizeMB * 1024 * 1024
        static let compressionQuality: CGFloat = 0.7
    }
    
    
    enum UI {
        static let animationDuration: TimeInterval = 0.3
        static let toastDuration: TimeInterval = 4.0
        static let cardPadding: CGFloat = 16
        static let cardCornerRadius: CGFloat = 12
        static let iconSizeDefault: CGFloat = 40
        
        enum Colors {
            static let gold = "#FFD700"
            static let white = "#FFFFFF"
            static let black = "#000000"
            static let lightGray = "#F5F5F5"
        }
        
        enum IconSizes {
            static let text: CGFloat = 36
            static let audio: CGFloat = 40
            static let image: CGFloat = 44
            static let video: CGFloat = 48
            static let file: CGFloat = 40
        }
    }
    
    
    enum Keychain {
        static let userIdKey = "voice_bookmarks_user_id"
        static let service = "com.yourcompany.yourapp.keychain"
    }
    
    
    enum AppGroups {
        static let identifier = "group.com.yourcompany.yourapp"
        static let sharedDataKey = "shared_clipboard_data"
        static let userIdKey = "shared_user_id"
        static let shareTabFlagKey = "should_open_share_tab"
        static let openHostAttemptKey = "last_open_host_attempt"
    }
    
    
    enum CoreData {
        static let modelName = "VoiceBookmarks"
        static let containerName = "VoiceBookmarks"
    }
    
    
    enum Categories {
        static let all = ["SelfReflection", "Tasks", "ProjectResources", "Uncategorised"]
        static let defaultCategory = "Uncategorised"
    }
}

enum AppTestHostContext {
    static var isUnitTestHostedMainApp: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-UITESTS") { return false }
        if args.contains(where: { $0.hasPrefix("--UITest") }) { return false }
        
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil { return true }
        if env["XCTestBundlePath"] != nil { return true }
        
        return Bundle.allFrameworks.contains { fw in
            (fw.bundleIdentifier ?? "").localizedCaseInsensitiveContains("xctest")
        }
    }
}
