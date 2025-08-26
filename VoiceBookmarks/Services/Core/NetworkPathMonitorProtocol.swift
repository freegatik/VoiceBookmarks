//
//  NetworkPathMonitorProtocol.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import Network

protocol NetworkPathMonitorProtocol: AnyObject {
    var pathUpdateHandler: ((NWPath) -> Void)? { get set }
    func start(queue: DispatchQueue)
    func cancel()
}

class NetworkPathMonitor: NetworkPathMonitorProtocol {
    private let monitor: NWPathMonitor
    
    init(requiredInterfaceType: NWInterface.InterfaceType? = nil) {
        if let interfaceType = requiredInterfaceType {
            self.monitor = NWPathMonitor(requiredInterfaceType: interfaceType)
        } else {
            self.monitor = NWPathMonitor()
        }
    }
    
    var pathUpdateHandler: ((NWPath) -> Void)? {
        get {
            return monitor.pathUpdateHandler
        }
        set {
            monitor.pathUpdateHandler = newValue
        }
    }
    
    func start(queue: DispatchQueue) {
        monitor.start(queue: queue)
    }
    
    func cancel() {
        monitor.cancel()
    }
}

class NetworkPathMonitorWrapper: NetworkPathMonitorProtocol {
    private let monitor: NWPathMonitor
    
    init(monitor: NWPathMonitor) {
        self.monitor = monitor
    }
    
    var pathUpdateHandler: ((NWPath) -> Void)? {
        get {
            return monitor.pathUpdateHandler
        }
        set {
            monitor.pathUpdateHandler = newValue
        }
    }
    
    func start(queue: DispatchQueue) {
        monitor.start(queue: queue)
    }
    
    func cancel() {
        monitor.cancel()
    }
}

class MockNetworkPathMonitor: NetworkPathMonitorProtocol {
    var pathUpdateHandler: ((NWPath) -> Void)?
    var startCalled = false
    var cancelCalled = false
    
    var simulatedPaths: [NWPath] = []
    var currentPathIndex = 0
    
    func start(queue: DispatchQueue) {
        startCalled = true
        
        let realMonitor = NWPathMonitor()
        realMonitor.pathUpdateHandler = { [weak self] path in
            self?.pathUpdateHandler?(path)
        }
        realMonitor.start(queue: queue)
        
        if !simulatedPaths.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for path in self.simulatedPaths {
                    self.pathUpdateHandler?(path)
                }
            }
        }
    }
    
    func cancel() {
        cancelCalled = true
        pathUpdateHandler = nil
    }
    
    func simulatePathUpdate(_ path: NWPath) {
        pathUpdateHandler?(path)
    }
}

