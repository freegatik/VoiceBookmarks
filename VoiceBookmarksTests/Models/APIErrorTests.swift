//
//  APIErrorTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class APIErrorTests: XCTestCase {
    
    func testAPIError_NoData_ErrorDescription() {
        let error = APIError.noData
        XCTAssertEqual(error.errorDescription, "No data from server")
    }
    
    func testAPIError_Unauthorized_ErrorDescription() {
        let error = APIError.unauthorized
        XCTAssertEqual(error.errorDescription, "Authorization error")
    }
    
    func testAPIError_ServerError_ErrorDescription() {
        let message = "Internal server error"
        let error = APIError.serverError(message: message)
        XCTAssertEqual(error.errorDescription, "Server error: \(message)")
    }
    
    func testAPIError_HttpError_ErrorDescription() {
        let statusCode = 404
        let error = APIError.httpError(statusCode: statusCode)
        XCTAssertEqual(error.errorDescription, "HTTP error \(statusCode)")
    }
    
    func testAPIError_DecodingError_ErrorDescription() {
        let underlyingError = NSError(domain: "Test", code: 1)
        let error = APIError.decodingError(underlyingError)
        XCTAssertEqual(error.errorDescription, "JSON parsing error")
    }
    
    func testAPIError_NetworkError_ErrorDescription() {
        let underlyingError = NSError(domain: "Test", code: 1)
        let error = APIError.networkError(underlyingError)
        XCTAssertEqual(error.errorDescription, "Network error")
    }
    
    func testAPIError_ConformsToLocalizedError() {
        let error = APIError.noData
        XCTAssertNotNil(error.errorDescription)
    }
    
    func testAPIError_AllCases_HaveErrorDescription() {
        let errors: [APIError] = [
            .noData,
            .unauthorized,
            .serverError(message: "test"),
            .httpError(statusCode: 500),
            .decodingError(NSError(domain: "test", code: 1)),
            .networkError(NSError(domain: "test", code: 1))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have errorDescription")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "Error \(error) should have non-empty errorDescription")
        }
    }
}
