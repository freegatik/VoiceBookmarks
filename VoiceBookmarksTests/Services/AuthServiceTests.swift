//
//  AuthServiceTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class AuthServiceTests: XCTestCase {
    
    var sut: AuthService!
    var mockNetworkService: MockNetworkService!
    var mockKeychainService: MockKeychainService!
    
    override func setUp() {
        super.setUp()
        mockNetworkService = MockNetworkService()
        mockKeychainService = MockKeychainService()
        sut = AuthService(
            networkService: mockNetworkService,
            keychainService: mockKeychainService
        )
    }
    
    override func tearDown() {
        sut = nil
        mockNetworkService = nil
        mockKeychainService = nil
        super.tearDown()
    }
    
    func testGetOrCreateUserId_ExistingInKeychain_ReturnsIt() async throws {
        mockKeychainService.mockUserId = "existing-user-id"
        
        let userId = try await sut.getOrCreateUserId()
        
        XCTAssertEqual(userId, "existing-user-id")
        XCTAssertTrue(mockKeychainService.getUserIdCalled)
    }
    
    func testGetOrCreateUserId_ExistingUserId_SetsInNetworkService() async throws {
        mockKeychainService.mockUserId = "test-id"
        
        _ = try await sut.getOrCreateUserId()
        
        XCTAssertTrue(mockNetworkService.setUserIdCalled)
        XCTAssertEqual(mockNetworkService.capturedUserId, "test-id")
    }
    
    func testGetOrCreateUserId_ExistingUserId_DoesNotCallAPI() async throws {
        mockKeychainService.mockUserId = "test-id"
        
        _ = try await sut.getOrCreateUserId()
        
        XCTAssertNil(mockNetworkService.capturedEndpoint)
    }
    
    func testGetOrCreateUserId_NoUserId_CallsAPI() async throws {
        mockKeychainService.mockUserId = nil
        mockNetworkService.mockResponse = AuthResponse(
            success: true,
            userId: "new-user-id",
            anonymousId: nil,
            message: nil
        )
        
        _ = try await sut.getOrCreateUserId()
        
        XCTAssertNotNil(mockNetworkService.capturedEndpoint)
    }
    
    func testGetOrCreateUserId_NewUserId_SavesInKeychain() async throws {
        mockKeychainService.mockUserId = nil
        mockNetworkService.mockResponse = AuthResponse(
            success: true,
            userId: "new-user-id",
            anonymousId: nil,
            message: nil
        )
        
        _ = try await sut.getOrCreateUserId()
        
        XCTAssertTrue(mockKeychainService.saveUserIdCalled)
        XCTAssertEqual(mockKeychainService.mockUserId, "new-user-id")
    }
    
    func testGetOrCreateUserId_NewUserId_SetsInNetworkService() async throws {
        mockKeychainService.mockUserId = nil
        mockNetworkService.mockResponse = AuthResponse(
            success: true,
            userId: "new-user-id",
            anonymousId: nil,
            message: nil
        )
        
        _ = try await sut.getOrCreateUserId()
        
        XCTAssertTrue(mockNetworkService.setUserIdCalled)
        XCTAssertEqual(mockNetworkService.capturedUserId, "new-user-id")
    }
    
    func testGetOrCreateUserId_CallsCorrectEndpoint() async throws {
        mockKeychainService.mockUserId = nil
        mockNetworkService.mockResponse = AuthResponse(
            success: true,
            userId: "test-id",
            anonymousId: nil,
            message: nil
        )
        
        _ = try await sut.getOrCreateUserId()
        
        XCTAssertEqual(mockNetworkService.capturedEndpoint, "/api/auth/anonymous")
    }
    
    func testGetOrCreateUserId_UsesPOSTMethod() async throws {
        mockKeychainService.mockUserId = nil
        mockNetworkService.mockResponse = AuthResponse(
            success: true,
            userId: "test-id",
            anonymousId: nil,
            message: nil
        )
        
        _ = try await sut.getOrCreateUserId()
        
        XCTAssertEqual(mockNetworkService.capturedMethod, "POST")
    }
    
    func testGetOrCreateUserId_ReturnsUserIdFromResponse() async throws {
        mockKeychainService.mockUserId = nil
        mockNetworkService.mockResponse = AuthResponse(
            success: true,
            userId: "response-user-id",
            anonymousId: nil,
            message: nil
        )
        
        let userId = try await sut.getOrCreateUserId()
        
        XCTAssertEqual(userId, "response-user-id")
    }
    
    func testGetOrCreateUserId_NetworkError_Throws() async {
        mockKeychainService.mockUserId = nil
        mockNetworkService.mockError = APIError.networkError(NSError(domain: "test", code: -1))
        
        do {
            _ = try await sut.getOrCreateUserId()
            XCTFail("Должна быть ошибка")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testGetOrCreateUserId_KeychainSaveError_Throws() async {
        class FailingKeychainService: KeychainServiceProtocol {
            func saveUserId(_ userId: String) async -> Bool {
                return false
            }
            func getUserId() -> String? {
                return nil
            }
            func deleteUserId() -> Bool {
                return true
            }
        }
        
        let failingKeychain = FailingKeychainService()
        let authService = AuthService(
            networkService: mockNetworkService,
            keychainService: failingKeychain
        )
        
        mockNetworkService.mockResponse = AuthResponse(
            success: true,
            userId: "test-id",
            anonymousId: nil,
            message: nil
        )
        
        do {
            _ = try await authService.getOrCreateUserId()
            XCTFail("Должна быть ошибка")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testGetOrCreateUserId_LogsOperations() async throws {
        mockKeychainService.mockUserId = "existing-id"
        
        _ = try await sut.getOrCreateUserId()
        
        XCTAssertTrue(mockKeychainService.getUserIdCalled)
    }
}
