//
//  TranscriptionMerger.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

class TranscriptionMerger {
    private func normalizeWord(_ word: String) -> String {
        return word.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }
    
    func removeInternalDuplicates(from text: String) -> String {
        let rawWords = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard rawWords.count >= 2 else { return text }
        
        var words: [String] = []
        for w in rawWords {
            if let prev = words.last, normalizeWord(prev) == normalizeWord(w) {
                continue
            }
            words.append(w)
        }
        guard words.count >= 2 else { return words.joined(separator: " ") }
        
        let hasBrokenWords = words.contains { word in
            word.count == 1 && !["а", "и", "о", "у", "в", "к", "с", "я"].contains(word.lowercased())
        }
        if hasBrokenWords && words.count > 5 {
            return text
        }
        
        var fixedWords: [String] = []
        var i = 0
        
        while i < words.count {
            let currentWord = words[i]
            let currentNormalized = normalizeWord(currentWord)
            
            var duplicateCount = 1
            var j = i + 1
            while j < words.count {
                let nextWord = words[j]
                let nextNormalized = normalizeWord(nextWord)
                if currentNormalized == nextNormalized {
                    duplicateCount += 1
                    j += 1
                } else {
                    break
                }
            }
            
            if duplicateCount > 1 {
                fixedWords.append(currentWord)
                i += duplicateCount
                continue
            }
            
            if i + 1 < words.count {
                let nextWord = words[i + 1]
                let nextNormalized = normalizeWord(nextWord)
                
                if currentNormalized == nextNormalized {
                    fixedWords.append(currentWord)
                    i += 2
                    continue
                }
                
                if currentWord.count >= 2 && nextWord.count >= 3 {
                    if nextNormalized.hasPrefix(currentNormalized) {
                        fixedWords.append(nextWord)
                        i += 2
                        continue
                    }
                }
                
            }
            
            let alreadyAdded = fixedWords.map { normalizeWord($0) }
            if currentWord.count >= 2 {
                let recentWords = Array(alreadyAdded.suffix(20))
                var shouldSkip = false
                for recentWord in recentWords {
                    if recentWord == currentNormalized {
                        shouldSkip = true
                        break
                    }
                    if currentWord.count >= 2 && recentWord.count >= 4 && recentWord.hasPrefix(currentNormalized) {
                        shouldSkip = true
                        break
                    }
                    if currentWord.count >= 3 && recentWord.count >= 2 && currentNormalized.hasPrefix(recentWord) {
                        shouldSkip = true
                        break
                    }
                    if abs(recentWord.count - currentNormalized.count) <= 2 {
                        let longer = recentWord.count >= currentNormalized.count ? recentWord : currentNormalized
                        let shorter = recentWord.count < currentNormalized.count ? recentWord : currentNormalized
                        if longer.hasPrefix(shorter) && shorter.count >= 4 {
                            shouldSkip = true
                            break
                        }
                    }
                }
                if shouldSkip {
                    i += 1
                    continue
                }
            }
            
            fixedWords.append(currentWord)
            i += 1
        }
        
        var finalWords: [String] = []
        i = 0
        
        while i < fixedWords.count {
            var maxPhraseLength = 0
            var maxPhraseMatch = false
            
            for phraseLen in stride(from: min(10, fixedWords.count / 2), through: 2, by: -1) {
                if i + phraseLen * 2 - 1 < fixedWords.count {
                    let phrase1 = Array(fixedWords[i..<i + phraseLen])
                    let phrase2 = Array(fixedWords[i + phraseLen..<i + phraseLen * 2])
                    
                    let phrase1Normalized = phrase1.map { normalizeWord($0) }
                    let phrase2Normalized = phrase2.map { normalizeWord($0) }
                    
                    if phrase1Normalized == phrase2Normalized {
                        maxPhraseLength = phraseLen
                        maxPhraseMatch = true
                        break
                    }
                }
            }
            
            if maxPhraseMatch {
                finalWords.append(contentsOf: Array(fixedWords[i..<i + maxPhraseLength]))
                i += maxPhraseLength * 2
                continue
            }
            
            if i + 1 < fixedWords.count {
                let word1 = normalizeWord(fixedWords[i])
                let word2 = normalizeWord(fixedWords[i + 1])
                if word1 == word2 {
                    finalWords.append(fixedWords[i])
                    i += 2
                    continue
                }
            }
            
            finalWords.append(fixedWords[i])
            i += 1
        }
        
        var result = finalWords.joined(separator: " ")
        
        let originalLength = text.count
        let resultLength = result.count
        if resultLength < Int(Double(originalLength) * 0.7) && originalLength > 28 {
            return text
        }
        
        let resultWords = result.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if resultWords.count >= 6 {
            let normalizedWords = resultWords.map { normalizeWord($0) }
            var seenPhrases: [String] = []
            var uniqueWords: [String] = []
            
            for (index, word) in normalizedWords.enumerated() {
                var shouldSkip = false
                
                if index >= 2 {
                    let phrase3 = [normalizedWords[index - 2], normalizedWords[index - 1], word].joined(separator: " ")
                    if seenPhrases.contains(phrase3) {
                        shouldSkip = true
                    } else {
                        seenPhrases.append(phrase3)
                    }
                }
                
                if !shouldSkip && index >= 1 {
                    let phrase2 = [normalizedWords[index - 1], word].joined(separator: " ")
                    if seenPhrases.contains(phrase2) {
                        shouldSkip = true
                    } else {
                        seenPhrases.append(phrase2)
                    }
                }
                
                if !shouldSkip {
                    uniqueWords.append(resultWords[index])
                }
            }
            
            if uniqueWords.count < resultWords.count {
                let newResult = uniqueWords.joined(separator: " ")
                if newResult.count >= Int(Double(result.count) * 0.8) {
                    result = newResult
                }
            }
        }
        
        if result.count < Int(Double(text.count) * 0.7) && text.count > 28 {
            return text
        }
        
        return result
    }
    
    func merge(accumulated: String, new: String, logger: ((String, String) -> Void)? = nil) -> String? {
        let trimmedAccumulated = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNew = new.trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger?("merge: accumulated='\(trimmedAccumulated.prefix(100))' (\(trimmedAccumulated.count) символов), new='\(trimmedNew.prefix(100))' (\(trimmedNew.count) символов)", "SPEECH")
        
        guard !trimmedNew.isEmpty else {
            logger?("merge: отклонено - новый текст пуст", "SPEECH")
            return nil
        }
        
        if trimmedAccumulated.isEmpty {
            let result = removeInternalDuplicates(from: trimmedNew)
            logger?("merge: принято (накопленный пуст) -> '\(result.prefix(100))'", "SPEECH")
            return result
        }
        
        if trimmedNew == trimmedAccumulated {
            logger?("merge: отклонено - идентичные тексты", "SPEECH")
            return nil
        }
        
        let accumulatedWordsList = trimmedAccumulated.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let newWordsList = trimmedNew.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        let accumulatedWordsSet = Set(accumulatedWordsList.map { normalizeWord($0) })
        let newWordsSet = Set(newWordsList.map { normalizeWord($0) })
        
        let newUniqueWords = newWordsSet.subtracting(accumulatedWordsSet)
        
        let newPartiallyUniqueWords = newWordsList.filter { newWord in
            let normalizedNew = normalizeWord(newWord)
            if !accumulatedWordsSet.contains(normalizedNew) {
                let isPartOfAccumulated = accumulatedWordsSet.contains { accWord in
                    accWord.contains(normalizedNew) || normalizedNew.contains(accWord)
                }
                return !isPartOfAccumulated || newWord.count >= 5
            }
            return false
        }.map { normalizeWord($0) }
        
        let allUniqueWords = newUniqueWords.union(Set(newPartiallyUniqueWords))
        
        logger?("merge: анализ слов - накоплено: \(accumulatedWordsList.count) слов, новых: \(newWordsList.count) слов, уникальных новых: \(allUniqueWords.count) слов (\(Array(allUniqueWords).prefix(5).joined(separator: ", ")))", "SPEECH")
        
        if !allUniqueWords.isEmpty {
            logger?("merge: ПРИОРИТЕТ - есть новые уникальные слова (\(allUniqueWords.count) слов), пробуем умное слияние", "SPEECH")
            
            let isObviousCorrection = trimmedNew.count <= 1 && trimmedAccumulated.count > 10
            
            if !isObviousCorrection {
                let accumulatedWords = trimmedAccumulated.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                let newWords = trimmedNew.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                
                let corruptionAnalysis = analyzeTextCorruption(accumulatedWords)
                
                let isNewTextCorrection = {
                    if newWords.count == 1 && accumulatedWords.count >= 2 {
                        let newWord = newWords[0].lowercased()
                        let accumulatedCombined = accumulatedWords.joined(separator: "").lowercased()
                        if newWord.contains(accumulatedCombined) || accumulatedCombined.count >= 6 {
                            return true
                        }
                        let commonPrefix = commonPrefixLength(newWord, accumulatedCombined)
                        if commonPrefix >= 4 && newWord.count > accumulatedCombined.count {
                            return true
                        }
                    }
                    return false
                }()
                
                let isAccumulatedCorrupted = corruptionAnalysis.isCorrupted
                let isNewValid = (newWords.count >= 1 && newWords.allSatisfy { $0.count >= 2 }) || isNewTextCorrection
                
                if isAccumulatedCorrupted && (isNewValid || isNewTextCorrection) {
                    let newIsBetter = {
                        if isNewTextCorrection {
                            return Double(trimmedNew.count) >= Double(trimmedAccumulated.count) * 0.8
                        } else {
                            let accumulatedWordCount = accumulatedWords.count
                            let newWordCount = newWords.count
                            
                            if newWordCount >= accumulatedWordCount && Double(trimmedNew.count) >= Double(trimmedAccumulated.count) * 0.9 {
                                return true
                            }
                            
                            let accumulatedKeyWords = Set(accumulatedWords.filter { $0.count >= 3 }.map { normalizeWord($0) })
                            let newKeyWords = Set(newWords.filter { $0.count >= 3 }.map { normalizeWord($0) })
                            let coveredWords = accumulatedKeyWords.intersection(newKeyWords)
                            
                            if Double(coveredWords.count) >= Double(accumulatedKeyWords.count) * 0.7 && Double(trimmedNew.count) >= Double(trimmedAccumulated.count) * 0.8 {
                                return true
                            }
                            
                            return false
                        }
                    }()
                    
                    if newIsBetter {
                        if isNewTextCorrection {
                            logger?("merge: заменяем накопленный текст (содержит разбитое слово) на исправление: '\(trimmedNew.prefix(80))'", "SPEECH")
                        } else {
                            logger?("merge: заменяем накопленный текст (испорчен: \(corruptionAnalysis.reasons.joined(separator: ", "))) на новый: '\(trimmedNew.prefix(80))'", "SPEECH")
                        }
                        let cleaned = removeInternalDuplicates(from: trimmedNew)
                        return cleaned
                    } else {
                        logger?("merge: накопленный испорчен, но новый текст не лучше - используем слияние", "SPEECH")
                    }
                }
                
                var merged: String? = nil
                let accumulatedWordsForLog = trimmedAccumulated.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                let newWordsForLog = trimmedNew.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                logger?("merge: пробуем умное слияние: накоплено \(accumulatedWordsForLog.count) слов (\(Array(accumulatedWordsForLog.suffix(3)).joined(separator: ", "))), новых \(newWordsForLog.count) слов (\(Array(newWordsForLog.prefix(3)).joined(separator: ", ")))", "SPEECH")
                
                if let wordOverlap = mergeByWordOverlap(accumulated: trimmedAccumulated, new: trimmedNew) {
                    merged = wordOverlap
                    logger?("merge: mergeByWordOverlap успешно -> '\(wordOverlap.prefix(100))'", "SPEECH")
                }
                else if let charOverlap = mergeByCharacterOverlap(accumulated: trimmedAccumulated, new: trimmedNew) {
                    merged = charOverlap
                    logger?("merge: mergeByCharacterOverlap успешно -> '\(charOverlap.prefix(100))'", "SPEECH")
                }
                else if let fuzzyOverlap = mergeByFuzzyOverlap(accumulated: trimmedAccumulated, new: trimmedNew) {
                    merged = fuzzyOverlap
                    logger?("merge: mergeByFuzzyOverlap успешно -> '\(fuzzyOverlap.prefix(100))'", "SPEECH")
                } else {
                    logger?("merge: все методы умного слияния не сработали", "SPEECH")
                }
                
                if merged == nil && newWords.count >= 2 {
                    logger?("merge: умное слияние не сработало, пробуем простое дополнение", "SPEECH")
                    merged = trimmedAccumulated + " " + trimmedNew
                    logger?("merge: дополнение: накоплено=\(trimmedAccumulated.count) символов, новый=\(trimmedNew.count) символов, результат=\(merged!.count) символов", "SPEECH")
                }
                
                if merged == nil {
                    merged = trimmedAccumulated + " " + trimmedNew
                    logger?("merge: используем простое склеивание", "SPEECH")
                }
                
                if let mergedResult = merged {
                    let cleaned = removeInternalDuplicates(from: mergedResult)
                    
                    let words = cleaned.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                    let singleLetterCount = words.filter { word in
                        word.count == 1 && !["а", "и", "о", "у", "в", "к", "с", "я"].contains(word.lowercased())
                    }.count
                    
                    if singleLetterCount > words.count / 3 && words.count > 5 {
                        let newWordsCount = newWords.count
                        let newWordsValid = newWords.allSatisfy { $0.count >= 2 }
                        
                        if newWordsCount >= 2 && newWordsValid && trimmedNew.count > trimmedAccumulated.count {
                            logger?("merge: очистка создала проблемы, но новый текст правильный - используем новый", "SPEECH")
                            let cleanedNew = removeInternalDuplicates(from: trimmedNew)
                            return cleanedNew
                        }
                        
                        logger?("merge: очистка создала слишком много одиночных букв, используем без очистки", "SPEECH")
                        return mergedResult
                    }
                    
                    let hasCriticalInvalidPatterns = words.count > 3 && singleLetterCount > words.count / 2
                    
                    if !hasCriticalInvalidPatterns && cleaned != trimmedAccumulated {
                        logger?("merge: принято через приоритет уникальных слов -> '\(cleaned.prefix(100))'", "SPEECH")
                        return cleaned
                    } else if hasCriticalInvalidPatterns {
                        if newWords.count >= 2 && newWords.allSatisfy({ $0.count >= 2 }) && trimmedNew.count > trimmedAccumulated.count {
                            logger?("merge: есть проблемы, но новый текст правильный - используем новый", "SPEECH")
                            let cleanedNew = removeInternalDuplicates(from: trimmedNew)
                            return cleanedNew
                        }
                        logger?("merge: есть неправильные паттерны, используем без очистки", "SPEECH")
                        return mergedResult
                    }
                }
            } else {
                logger?("merge: отклонено как очевидное исправление (одна буква)", "SPEECH")
            }
        }
        
        if trimmedNew.count < 2 && !trimmedAccumulated.isEmpty {
            let lastAccumulatedWord = trimmedAccumulated.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.last?.lowercased() ?? ""
            let newWord = trimmedNew.lowercased()
            if lastAccumulatedWord != newWord && !lastAccumulatedWord.hasSuffix(newWord) && !newWord.hasSuffix(lastAccumulatedWord) {
                return trimmedAccumulated + " " + trimmedNew
            }
            return nil
        }
        
        if trimmedNew.hasPrefix(trimmedAccumulated) {
            logger?("merge: проверка hasPrefix - новый текст начинается с накопленного", "SPEECH")
            let newPart = String(trimmedNew.dropFirst(trimmedAccumulated.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !newPart.isEmpty {
                let accumulatedWords = Set(trimmedAccumulated.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
                let newWords = Set(trimmedNew.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
                let newWordsInNew = newWords.subtracting(accumulatedWords)
                
                logger?("merge: hasPrefix - новые слова: \(Array(newWordsInNew).prefix(5).joined(separator: ", "))", "SPEECH")
                
                if !newWordsInNew.isEmpty {
                    let cleaned = removeInternalDuplicates(from: trimmedNew)
                    if cleaned != trimmedAccumulated {
                        if !hasInternalDuplicates(in: cleaned) {
                            logger?("merge: принято через hasPrefix -> '\(cleaned.prefix(100))'", "SPEECH")
                            return cleaned
                        } else {
                            let reCleaned = removeInternalDuplicates(from: cleaned)
                            if !hasInternalDuplicates(in: reCleaned) && reCleaned != trimmedAccumulated {
                                logger?("merge: принято через hasPrefix (после повторной очистки) -> '\(reCleaned.prefix(100))'", "SPEECH")
                                return reCleaned
                            }
                        }
                    }
                }
            }
            logger?("merge: отклонено через hasPrefix - нет новых слов или дубликаты", "SPEECH")
            return nil
        }
        
        let accumulatedLower = trimmedAccumulated.lowercased()
        let newLower = trimmedNew.lowercased()
        if newLower.contains(accumulatedLower) && trimmedNew.count > trimmedAccumulated.count {
            logger?("merge: проверка contains - новый текст содержит накопленный", "SPEECH")
            let accumulatedWords = Set(accumulatedLower.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
            let newWords = Set(newLower.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
            let newWordsInNew = newWords.subtracting(accumulatedWords)
            
            logger?("merge: contains - новые слова: \(Array(newWordsInNew).prefix(5).joined(separator: ", "))", "SPEECH")
            
            if !newWordsInNew.isEmpty {
                let cleaned = removeInternalDuplicates(from: trimmedNew)
                if cleaned != trimmedAccumulated && !hasInternalDuplicates(in: cleaned) {
                    logger?("merge: принято через contains -> '\(cleaned.prefix(100))'", "SPEECH")
                    return cleaned
                }
            }
        }
        
        if trimmedAccumulated.hasPrefix(trimmedNew) && trimmedNew.count < trimmedAccumulated.count {
            return nil
        }
        
        if trimmedAccumulated.count <= 5 && trimmedNew.hasPrefix(trimmedAccumulated) && trimmedNew.count > trimmedAccumulated.count {
            let cleaned = removeInternalDuplicates(from: trimmedNew)
            if !hasInternalDuplicates(in: cleaned) {
                return cleaned
            }
        }
        
        if trimmedAccumulated.contains(trimmedNew) && trimmedNew.count < trimmedAccumulated.count {
            return nil
        }
        
        if trimmedAccumulated.count <= 4 && trimmedNew.hasPrefix(trimmedAccumulated) && trimmedNew.count >= trimmedAccumulated.count * 2 {
            let cleaned = removeInternalDuplicates(from: trimmedNew)
            if !hasInternalDuplicates(in: cleaned) {
                return cleaned
            }
        }
        
        let hasNewContent = !newUniqueWords.isEmpty
        
        let accumulatedLowerCheck = trimmedAccumulated.lowercased()
        let newLowerCheck = trimmedNew.lowercased()
        if newLowerCheck.contains(accumulatedLowerCheck) && trimmedNew.count > trimmedAccumulated.count {
            if let range = newLowerCheck.range(of: accumulatedLowerCheck) {
                let afterAccumulated = String(trimmedNew[range.upperBound...]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !afterAccumulated.isEmpty {
                    let cleaned = removeInternalDuplicates(from: trimmedNew)
                    if cleaned != trimmedAccumulated && !hasInternalDuplicates(in: cleaned) {
                        let accumulatedWordsCheck = Set(accumulatedLowerCheck.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty })
                        let cleanedWords = Set(cleaned.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty })
                        let newWordsInCleaned = cleanedWords.subtracting(accumulatedWordsCheck)
                        
                        if !newWordsInCleaned.isEmpty {
                            return cleaned
                        }
                    }
                }
            }
        }
        
        if let merged = mergeByWordOverlap(accumulated: trimmedAccumulated, new: trimmedNew) {
            logger?("merge: mergeByWordOverlap успешно -> '\(merged.prefix(100))'", "SPEECH")
            let cleaned = removeInternalDuplicates(from: merged)
            if cleaned != trimmedAccumulated {
                if hasInternalDuplicates(in: cleaned) {
                    if hasNewContent && newUniqueWords.count >= 1 {
                        let reCleaned = removeInternalDuplicates(from: cleaned)
                        if !hasInternalDuplicates(in: reCleaned) {
                            logger?("merge: принято через mergeByWordOverlap (после повторной очистки) -> '\(reCleaned.prefix(100))'", "SPEECH")
                            return reCleaned
                        }
                    }
                    logger?("merge: отклонено через mergeByWordOverlap - есть дубликаты и нет новых слов", "SPEECH")
                    return nil
                }
                if hasDuplicateWords(accumulated: trimmedAccumulated, new: trimmedNew) {
                    if hasNewContent && newUniqueWords.count >= 1 {
                        logger?("merge: принято через mergeByWordOverlap (есть дубликаты, но есть новые слова) -> '\(cleaned.prefix(100))'", "SPEECH")
                        return cleaned
                    }
                    logger?("merge: отклонено через mergeByWordOverlap - есть дубликаты и нет новых слов", "SPEECH")
                    return nil
                }
                logger?("merge: принято через mergeByWordOverlap -> '\(cleaned.prefix(100))'", "SPEECH")
                return cleaned
            }
        } else {
            logger?("merge: mergeByWordOverlap не сработал", "SPEECH")
        }
        
        if let merged = mergeByCharacterOverlap(accumulated: trimmedAccumulated, new: trimmedNew) {
            logger?("merge: mergeByCharacterOverlap успешно -> '\(merged.prefix(100))'", "SPEECH")
            let cleaned = removeInternalDuplicates(from: merged)
            if cleaned != trimmedAccumulated {
                if hasInternalDuplicates(in: cleaned) {
                    if hasNewContent && newUniqueWords.count >= 1 {
                        let reCleaned = removeInternalDuplicates(from: cleaned)
                        if !hasInternalDuplicates(in: reCleaned) {
                            logger?("merge: принято через mergeByCharacterOverlap (после повторной очистки) -> '\(reCleaned.prefix(100))'", "SPEECH")
                            return reCleaned
                        }
                    }
                    logger?("merge: отклонено через mergeByCharacterOverlap - есть дубликаты и нет новых слов", "SPEECH")
                    return nil
                }
                if hasDuplicateWords(accumulated: trimmedAccumulated, new: trimmedNew) {
                    if hasNewContent && newUniqueWords.count >= 1 {
                        logger?("merge: принято через mergeByCharacterOverlap (есть дубликаты, но есть новые слова) -> '\(cleaned.prefix(100))'", "SPEECH")
                        return cleaned
                    }
                    logger?("merge: отклонено через mergeByCharacterOverlap - есть дубликаты и нет новых слов", "SPEECH")
                    return nil
                }
                logger?("merge: принято через mergeByCharacterOverlap -> '\(cleaned.prefix(100))'", "SPEECH")
                return cleaned
            }
        } else {
            logger?("merge: mergeByCharacterOverlap не сработал", "SPEECH")
        }
        
        if let merged = mergeByFuzzyOverlap(accumulated: trimmedAccumulated, new: trimmedNew) {
            logger?("merge: mergeByFuzzyOverlap успешно -> '\(merged.prefix(100))'", "SPEECH")
            let cleaned = removeInternalDuplicates(from: merged)
            if cleaned != trimmedAccumulated {
                if hasInternalDuplicates(in: cleaned) {
                    if hasNewContent && newUniqueWords.count >= 1 {
                        let reCleaned = removeInternalDuplicates(from: cleaned)
                        if !hasInternalDuplicates(in: reCleaned) {
                            logger?("merge: принято через mergeByFuzzyOverlap (после повторной очистки) -> '\(reCleaned.prefix(100))'", "SPEECH")
                            return reCleaned
                        }
                    }
                    logger?("merge: отклонено через mergeByFuzzyOverlap - есть дубликаты и нет новых слов", "SPEECH")
                    return nil
                }
                if hasDuplicateWords(accumulated: trimmedAccumulated, new: trimmedNew) {
                    if hasNewContent && newUniqueWords.count >= 1 {
                        logger?("merge: принято через mergeByFuzzyOverlap (есть дубликаты, но есть новые слова) -> '\(cleaned.prefix(100))'", "SPEECH")
                        return cleaned
                    }
                    logger?("merge: отклонено через mergeByFuzzyOverlap - есть дубликаты и нет новых слов", "SPEECH")
                    return nil
                }
                logger?("merge: принято через mergeByFuzzyOverlap -> '\(cleaned.prefix(100))'", "SPEECH")
                return cleaned
            }
        } else {
            logger?("merge: mergeByFuzzyOverlap не сработал", "SPEECH")
        }
        
        if trimmedNew.count >= 1 && !isLikelyCorrection(accumulated: trimmedAccumulated, new: trimmedNew) {
            let hasNewContent = !newUniqueWords.isEmpty
            
            if hasDuplicateWords(accumulated: trimmedAccumulated, new: trimmedNew) {
                if hasNewContent && newUniqueWords.count >= 1 {
                    let merged = trimmedAccumulated + " " + trimmedNew
                    let cleaned = removeInternalDuplicates(from: merged)
                    if cleaned != trimmedAccumulated && !hasInternalDuplicates(in: cleaned) {
                        checkForGaps(accumulated: trimmedAccumulated, new: trimmedNew)
                        return cleaned
                    }
                }
                
                if trimmedNew.count <= 2 && !trimmedAccumulated.isEmpty {
                    let lastAccumulatedWord = trimmedAccumulated.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.last?.lowercased() ?? ""
                    let firstNewWord = trimmedNew.lowercased()
                    if lastAccumulatedWord != firstNewWord && !lastAccumulatedWord.hasSuffix(firstNewWord) && !firstNewWord.hasSuffix(lastAccumulatedWord) {
                        let merged = trimmedAccumulated + " " + trimmedNew
                        let cleaned = removeInternalDuplicates(from: merged)
                        if cleaned != trimmedAccumulated {
                            return cleaned
                        }
                    }
                }
                
                return nil
            }
            
            if hasNewContent && newUniqueWords.count >= 1 {
                let merged = trimmedAccumulated + " " + trimmedNew
                let cleaned = removeInternalDuplicates(from: merged)
                if cleaned != trimmedAccumulated && !hasInternalDuplicates(in: cleaned) {
                    checkForGaps(accumulated: trimmedAccumulated, new: trimmedNew)
                    return cleaned
                }
            }
        }
        
        let accumulatedWordsListLower = trimmedAccumulated.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
        let newWordsListLower = trimmedNew.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
        
        if !accumulatedWordsListLower.isEmpty && !newWordsListLower.isEmpty {
            logger?("merge: проверка пересечения по последним словам - накоплено: \(accumulatedWordsListLower.count) слов, новых: \(newWordsListLower.count) слов", "SPEECH")
            for suffixLen in stride(from: min(5, accumulatedWordsListLower.count), through: 1, by: -1) {
                let accumulatedSuffix = Array(accumulatedWordsListLower.suffix(suffixLen))
                let newPrefix = Array(newWordsListLower.prefix(suffixLen))
                
                if accumulatedSuffix == newPrefix {
                    logger?("merge: найдено пересечение по последним словам (suffixLen=\(suffixLen)): \(accumulatedSuffix.joined(separator: " "))", "SPEECH")
                    let newPart = Array(newWordsListLower.dropFirst(suffixLen))
                    if !newPart.isEmpty {
                        let merged = trimmedAccumulated + " " + newPart.joined(separator: " ")
                        let cleaned = removeInternalDuplicates(from: merged)
                        if cleaned != trimmedAccumulated && !hasInternalDuplicates(in: cleaned) {
                            logger?("merge: принято через пересечение по последним словам -> '\(cleaned.prefix(100))'", "SPEECH")
                            return cleaned
                        }
                    }
                    break
                }
            }
            
            for prefixLen in stride(from: min(5, newWordsListLower.count), through: 2, by: -1) {
                let newPrefix = Array(newWordsListLower.prefix(prefixLen))
                let accumulatedSuffix = Array(accumulatedWordsListLower.suffix(prefixLen))
                
                if newPrefix == accumulatedSuffix {
                    logger?("merge: найдено обратное пересечение (prefixLen=\(prefixLen)): \(newPrefix.joined(separator: " "))", "SPEECH")
                    let newPart = Array(newWordsListLower.dropFirst(prefixLen))
                    if !newPart.isEmpty {
                        let merged = trimmedAccumulated + " " + newPart.joined(separator: " ")
                        let cleaned = removeInternalDuplicates(from: merged)
                        if cleaned != trimmedAccumulated && !hasInternalDuplicates(in: cleaned) {
                            logger?("merge: принято через обратное пересечение -> '\(cleaned.prefix(100))'", "SPEECH")
                            return cleaned
                        }
                    }
                    break
                }
            }
        }
        
        if !newUniqueWords.isEmpty && newUniqueWords.count >= 1 {
            logger?("merge: fallback - есть новые уникальные слова, но не приняты выше, пробуем принудительно: \(Array(newUniqueWords).prefix(5).joined(separator: ", "))", "SPEECH")
            
            var merged: String? = nil
            
            if let wordOverlap = mergeByWordOverlap(accumulated: trimmedAccumulated, new: trimmedNew) {
                merged = wordOverlap
            } else if let charOverlap = mergeByCharacterOverlap(accumulated: trimmedAccumulated, new: trimmedNew) {
                merged = charOverlap
            } else if let fuzzyOverlap = mergeByFuzzyOverlap(accumulated: trimmedAccumulated, new: trimmedNew) {
                merged = fuzzyOverlap
            } else {
                merged = trimmedAccumulated + " " + trimmedNew
            }
            
            if let mergedResult = merged {
                let cleaned = removeInternalDuplicates(from: mergedResult)
                
                if cleaned != trimmedAccumulated {
                    logger?("merge: ПРИНЯТО через fallback (принудительно, умное слияние) -> '\(cleaned.prefix(100))'", "SPEECH")
                    return cleaned
                }
            }
        }
        
        logger?("merge: все проверки провалились, результат отклонен", "SPEECH")
        return nil
    }
    
    private func checkForGaps(accumulated: String, new: String) {
        let accumulatedWords = accumulated.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let newWords = new.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        guard !accumulatedWords.isEmpty && !newWords.isEmpty else { return }
        
        _ = normalizeWord(accumulatedWords.last!)
        _ = normalizeWord(newWords.first!)
    }
    
    private func mergeByWordOverlap(accumulated: String, new: String) -> String? {
        let accumulatedWords = accumulated.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let newWords = new.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        guard !accumulatedWords.isEmpty && !newWords.isEmpty else { return nil }
        
        var maxOverlap = 0
        let maxPossibleOverlap = min(accumulatedWords.count, newWords.count)
        
        guard maxPossibleOverlap >= 1 else { return nil }
        
        for overlapSize in stride(from: maxPossibleOverlap, through: 1, by: -1) {
            let lastAccumulated = Array(accumulatedWords.suffix(overlapSize))
            let firstNew = Array(newWords.prefix(overlapSize))
            
            let normalizedLast = normalizeWords(lastAccumulated)
            let normalizedFirst = normalizeWords(firstNew)
            
            if normalizedLast == normalizedFirst {
                maxOverlap = overlapSize
                break
            }
            
            if overlapSize == 1 {
                let lastWord = normalizedLast[0]
                let firstWord = normalizedFirst[0]
                
                if lastWord == firstWord {
                    maxOverlap = 1
                    break
                }
                
                if firstWord.count > lastWord.count && firstWord.hasPrefix(lastWord) && lastWord.count >= 3 {
                    maxOverlap = 1
                    break
                }
                
                if lastWord.count > firstWord.count && lastWord.hasPrefix(firstWord) && firstWord.count >= 3 {
                    maxOverlap = 1
                    break
                }
                
                if firstWord.count >= 6 && lastWord.count >= 4 {
                    let commonPrefix = commonPrefixLength(firstWord, lastWord)
                    if commonPrefix >= 4 {
                        maxOverlap = 1
                        break
                    }
                }
                
                if areWordsRelated(lastWord, firstWord) {
                    maxOverlap = 1
                    break
                }
            }
        }
        
        if maxOverlap > 0 {
            let newPartWords = Array(newWords.dropFirst(maxOverlap))
            if !newPartWords.isEmpty {
                let newPart = newPartWords.joined(separator: " ")
                return accumulated + " " + newPart
            }
            return nil
        }
        
        return nil
    }
    
    private func mergeByCharacterOverlap(accumulated: String, new: String) -> String? {
        guard accumulated.count >= 10 && new.count >= 5 else { return nil }
        
        let accumulatedWords = accumulated.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let newWords = new.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        guard !accumulatedWords.isEmpty && !newWords.isEmpty else { return nil }
        
        let lastAccumulatedWord = accumulatedWords.last!
        let firstNewWord = newWords.first!
        
        guard lastAccumulatedWord.count >= 4 && firstNewWord.count >= 4 else { return nil }
        
        let lastWordLower = lastAccumulatedWord.lowercased()
        let firstWordLower = firstNewWord.lowercased()
        
        let minWordLength = min(lastWordLower.count, firstWordLower.count)
        guard minWordLength >= 5 else { return nil }
        
        var maxCharOverlap = 0
        let maxPossibleOverlap = min(lastWordLower.count, firstWordLower.count)
        let minOverlap = max(4, minWordLength / 2)
        
        guard maxPossibleOverlap >= minOverlap else { return nil }
        
        let maxAllowedOverlap = min(maxPossibleOverlap, minWordLength - 1)
        
        for overlapLen in stride(from: min(maxAllowedOverlap, 10), through: minOverlap, by: -1) {
            let lastWordSuffix = String(lastWordLower.suffix(overlapLen))
            if firstWordLower.hasPrefix(lastWordSuffix) {
                maxCharOverlap = overlapLen
                break
            }
        }
        
        if maxCharOverlap >= minOverlap && maxCharOverlap < lastAccumulatedWord.count {
            let lastWordSuffix = String(lastAccumulatedWord.suffix(maxCharOverlap))
            if let range = firstNewWord.range(of: lastWordSuffix, options: .caseInsensitive) {
                let newPartOfFirstWord = String(firstNewWord[range.upperBound...])
                let remainingNewWords = Array(newWords.dropFirst())
                
                let trimmedPart = lastAccumulatedWord.prefix(lastAccumulatedWord.count - maxCharOverlap)
                guard trimmedPart.count <= lastAccumulatedWord.count / 2 else { return nil }
                
                var newPart = ""
                if !newPartOfFirstWord.isEmpty {
                    newPart = newPartOfFirstWord
                }
                if !remainingNewWords.isEmpty {
                    if !newPart.isEmpty {
                        newPart += " " + remainingNewWords.joined(separator: " ")
                    } else {
                        newPart = remainingNewWords.joined(separator: " ")
                    }
                }
                
                if !newPart.isEmpty {
                    let accumulatedWithoutLastWord = accumulatedWords.dropLast().joined(separator: " ")
                    if accumulatedWithoutLastWord.isEmpty {
                        return String(trimmedPart) + newPart
                    } else {
                        return accumulatedWithoutLastWord + " " + String(trimmedPart) + newPart
                    }
                }
            }
        }
        
        return nil
    }
    
    private func mergeByFuzzyOverlap(accumulated: String, new: String) -> String? {
        guard accumulated.count >= 8 && new.count >= 4 else { return nil }
        
        let accumulatedWords = accumulated.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let newWords = new.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        guard !accumulatedWords.isEmpty && !newWords.isEmpty else { return nil }
        
        let lastAccumulatedWord = normalizeWord(accumulatedWords.last!)
        let firstNewWord = normalizeWord(newWords.first!)
        
        if areWordsRelated(lastAccumulatedWord, firstNewWord) {
            let newPartWords = Array(newWords.dropFirst(1))
            if !newPartWords.isEmpty {
                let newPart = newPartWords.joined(separator: " ")
                return accumulated + " " + newPart
            }
        }
        
        return nil
    }
    
    private func isLikelyCorrection(accumulated: String, new: String) -> Bool {
        let accumulatedLower = accumulated.lowercased()
        let newLower = new.lowercased()
        
        if newLower.hasPrefix(accumulatedLower) && new.count > accumulated.count {
            if accumulated.count <= 5 {
                return true
            }
        }
        
        if accumulated.count <= 6 && newLower.hasPrefix(accumulatedLower) {
            let newPart = String(newLower.dropFirst(accumulatedLower.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !newPart.isEmpty && newPart.count >= 2 {
                return true
            }
        }
        
        let accumulatedWords = accumulated.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let newWords = new.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        if !accumulatedWords.isEmpty && !newWords.isEmpty {
            let lastAccumulatedWords = Array(accumulatedWords.suffix(min(3, accumulatedWords.count)))
            let firstNewWords = Array(newWords.prefix(min(3, newWords.count)))
            
            if lastAccumulatedWords.count == firstNewWords.count && lastAccumulatedWords == firstNewWords {
                if new.count <= accumulated.count {
                    return true
                }
            }
        }
        
        if new.count < accumulated.count / 2 {
            let accumulatedWordsSet = Set(accumulated.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
            let newWordsSet = Set(new.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
            
            if !newWordsSet.isEmpty {
                let commonWords = accumulatedWordsSet.intersection(newWordsSet)
                let similarity = Double(commonWords.count) / Double(newWordsSet.count)
                if similarity > 0.5 {
                    return true
                }
            }
        }
        
        if accumulatedLower.contains(newLower) && new.count < Int(Double(accumulated.count) * 0.7) {
            return true
        }
        
        if !accumulatedWords.isEmpty && !newWords.isEmpty {
            let accumulatedSet = Set(accumulatedWords)
            let newSet = Set(newWords)
            let commonWords = accumulatedSet.intersection(newSet)
            
            if commonWords.count >= 2 {
                let similarity = Double(commonWords.count) / Double(max(accumulatedWords.count, newWords.count))
                if similarity > 0.6 {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func hasInternalDuplicates(in text: String) -> Bool {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard words.count >= 2 else { return false }
        
        let normalizedWords = words.map { normalizeWord($0) }
        var seenWords = Set<String>()
        
        for word in normalizedWords {
            if seenWords.contains(word) {
                return true
            }
            seenWords.insert(word)
        }
        
        if words.count >= 4 {
            for phraseLen in stride(from: min(5, words.count / 2), through: 2, by: -1) {
                for i in 0..<(words.count - phraseLen * 2 + 1) {
                    let phrase1 = Array(normalizedWords[i..<i + phraseLen])
                    let phrase2 = Array(normalizedWords[i + phraseLen..<min(i + phraseLen * 2, normalizedWords.count)])
                    
                    if phrase1.count == phraseLen && phrase2.count == phraseLen && phrase1 == phrase2 {
                        return true
                    }
                }
            }
        }
        
        let longWords = normalizedWords.filter { $0.count >= 6 }
        var seenLongWords = Set<String>()
        for word in longWords {
            if seenLongWords.contains(word) {
                return true
            }
            seenLongWords.insert(word)
        }
        
        if words.count >= 6 {
            for phraseLen in stride(from: min(5, words.count / 2), through: 2, by: -1) {
                var seenPhrases: [String] = []
                for i in 0..<(words.count - phraseLen + 1) {
                    let phrase = Array(normalizedWords[i..<i + phraseLen]).joined(separator: " ")
                    if seenPhrases.contains(phrase) {
                        return true
                    }
                    seenPhrases.append(phrase)
                }
            }
        }
        
        return false
    }
    
    private func hasDuplicateWords(accumulated: String, new: String) -> Bool {
        let accumulatedWords = accumulated.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let newWords = new.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        guard !accumulatedWords.isEmpty && !newWords.isEmpty else { return false }
        
        let normalizedAccumulatedWords = accumulatedWords.map { normalizeWord($0) }
        let normalizedNewWords = newWords.map { normalizeWord($0) }
        
        let accumulatedSet = Set(normalizedAccumulatedWords)
        let newSet = Set(normalizedNewWords)
        
        let newUniqueWords = newSet.subtracting(accumulatedSet)
        let hasNewContent = !newUniqueWords.isEmpty
        
        if newSet.isSubset(of: accumulatedSet) && !hasNewContent && newWords.count > 0 {
            return true
        }
        
        if hasNewContent && newUniqueWords.count >= newWords.count / 2 {
            return false
        }
        
        let lastAccumulatedWords = Array(normalizedAccumulatedWords.suffix(min(10, normalizedAccumulatedWords.count)))
        let firstNewWords = Array(normalizedNewWords.prefix(min(10, normalizedNewWords.count)))
        
        var duplicateCount = 0
        for accWord in lastAccumulatedWords {
            for newWord in firstNewWords {
                if accWord == newWord {
                    duplicateCount += 1
                }
            }
        }
        
        let longAccumulatedWords = lastAccumulatedWords.filter { $0.count >= 5 }
        let longNewWords = firstNewWords.filter { $0.count >= 5 }
        let longDuplicateCount = longAccumulatedWords.filter { longNewWords.contains($0) }.count
        
        if longDuplicateCount >= 1 {
            return true
        }
        
        if duplicateCount >= 2 {
            return true
        }
        
        if duplicateCount >= 1 {
            let mediumDuplicateCount = lastAccumulatedWords.filter { $0.count >= 4 }.filter { firstNewWords.contains($0) }.count
            if mediumDuplicateCount >= 1 {
                return true
            }
        }
        
        if duplicateCount == 1 && hasNewContent {
            if newUniqueWords.count <= 1 {
                return true
            }
            return false
        }
        
        if duplicateCount == 1 && newWords.count <= 4 && !hasNewContent {
            return true
        }
        
        let duplicates = accumulatedSet.intersection(newSet)
        
        if duplicates.count == newWords.count && newWords.count > 0 && !hasNewContent {
            return true
        }
        
        if duplicates.count >= newWords.count * 4 / 5 && newWords.count <= 5 && !hasNewContent {
            return true
        }
        
        if lastAccumulatedWords.count >= 2 && firstNewWords.count >= 2 {
            let lastPhrase = Array(lastAccumulatedWords.suffix(2)).joined(separator: " ")
            let firstPhrase = Array(firstNewWords.prefix(2)).joined(separator: " ")
            
            if lastPhrase == firstPhrase && !hasNewContent {
                return true
            }
        }
        
        if lastAccumulatedWords.count >= 3 && firstNewWords.count >= 3 {
            let lastPhrase = Array(lastAccumulatedWords.suffix(3)).joined(separator: " ")
            let firstPhrase = Array(firstNewWords.prefix(3)).joined(separator: " ")
            
            if lastPhrase == firstPhrase && !hasNewContent {
                return true
            }
            
            let lastPhraseWords = Set(Array(lastAccumulatedWords.suffix(3)))
            let firstPhraseWords = Set(Array(firstNewWords.prefix(3)))
            if lastPhraseWords.intersection(firstPhraseWords).count >= 3 && !hasNewContent {
                return true
            }
        }
        
        let accumulatedText = normalizedAccumulatedWords.joined(separator: " ")
        let newText = normalizedNewWords.joined(separator: " ")
        
        if accumulatedText.count > 10 && newText.count > 10 && newText.count <= accumulatedText.count {
            let commonLength = commonSubstringLength(accumulatedText, newText)
            if commonLength >= accumulatedText.count * 7 / 10 && !hasNewContent {
                return true
            }
        }
        
        return false
    }
    
    private func commonSubstringLength(_ str1: String, _ str2: String) -> Int {
        let s1 = str1.lowercased()
        let s2 = str2.lowercased()
        var maxLen = 0
        
        for i in 0..<s1.count {
            for j in 0..<s2.count {
                var len = 0
                var iIdx = s1.index(s1.startIndex, offsetBy: i)
                var jIdx = s2.index(s2.startIndex, offsetBy: j)
                
                while iIdx < s1.endIndex && jIdx < s2.endIndex && s1[iIdx] == s2[jIdx] {
                    len += 1
                    iIdx = s1.index(after: iIdx)
                    jIdx = s2.index(after: jIdx)
                }
                
                maxLen = max(maxLen, len)
            }
        }
        
        return maxLen
    }
    
    private func normalizeWords(_ words: [String]) -> [String] {
        return words.map { normalizeWord($0) }
    }
    
    private func areWordsRelated(_ word1: String, _ word2: String) -> Bool {
        let w1 = normalizeWord(word1)
        let w2 = normalizeWord(word2)
        
        if w1 == w2 { return true }
        if w1.count >= 3 && w2.hasPrefix(w1) { return true }
        if w2.count >= 3 && w1.hasPrefix(w2) { return true }
        
        let minLen = min(w1.count, w2.count)
        if minLen >= 3 {
            let commonPrefix = w1.commonPrefix(with: w2)
            if commonPrefix.count >= max(3, minLen - 2) {
                return true
            }
            
            let similarity = calculateSimilarity(w1, w2)
            if similarity >= 0.75 {
                return true
            }
        }
        
        return false
    }
    
    private func calculateSimilarity(_ word1: String, _ word2: String) -> Double {
        let len1 = word1.count
        let len2 = word2.count
        
        if len1 == 0 && len2 == 0 { return 1.0 }
        if len1 == 0 || len2 == 0 { return 0.0 }
        
        let commonPrefix = word1.commonPrefix(with: word2).count
        let reversed1 = String(word1.reversed())
        let reversed2 = String(word2.reversed())
        let commonSuffix = reversed1.commonPrefix(with: reversed2).count
        
        let maxLen = max(len1, len2)
        let similarity = Double(commonPrefix + commonSuffix) / Double(maxLen * 2)
        
        return min(1.0, similarity)
    }
    
    private func commonPrefixLength(_ str1: String, _ str2: String) -> Int {
        let s1 = str1.lowercased()
        let s2 = str2.lowercased()
        let minLen = min(s1.count, s2.count)
        
        for i in 0..<minLen {
            let idx1 = s1.index(s1.startIndex, offsetBy: i)
            let idx2 = s2.index(s2.startIndex, offsetBy: i)
            if s1[idx1] != s2[idx2] {
                return i
            }
        }
        
        return minLen
    }
    
    struct CorruptionAnalysis {
        let isCorrupted: Bool
        let reasons: [String]
    }
    
    func analyzeTextCorruption(_ words: [String]) -> CorruptionAnalysis {
        guard words.count >= 2 else {
            return CorruptionAnalysis(isCorrupted: false, reasons: [])
        }
        
        var reasons: [String] = []
        var isCorrupted = false
        
        let hasLongGluedWords = words.contains { word in
            word.count > 15 && !word.contains(" ")
        }
        if hasLongGluedWords {
            isCorrupted = true
            reasons.append("длинные склеенные слова")
        }
        
        let hasCommasInsideWords = words.contains { word in
            word.contains(",") && word.count > 5
        }
        if hasCommasInsideWords {
            isCorrupted = true
            reasons.append("запятые внутри слов")
        }
        
        let hasSingleLettersInMiddle = {
            if words.count >= 3 {
                for i in 1..<(words.count - 1) {
                    let word = words[i]
                    if word.count == 1 && !["а", "и", "о", "у", "в", "к", "с", "я"].contains(word.lowercased()) {
                        return true
                    }
                }
            }
            return false
        }()
        if hasSingleLettersInMiddle {
            isCorrupted = true
            reasons.append("одиночные буквы в середине")
        }
        
        let hasManyShortWords = {
            var consecutiveShort = 0
            var maxConsecutive = 0
            for word in words {
                if word.count <= 4 {
                    consecutiveShort += 1
                    maxConsecutive = max(maxConsecutive, consecutiveShort)
                } else {
                    consecutiveShort = 0
                }
            }
            return maxConsecutive >= 2
        }()
        if hasManyShortWords {
            isCorrupted = true
            reasons.append("много коротких слов подряд")
        }
        
        let hasCombinableWords = {
            if words.count >= 2 {
                for startIndex in 0..<(words.count - 1) {
                    for length in 2...min(4, words.count - startIndex) {
                        let wordsToCombine = Array(words[startIndex..<startIndex + length])
                        let combined = wordsToCombine.joined(separator: "")
                        
                        if combined.count >= 6 {
                            let vowels = CharacterSet(charactersIn: "аеёиоуыэюя")
                            if combined.lowercased().rangeOfCharacter(from: vowels) != nil {
                                let allPartsShort = wordsToCombine.allSatisfy { $0.count <= 5 }
                                if allPartsShort {
                                    return true
                                }
                            }
                        }
                    }
                }
            }
            return false
        }()
        if hasCombinableWords {
            isCorrupted = true
            reasons.append("разбитые слова (можно объединить)")
        }
        
        let hasMixedPatterns = {
            let shortWordsCount = words.filter { $0.count <= 4 }.count
            let longWordsCount = words.filter { $0.count > 12 }.count
            return shortWordsCount >= 2 && longWordsCount >= 1
        }()
        if hasMixedPatterns {
            isCorrupted = true
            reasons.append("смешанные паттерны")
        }
        
        let hasWordsWithoutVowels = words.contains { word in
            let vowels = CharacterSet(charactersIn: "аеёиоуыэюя")
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            return cleaned.count >= 4 && cleaned.lowercased().rangeOfCharacter(from: vowels) == nil
        }
        if hasWordsWithoutVowels {
            isCorrupted = true
            reasons.append("слова без гласных")
        }
        
        let hasIncorrectSpaces = {
            for word in words {
                if word.count <= 3 {
                    let validShortWords = ["а", "и", "о", "у", "в", "к", "с", "я", "на", "за", "от", "до", "по", "со", "во", "об", "про", "под", "над", "при", "без", "для", "из", "не", "но", "да", "или", "что", "как", "где", "когда", "чем", "чем", "куда", "откуда"]
                    if !validShortWords.contains(word.lowercased()) {
                        if let index = words.firstIndex(of: word), index > 0 && index < words.count - 1 {
                            let prevWord = words[index - 1]
                            let nextWord = words[index + 1]
                            let combined = prevWord + word + nextWord
                            if combined.count >= 6 {
                                let vowels = CharacterSet(charactersIn: "аеёиоуыэюя")
                                if combined.lowercased().rangeOfCharacter(from: vowels) != nil {
                                    return true
                                }
                            }
                        }
                    }
                }
            }
            return false
        }()
        if hasIncorrectSpaces {
            isCorrupted = true
            reasons.append("неправильные пробелы")
        }
        
        let hasCapitalInMiddle = words.contains { word in
            if word.count > 3 {
                let middleStart = word.index(word.startIndex, offsetBy: 1)
                let middleEnd = word.index(word.endIndex, offsetBy: -1)
                let middle = String(word[middleStart..<middleEnd])
                return middle.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil
            }
            return false
        }
        if hasCapitalInMiddle {
            isCorrupted = true
            reasons.append("заглавные буквы в середине слов")
        }
        
        let hasSuspiciousPattern = {
            if words.count >= 4 {
                let lengthGroups = Dictionary(grouping: words, by: { $0.count })
                let maxGroupSize = lengthGroups.values.map { $0.count }.max() ?? 0
                if maxGroupSize >= 3 {
                    let suspiciousLengths = lengthGroups.filter { $0.key <= 3 && $0.value.count >= 3 }
                    if !suspiciousLengths.isEmpty {
                        return true
                    }
                }
            }
            return false
        }()
        if hasSuspiciousPattern {
            isCorrupted = true
            reasons.append("подозрительный паттерн повторений")
        }
        
        let hasGluedWords = {
            for word in words {
                if word.count >= 8 {
                    let firstChar = word.prefix(1)
                    let rest = String(word.dropFirst())
                    if firstChar.first?.isUppercase == true && rest.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil {
                        return true
                    }
                    if word.count >= 12 {
                        return true
                    }
                }
            }
            return false
        }()
        if hasGluedWords {
            isCorrupted = true
            reasons.append("склеенные слова без пробелов")
        }
        
        let hasNumbersInWords = words.contains { word in
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            return cleaned.count >= 4 && cleaned.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
        }
        if hasNumbersInWords {
            isCorrupted = true
            reasons.append("цифры внутри слов")
        }
        
        let hasTooManyShortWords = {
            if words.count >= 4 {
                let shortWordsCount = words.filter { $0.count <= 3 }.count
                let shortWordsRatio = Double(shortWordsCount) / Double(words.count)
                return shortWordsRatio >= 0.5
            }
            return false
        }()
        if hasTooManyShortWords {
            isCorrupted = true
            reasons.append("слишком много коротких слов")
        }
        
        return CorruptionAnalysis(isCorrupted: isCorrupted, reasons: reasons)
    }
}
