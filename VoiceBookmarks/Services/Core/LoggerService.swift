//
//  LoggerService.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import OSLog

protocol TranscriptionMergerLogger {
    func debug(_ message: String, category: String, file: String, function: String, line: Int)
}

extension TranscriptionMergerLogger {
    func debug(_ message: String, category: String, file: String = #file, function: String = #function, line: Int = #line) {
        self.debug(message, category: category, file: file, function: function, line: line)
    }
}

final class LoggerService: @unchecked Sendable {
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }
    
    enum Category: String {
        case network = "NETWORK"
        case auth = "AUTH"
        case storage = "STORAGE"
        case speech = "SPEECH"
        case ui = "UI"
        case lifecycle = "LIFECYCLE"
        case fileOperation = "FILE_OP"
        case offline = "OFFLINE"
        case webview = "WEBVIEW"
    }
    
    static let shared = LoggerService()
    
    private let osLog = OSLog(subsystem: "com.yourcompany.yourapp", category: "app")
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    private let shareExtensionLogsKey = "share_extension_logs"
    private let shareExtensionMaxEntries = 200
    private let isRunningInsideShareExtension: Bool = {
        #if os(iOS)
        return Bundle.main.bundleURL.pathExtension == "appex"
        #else
        return false
        #endif
    }()
    
    private init() {}
    
    
    func log(
        _ level: LogLevel,
        category: Category,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        if AppTestHostContext.isUnitTestHostedMainApp, level == .debug || level == .info {
            return
        }
        
        let timestamp = dateFormatter.string(from: Date())
        let filename = (file as NSString).lastPathComponent
        
        let logMessage = """
        [\(timestamp)] [\(level.rawValue)] [\(category.rawValue)]
        Файл: \(filename):\(line)
        Функция: \(function)
        Сообщение: \(message)
        ---
        """
        
        if isRunningInsideShareExtension {
            print("[SHARE EXT] \(logMessage)")
            persistShareExtensionLog(logMessage)
        }
        
        os_log("%{public}@", log: osLog, type: level.osLogType, logMessage)
    }
    
    
    func debug(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, category: category, message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: category, message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, category: category, message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, category: category, message, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, category: category, message, file: file, function: function, line: line)
    }
    
    func logNetworkRequest(method: String, endpoint: String, category: Category = .network, file: String = #file, function: String = #function, line: Int = #line) {
        info("HTTP \(method) \(endpoint)", category: category, file: file, function: function, line: line)
    }
    
    
    private func persistShareExtensionLog(_ message: String) {
        guard let defaults = SharedUserDefaults.shared else {
            return
        }
        
        var logs = defaults.stringArray(forKey: shareExtensionLogsKey) ?? []
        logs.append(message)
        if logs.count > shareExtensionMaxEntries {
            logs.removeFirst(logs.count - shareExtensionMaxEntries)
        }
        defaults.set(logs, forKey: shareExtensionLogsKey)
    }
    
    func fetchShareExtensionLogs() -> [String] {
        guard let defaults = SharedUserDefaults.shared else {
            return []
        }
        return defaults.stringArray(forKey: shareExtensionLogsKey) ?? []
    }
    
    func clearShareExtensionLogs() {
        guard let defaults = SharedUserDefaults.shared else {
            return
        }
        defaults.removeObject(forKey: shareExtensionLogsKey)
    }
}

extension LoggerService: TranscriptionMergerLogger {
    func debug(_ message: String, category: String, file: String, function: String, line: Int) {
        if let cat = Category(rawValue: category) {
            self.debug(message, category: cat, file: file, function: function, line: line)
        }
    }
}
