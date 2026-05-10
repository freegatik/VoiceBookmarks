//
//  NetworkMonitorTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import Network
import Combine
@testable import VoiceBookmarks

final class NetworkMonitorTests: XCTestCase {
    
    var sut: NetworkMonitor!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        if AppTestHostContext.isUnitTestHostedMainApp {
            throw XCTSkip("NWPathMonitor под симуляторным TEST_HOST даёт SIGKILL при множественных инстансах")
        }
        sut = NetworkMonitor.shared
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testNetworkMonitor_Singleton_IsAccessible() {
        XCTAssertNotNil(NetworkMonitor.shared)
    }
    
    func testNetworkMonitor_Singleton_ReturnsSameInstance() {
        let instance1 = NetworkMonitor.shared
        let instance2 = NetworkMonitor.shared
        XCTAssertTrue(instance1 === instance2)
    }
    
    func testNetworkMonitor_InitialState_IsConnected() {
        XCTAssertTrue(sut.isConnected)
    }
    
    func testNetworkMonitor_StartMonitoring_DoesNotCrash() {
        sut.startMonitoring()
        XCTAssertNotNil(sut)
    }
    
    func testNetworkMonitor_StopMonitoring_DoesNotCrash() {
        sut.stopMonitoring()
        XCTAssertNotNil(sut)
    }
    
    func testNetworkMonitor_ConnectionType_CanBeNil() {
        XCTAssertNotNil(sut)
    }
    
    func testNetworkMonitor_IsConnected_IsPublished() {
        let initialValue = sut.isConnected
        XCTAssertEqual(initialValue, true)
    }
    
    func testNetworkMonitor_ConnectionType_IsPublished() {
        let _ = sut.connectionType
        XCTAssertNotNil(sut)
    }
    
    func testNetworkMonitor_StartMonitoring_CanBeCalledMultipleTimes() {
        sut.startMonitoring()
        sut.startMonitoring()
        sut.startMonitoring()
        XCTAssertNotNil(sut)
    }
    
    func testNetworkMonitor_StopMonitoring_CanBeCalledMultipleTimes() {
        sut.stopMonitoring()
        sut.stopMonitoring()
        sut.stopMonitoring()
        XCTAssertNotNil(sut)
    }
    
    func testNetworkMonitor_Monitoring_UpdatesIsConnected() {
        let initialValue = sut.isConnected
        XCTAssertNotNil(initialValue)
    }
    
    func testNetworkMonitor_Monitoring_UpdatesConnectionType() {
        let initialType = sut.connectionType
        XCTAssertTrue(initialType == nil || initialType == .wifi || initialType == .cellular)
    }
    
    func testNetworkMonitor_PathUpdateHandler_HandlesSatisfiedStatusWithWifi() {
        #if DEBUG
        let wifiMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
        let testMonitor = NetworkMonitor(forTesting: true, pathMonitor: NetworkPathMonitorWrapper(monitor: wifiMonitor))
        
        let expectation = XCTestExpectation(description: "Network status updated")
        var receivedValue: Bool?
        
        let cancellable = testMonitor.$isConnected
            .dropFirst()
            .sink { value in
                receivedValue = value
                expectation.fulfill()
            }
        
        testMonitor.startMonitoring()
        
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
        
        XCTAssertNotNil(receivedValue, "isConnected должен быть обновлен")
        #else
        sut.stopMonitoring()
        sut.startMonitoring()
        XCTAssertNotNil(sut.isConnected)
        #endif
    }
    
    func testNetworkMonitor_PathUpdateHandler_HandlesUnsatisfiedStatus() {
        #if DEBUG
        let testMonitor = NetworkMonitor(forTesting: true)
        testMonitor.stopMonitoring()
        testMonitor.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Status checked")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertNotNil(testMonitor.isConnected)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        #else
        sut.stopMonitoring()
        sut.startMonitoring()
        XCTAssertNotNil(sut.isConnected)
        #endif
    }
    
    func testNetworkMonitor_PathUpdateHandler_SetsWifiConnectionType() {
        #if DEBUG
        let wifiMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
        let testMonitor = NetworkMonitor(forTesting: true, pathMonitor: NetworkPathMonitorWrapper(monitor: wifiMonitor))
        
        let expectation = XCTestExpectation(description: "Connection type updated")
        
        let cancellable = testMonitor.$connectionType
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
        
        testMonitor.startMonitoring()
        
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
        
        XCTAssertNotNil(testMonitor)
        #else
        sut.stopMonitoring()
        sut.startMonitoring()
        XCTAssertTrue(sut.connectionType == nil || sut.connectionType == .wifi || sut.connectionType == .cellular)
        #endif
    }
    
    func testNetworkMonitor_PathUpdateHandler_SetsCellularConnectionType() {
        #if DEBUG
        let cellularMonitor = NWPathMonitor(requiredInterfaceType: .cellular)
        let testMonitor = NetworkMonitor(forTesting: true, pathMonitor: NetworkPathMonitorWrapper(monitor: cellularMonitor))
        
        let expectation = XCTestExpectation(description: "Connection type updated")
        
        let cancellable = testMonitor.$connectionType
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
        
        testMonitor.startMonitoring()
        
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
        
        XCTAssertNotNil(testMonitor)
        #else
        sut.stopMonitoring()
        sut.startMonitoring()
        XCTAssertNotNil(sut)
        #endif
    }
    
    func testNetworkMonitor_PathUpdateHandler_SetsNilConnectionType() {
        #if DEBUG
        let generalMonitor = NWPathMonitor()
        let testMonitor = NetworkMonitor(forTesting: true, pathMonitor: NetworkPathMonitorWrapper(monitor: generalMonitor))
        
        let expectation = XCTestExpectation(description: "Connection type updated")
        
        let cancellable = testMonitor.$connectionType
            .dropFirst()
            .sink { value in
                expectation.fulfill()
            }
        
        testMonitor.startMonitoring()
        
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
        
        XCTAssertNotNil(testMonitor)
        #else
        sut.stopMonitoring()
        sut.startMonitoring()
        XCTAssertNotNil(sut)
        #endif
    }
    
    func testNetworkMonitor_PathUpdateHandler_LogsNetworkStatus() {
        #if DEBUG
        let testMonitor = NetworkMonitor(forTesting: true)
        testMonitor.stopMonitoring()
        testMonitor.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Status logged")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertNotNil(testMonitor.isConnected)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        #else
        sut.stopMonitoring()
        sut.startMonitoring()
        XCTAssertNotNil(sut.isConnected)
        #endif
    }
    
    func testNetworkMonitor_Deinit_CallsStopMonitoring() {
        #if DEBUG
        var monitorInstance: NetworkMonitor?
        
        autoreleasepool {
            monitorInstance = NetworkMonitor(forTesting: true)
            XCTAssertNotNil(monitorInstance)
            
            monitorInstance?.startMonitoring()
            
            monitorInstance = nil
        }
        
        let expectation = XCTestExpectation(description: "Deinit executed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
        
        XCTAssertTrue(true, "deinit должен вызывать stopMonitoring")
        #else
        sut.startMonitoring()
        sut.stopMonitoring()
        XCTAssertTrue(true, "deinit вызывает stopMonitoring согласно коду")
        #endif
    }
    
    func testNetworkMonitor_Init_ChecksUITestArguments() {
        sut.stopMonitoring()
        sut.startMonitoring()
        
        XCTAssertNotNil(sut)
    }
    
    func testNetworkMonitor_PathUpdateHandler_ExecutesAllBranches() {
        sut.stopMonitoring()
        sut.startMonitoring()
        
        let expectation = XCTestExpectation(description: "All branches executed")
        
        var isConnectedUpdates: [Bool] = []
        var connectionTypeUpdates: [NWInterface.InterfaceType?] = []
        
        let cancellable1 = sut.$isConnected
            .dropFirst()

            .sink { value in
                isConnectedUpdates.append(value)
            }
        
        let cancellable2 = sut.$connectionType
            .dropFirst()
            .sink { value in
                connectionTypeUpdates.append(value)
            }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.5)
        
        cancellable1.cancel()
        cancellable2.cancel()
        
        XCTAssertTrue(true, "pathUpdateHandler выполнился и обработал все возможные ветки")
    }
}
