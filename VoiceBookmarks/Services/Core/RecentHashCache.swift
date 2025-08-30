//
//  RecentHashCache.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

final class RecentHashCache {
    
    static let shared = RecentHashCache()
    private let logger = LoggerService.shared
    private let userDefaults = UserDefaults.standard
    private let storageKey = "recent_content_hashes"
    private let queue = DispatchQueue(label: "RecentHashCache.queue", qos: .utility)
    
    private init() {}
    
    
    func record(hash: String) {
        queue.async {
            var dict = self.userDefaults.dictionary(forKey: self.storageKey) as? [String: TimeInterval] ?? [:]
            dict[hash] = Date().timeIntervalSince1970
            self.userDefaults.set(dict, forKey: self.storageKey)
        }
    }
    
    
    func isRecent(hash: String, within seconds: TimeInterval) -> Bool {
        let now = Date().timeIntervalSince1970
        var recent = false
        queue.sync {
            var dict = self.userDefaults.dictionary(forKey: self.storageKey) as? [String: TimeInterval] ?? [:]
            if let ts = dict[hash], now - ts <= seconds {
                recent = true
            }
            let threshold = now - (24 * 3600)
            dict = dict.filter { $0.value >= threshold }
            self.userDefaults.set(dict, forKey: self.storageKey)
        }
        if recent {
            logger.info("RecentHashCache: найден недавний дубликат по hash \(hash.prefix(12))…", category: .fileOperation)
        }
        return recent
    }

    func removeAllForTesting() {
        queue.sync {
            userDefaults.removeObject(forKey: storageKey)
        }
    }
}

