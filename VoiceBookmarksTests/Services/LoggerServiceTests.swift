//
//  LoggerServiceTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class LoggerServiceTests: XCTestCase {
    
    var sut: LoggerService!
    
    override func setUp() {
        super.setUp()
        sut = LoggerService.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testLoggerService_Singleton_IsAccessible() {
        XCTAssertNotNil(LoggerService.shared)
    }
    
    func testLoggerService_Singleton_ReturnsSameInstance() {
        let instance1 = LoggerService.shared
        let instance2 = LoggerService.shared
        XCTAssertTrue(instance1 === instance2)
    }
    
    func testLoggerService_Debug_LogsSuccessfully() {
        XCTAssertNoThrow(sut.debug("Test debug message", category: .network))
    }
    
    func testLoggerService_Info_LogsSuccessfully() {
        XCTAssertNoThrow(sut.info("Test info message", category: .auth))
    }
    
    func testLoggerService_Warning_LogsSuccessfully() {
        XCTAssertNoThrow(sut.warning("Test warning message", category: .storage))
    }
    
    func testLoggerService_Error_LogsSuccessfully() {
        XCTAssertNoThrow(sut.error("Test error message", category: .speech))
    }
    
    func testLoggerService_Critical_LogsSuccessfully() {
        XCTAssertNoThrow(sut.critical("Test critical message", category: .ui))
    }

    func testLoggerService_LogNetworkRequest_LogsSuccessfully() {
        XCTAssertNoThrow(sut.logNetworkRequest(method: "GET", endpoint: "/api/test", category: .network))
    }
    
    func testLoggerService_AllCategories_Work() {
        let categories: [LoggerService.Category] = [
            .network, .auth, .storage, .speech, .ui, .lifecycle, .fileOperation, .offline, .webview
        ]
        
        for category in categories {
            XCTAssertNoThrow(sut.info("Test for \(category.rawValue)", category: category))
        }
    }
    
    func testLoggerService_Performance_HandlesMultipleLogs() {
        measure {
            for i in 0..<100 {
                sut.debug("Performance test message \(i)", category: .ui)
            }
        }
    }
    
    func testLoggerService_StressTest_HandlesLongMessages() {
        let longMessage = String(repeating: "A", count: 1000)
        XCTAssertNoThrow(sut.info(longMessage, category: .network))
    }
}
