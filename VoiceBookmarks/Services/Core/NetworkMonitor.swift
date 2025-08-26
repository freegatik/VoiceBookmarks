//
//  NetworkMonitor.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import Network

class NetworkMonitor: ObservableObject {
    
    static let shared = NetworkMonitor()
    
    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    private let pathMonitor: NetworkPathMonitorProtocol
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private let logger = LoggerService.shared
    
    private init(pathMonitor: NetworkPathMonitorProtocol = NetworkPathMonitor()) {
        self.pathMonitor = pathMonitor
        
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--UITestForceOffline") {
            isConnected = false
        } else if args.contains("--UITestSeedFolders") || args.contains("-UITESTS") {
            isConnected = true
        } else if AppTestHostContext.isUnitTestHostedMainApp {
            return
        } else {
            startMonitoring()
        }
    }
    
    
    #if DEBUG
    init(forTesting: Bool, pathMonitor: NetworkPathMonitorProtocol = NetworkPathMonitor()) {
        self.pathMonitor = pathMonitor
        if !forTesting {
            startMonitoring()
        }
    }
    #endif
    
    
    func startMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else {
                    self?.connectionType = nil
                }
                
                self?.logger.info("Сеть: \(path.status == .satisfied ? "доступна" : "недоступна")", category: .network)
            }
        }
        
        pathMonitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        pathMonitor.cancel()
    }
    
    deinit {
        stopMonitoring()
    }
}
