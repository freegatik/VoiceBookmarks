//
//  TranscriptionProcessingExtension.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

extension TranscriptionMerger {
    func processPartialResult(
        accumulated: inout String,
        new: String,
        textPostProcessor: TextPostProcessor,
        logger: LoggerService
    ) -> String? {
        let logClosure: ((String, String) -> Void)? = { message, category in
            logger.debug(message, category: LoggerService.Category(rawValue: category) ?? .speech)
        }
        guard let merged = merge(accumulated: accumulated, new: new, logger: logClosure) else {
            let cleanedNew = removeInternalDuplicates(from: new)
            guard let mergedCleaned = merge(accumulated: accumulated, new: cleanedNew, logger: logClosure) else {
                let accumulatedWords = accumulated.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                let newWords = new.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                
                let corruptionAnalysis = self.analyzeTextCorruption(accumulatedWords)
                let isNewValid = newWords.count >= 2 && newWords.allSatisfy { $0.count >= 2 }
                
                if corruptionAnalysis.isCorrupted && isNewValid && new.count > accumulated.count / 2 {
                    logger.warning("processPartialResult: заменяем накопленный текст (испорчен: \(corruptionAnalysis.reasons.joined(separator: ", "))) на новый: '\(new.prefix(80))'", category: .speech)
                    let cleanedNew = self.removeInternalDuplicates(from: new)
                    let processed = textPostProcessor.process(cleanedNew)
                    accumulated = processed
                    return processed
                }
                
                let accumulatedWordsSet = Set(accumulated.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
                let newWordsSet = Set(new.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
                let newUniqueWords = newWordsSet.subtracting(accumulatedWordsSet)
                
                if !newUniqueWords.isEmpty {
                    logger.warning("Partial результат проигнорирован, но содержит уникальные слова: '\(new.prefix(50))...', уникальные: \(Array(newUniqueWords).prefix(5).joined(separator: ", "))", category: .speech)
                } else {
                    logger.debug("Partial результат проигнорирован (дубликат/исправление): '\(new.prefix(30))...'", category: .speech)
                }
                return nil
            }
            
            let processed = textPostProcessor.process(mergedCleaned)
            accumulated = processed
            return processed
        }
        
        let processed = textPostProcessor.process(merged)
        accumulated = processed
        return processed
    }
}

