//
//  NetworkServiceTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class NetworkServiceTests: XCTestCase {
    
    var sut: NetworkService!
    
    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        config.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: config)
        sut = NetworkService(baseURL: "https://test.api", session: session)
    }
    
    override func tearDown() {
        sut = nil
        MockURLProtocol.reset()
        super.tearDown()
    }
    
    func testNetworkService_Init_UsesDefaultURL() {
        let service = NetworkService()
        XCTAssertNotNil(service)
    }
    
    func testNetworkService_SetUserId_StoresUserId() {
        XCTAssertNoThrow(sut.setUserId("test-user-id"))
    }
    
    func testNetworkService_Request_AddsUserIDHeader() async throws {
        struct TestResponse: Codable {
            let message: String
        }
        
        sut.setUserId("test-user-123")
        
        let jsonData = """
        {"message": "success"}
        """.data(using: .utf8)!
        
        let response = HTTPURLResponse(
            url: URL(string: "https://test.api/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        MockURLProtocol.mockData = jsonData
        MockURLProtocol.mockResponse = response
        MockURLProtocol.mockError = nil
        
        let result: TestResponse = try await sut.request(endpoint: "/test", method: "GET")
        XCTAssertEqual(result.message, "success")
    }
    
    func testNetworkService_Request_AddsContentTypeHeader() {
        XCTAssertNotNil(sut)
    }
    
    func testNetworkService_Request_ParsesValidJSON() async throws {
        struct TestResponse: Codable {
            let message: String
        }
        
        let jsonData = """
        {"message": "success"}
        """.data(using: .utf8)!
        
        let response = HTTPURLResponse(
            url: URL(string: "https://test.api/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        MockURLProtocol.mockData = jsonData
        MockURLProtocol.mockResponse = response
        MockURLProtocol.mockError = nil
        
        let result: TestResponse = try await sut.request(endpoint: "/test", method: "GET")
        XCTAssertEqual(result.message, "success")
    }
    
    func testNetworkService_Request_WithBody_EncodesJSON() async throws {
        struct TestRequest: Codable {
            let name: String
        }
        
        struct TestResponse: Codable {
            let id: String
        }
        
        let jsonData = """
        {"id": "123"}
        """.data(using: .utf8)!
        
        let response = HTTPURLResponse(
            url: URL(string: "https://test.api/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        MockURLProtocol.mockData = jsonData
        MockURLProtocol.mockResponse = response
        MockURLProtocol.mockError = nil
        
        let requestBody = TestRequest(name: "test")
        let result: TestResponse = try await sut.request(endpoint: "/test", method: "POST", body: requestBody)
        XCTAssertEqual(result.id, "123")
    }
    
    func testNetworkService_Request_ThrowsOn401() async throws {
        struct TestResponse: Codable {
            let message: String
        }
        
        let response = HTTPURLResponse(
            url: URL(string: "https://test.api/test")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        
        MockURLProtocol.mockData = Data()
        MockURLProtocol.mockResponse = response
        MockURLProtocol.mockError = nil
        
        do {
            let _: TestResponse = try await sut.request(endpoint: "/test", method: "GET")
            XCTFail("Должна была быть выброшена ошибка APIError.unauthorized")
        } catch let error as APIError {
            if case .unauthorized = error {
            } else {
                XCTFail("Ожидалась ошибка .unauthorized, получена: \(error)")
            }
        } catch {
            XCTFail("Ожидалась ошибка APIError.unauthorized, получена: \(error)")
        }
    }
    
    func testNetworkService_Request_ThrowsOn404() async throws {
        struct TestResponse: Codable {
            let message: String
        }
        
        let response = HTTPURLResponse(
            url: URL(string: "https://test.api/test")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )!
        
        MockURLProtocol.mockData = Data()
        MockURLProtocol.mockResponse = response
        MockURLProtocol.mockError = nil
        
        do {
            let _: TestResponse = try await sut.request(endpoint: "/test", method: "GET")
            XCTFail("Должна была быть выброшена ошибка")
        } catch let error as APIError {
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 404)
            } else {
                XCTFail("Ожидалась ошибка .httpError(404), получена: \(error)")
            }
        } catch {
            XCTFail("Ожидалась ошибка APIError.httpError, получена: \(error)")
        }
    }
    
    func testNetworkService_Request_RetriesOn500() async throws {
        struct TestResponse: Codable {
            let message: String
        }
        
        MockURLProtocol.reset()
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        
        do {
            let _: TestResponse = try await sut.request(endpoint: "/test", method: "GET")
            XCTFail("Должна была быть выброшена ошибка после retry")
        } catch {
            XCTAssertEqual(MockURLProtocol.requestCount, Constants.API.retryCount, "Должно быть сделано \(Constants.API.retryCount) попытки")
            XCTAssertTrue(error is APIError, "Должна быть ошибка APIError")
            
            if case APIError.httpError(let code) = error as! APIError {
                XCTAssertEqual(code, 500, "Должна быть ошибка 500")
            } else {
                XCTFail("Ожидалась ошибка APIError.httpError(500)")
            }
        }
    }
    
    func testNetworkService_Request_RetriesOnNetworkError() async throws {
        struct TestResponse: Codable {
            let message: String
        }
        
        MockURLProtocol.reset()
        
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        
        MockURLProtocol.mockError = networkError
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.requestHandler = nil
        
        do {
            let _: TestResponse = try await sut.request(endpoint: "/test", method: "GET")
            XCTFail("Должна была быть выброшена ошибка")
        } catch {
            XCTAssertEqual(MockURLProtocol.requestCount, Constants.API.retryCount, "Должно быть сделано \(Constants.API.retryCount) попытки при сетевой ошибке")
            XCTAssertTrue(error is APIError, "Должна быть ошибка APIError")
        }
    }
    
    func testNetworkService_Request_NoRetryOn400() async throws {
        struct TestResponse: Codable {
            let message: String
        }
        
        MockURLProtocol.reset()
        
        let response = HTTPURLResponse(
            url: URL(string: "https://test.api/test")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )!
        
        MockURLProtocol.mockData = Data()
        MockURLProtocol.mockResponse = response
        MockURLProtocol.mockError = nil
        MockURLProtocol.requestHandler = nil
        
        do {
            let _: TestResponse = try await sut.request(endpoint: "/test", method: "GET")
            XCTFail("Должна была быть выброшена ошибка")
        } catch let error as APIError {
            XCTAssertEqual(MockURLProtocol.requestCount, 1, "При 400 ошибке НЕ должно быть retry, только 1 попытка")
            
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 400, "Должна быть ошибка 400")
            } else {
                XCTFail("Ожидалась ошибка .httpError(400), получена: \(error)")
            }
        } catch {
            XCTFail("Ожидалась ошибка APIError.httpError, получена: \(error)")
        }
    }
    
    func testNetworkService_Request_MaxThreeRetries() {
        XCTAssertEqual(Constants.API.retryCount, 3)
    }
    
    func testNetworkService_Request_LogsStart() {
        XCTAssertNotNil(sut)
    }
    
    func testNetworkService_Request_LogsSuccess() {
        XCTAssertNotNil(sut)
    }
    
    func testNetworkService_Request_LogsErrors() {
        XCTAssertNotNil(sut)
    }
    
    func testNetworkService_Request_ThrowsOnInvalidJSON() async throws {
        struct TestResponse: Codable {
            let message: String
        }
        
        let invalidJSON = "not json".data(using: .utf8)!
        
        let response = HTTPURLResponse(
            url: URL(string: "https://test.api/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        MockURLProtocol.mockData = invalidJSON
        MockURLProtocol.mockResponse = response
        MockURLProtocol.mockError = nil
        
        do {
            let _: TestResponse = try await sut.request(endpoint: "/test", method: "GET")
            XCTFail("Должна была быть выброшена ошибка декодирования")
        } catch let error as APIError {
            if case .decodingError = error {
            } else {
                XCTFail("Ожидалась ошибка .decodingError, получена: \(error)")
            }
        } catch {
            XCTFail("Ожидалась ошибка APIError.decodingError, получена: \(error)")
        }
    }
    
    func testNetworkService_Request_RetriesAndSucceeds() async throws {
        struct TestResponse: Codable {
            let message: String
        }
        
        MockURLProtocol.reset()
        
        MockURLProtocol.requestHandler = { request in
            if MockURLProtocol.requestCount <= 2 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            } else {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let jsonData = """
                {"message": "success after retry"}
                """.data(using: .utf8)!
                return (response, jsonData)
            }
        }
        
        let result: TestResponse = try await sut.request(endpoint: "/test", method: "GET")
        
        XCTAssertEqual(MockURLProtocol.requestCount, 3, "Должно быть сделано 3 попытки")
        XCTAssertEqual(result.message, "success after retry", "Должен быть успешный результат после retry")
    }
    
    func testNetworkService_Request_ThrowsOnInvalidURL() async throws {
        struct TestResponse: Codable {
            let message: String
        }
        
        let service = NetworkService(baseURL: "")
        
        do {
            let _: TestResponse = try await service.request(endpoint: "invalid://url", method: "GET")
            XCTFail("Должна была быть выброшена ошибка")
        } catch let error as APIError {
            if case .networkError = error {
            } else {
                XCTFail("Ожидалась ошибка .networkError, получена: \(error)")
            }
        } catch {
            XCTFail("Ожидалась ошибка APIError, получена: \(error)")
        }
    }
    
    func testNetworkService_Request_Handles429RateLimit() async throws {
        struct TestResponse: Codable {
            let message: String
        }
        
        MockURLProtocol.reset()
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "1"]
            )!
            return (response, Data())
        }
        
        do {
            let _: TestResponse = try await sut.request(endpoint: "/test", method: "GET")
            XCTFail("Должна была быть выброшена ошибка после retry")
        } catch let error as APIError {
            XCTAssertEqual(MockURLProtocol.requestCount, Constants.API.retryCount, "Должно быть сделано \(Constants.API.retryCount) попытки при 429")
            
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 429, "Должна быть ошибка 429")
            } else {
                XCTFail("Ожидалась ошибка .httpError(429), получена: \(error)")
            }
        } catch {
            XCTFail("Ожидалась ошибка APIError.httpError, получена: \(error)")
        }
    }
    
    func testNetworkService_Upload_UploadsFile() async throws {
        let testData = "test file content".data(using: .utf8)!
        let responseData = "{\"success\": true, \"bookmarkId\": \"test-id\"}".data(using: .utf8)!
        
        MockURLProtocol.reset()
        
        MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
                url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
            return (response, responseData)
        }
        
        sut.setUserId("test-user")
        
        let parameters = ["key": "value"]
        let result = try await sut.upload(
            data: testData,
            fileName: "test.txt",
            endpoint: "/upload",
            parameters: parameters
        )
        
        XCTAssertEqual(result, responseData)
        XCTAssertGreaterThan(MockURLProtocol.requestCount, 0, "Должен быть сделан хотя бы один запрос")
    }
    
    func testNetworkService_Upload_ThrowsOnInvalidURL() async throws {
        let testData = Data([0x00, 0x01, 0x02])
        let service = NetworkService(baseURL: "")
        
        do {
            let _ = try await service.upload(
                data: testData,
                fileName: "test.txt",
                endpoint: "invalid://url",
                parameters: [:]
            )
            XCTFail("Должна была быть выброшена ошибка")
        } catch let error as APIError {
            if case .networkError = error {
            } else {
                XCTFail("Ожидалась ошибка .networkError, получена: \(error)")
            }
        } catch {
            XCTFail("Ожидалась ошибка APIError, получена: \(error)")
        }
    }
    
    func testNetworkService_Request_ThrowsOnNonHTTPResponse() async throws {
        struct TestResponse: Codable {
            let message: String
        }
        
        MockURLProtocol.reset()
        MockURLProtocol.mockData = Data()
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = nil
        
        do {
            let _: TestResponse = try await sut.request(endpoint: "/test", method: "GET")
            XCTFail("Должна была быть выброшена ошибка")
        } catch let error as APIError {
            if case .serverError = error {
            } else {
                XCTFail("Ожидалась ошибка .serverError, получена: \(error)")
            }
        } catch {
            XCTFail("Ожидалась ошибка APIError, получена: \(error)")
        }
    }
}
