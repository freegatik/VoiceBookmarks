//
//  MockURLProtocol.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

class MockURLProtocol: URLProtocol {
    
    static var mockData: Data?
    static var mockResponse: URLResponse?
    static var mockError: Error?
    
    static var requestCount: Int = 0
    static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))? = nil
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canInit(with task: URLSessionTask) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        MockURLProtocol.requestCount += 1
        
        if let handler = MockURLProtocol.requestHandler {
            let (response, data) = handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        
        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            let response = MockURLProtocol.mockResponse ?? URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = MockURLProtocol.mockData {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    
    override func stopLoading() {}
    
    static func reset() {
        requestCount = 0
        requestHandler = nil
        mockData = nil
        mockResponse = nil
        mockError = nil
    }
}

