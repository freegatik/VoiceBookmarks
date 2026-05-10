//
//  SpeechServiceDependencies.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import Speech
import AVFoundation

protocol TimerProtocol {
    func invalidate()
}

extension Timer: TimerProtocol {}

protocol TimerFactoryProtocol {
    func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> TimerProtocol
}

class TimerFactory: TimerFactoryProtocol {
    func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> TimerProtocol {
        return Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: block)
    }
}

class MockTimerFactory: TimerFactoryProtocol {
    var scheduledTimers: [(interval: TimeInterval, repeats: Bool)] = []
    var mockTimers: [MockTimer] = []
    
    func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> TimerProtocol {
        let mockTimer = MockTimer(interval: interval, repeats: repeats, block: block)
        scheduledTimers.append((interval, repeats))
        mockTimers.append(mockTimer)
        return mockTimer
    }
    
    func fireAllTimers() {
        for timer in mockTimers where timer.isValid {
            timer.fire()
        }
    }
    
    func fireTimer(withInterval interval: TimeInterval) {
        for timer in mockTimers where timer.isValid && abs(timer.interval - interval) < 0.001 {
            timer.fire()
        }
    }
}

class MockTimer: TimerProtocol {
    let interval: TimeInterval
    let repeats: Bool
    let block: (Timer) -> Void
    var isValid = true
    
    init(interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) {
        self.interval = interval
        self.repeats = repeats
        self.block = block
    }
    
    func invalidate() {
        isValid = false
    }
    
    func fire() {
        if isValid {
            let timer = Timer(timeInterval: 0, repeats: false) { _ in }
            block(timer)
        }
    }
}
