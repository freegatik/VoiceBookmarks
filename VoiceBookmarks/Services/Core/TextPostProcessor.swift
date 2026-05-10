//
//  TextPostProcessor.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

class TextPostProcessor {
    
    func process(_ text: String) -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return text
        }
        
        var processed = text
        processed = removeAllDuplicates(in: processed)
        processed = fixCommonErrors(in: processed)
        processed = removeAllDuplicates(in: processed)
        processed = addPunctuation(to: processed)
        processed = capitalizeSentences(in: processed)
        processed = normalizeWhitespace(in: processed)
        processed = removeAllDuplicates(in: processed)
        
        return processed
    }
    
    func applyBasicPostProcessing(_ text: String) -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return text
        }
        
        var processed = text
        processed = fixCommonErrors(in: processed)
        processed = normalizeWhitespace(in: processed)
        
        return processed
    }
    
    func addPunctuation(to text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return text }
        
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " .", with: ".")
        result = result.replacingOccurrences(of: " !", with: "!")
        result = result.replacingOccurrences(of: " ?", with: "?")
        result = result.replacingOccurrences(of: " :", with: ":")
        result = result.replacingOccurrences(of: " ;", with: ";")
        
        result = addCommasBeforeConjunctions(in: result)
        result = addCommasBeforeIntroductoryWords(in: result)
        result = addCommasInComplexSentences(in: result)
        result = addCommasInEnumerations(in: result)
        result = addCommasInDirectSpeech(in: result)
        result = addPeriodsAtSentenceEnds(in: result)
        result = addDashes(in: result)
        result = addColons(in: result)
        result = addQuestionMarks(in: result)
        result = addExclamationMarks(in: result)
        
        let lastChar = result.last
        if lastChar != nil && !".!?".contains(lastChar!) {
            result += "."
        }
        
        result = normalizeWhitespace(in: result)
        return result
    }
    
    func fixCommonErrors(in text: String) -> String {
        var result = text
        
        result = fixDotsAndSpacesInWords(in: result)
        
        result = fixGluedWords(in: result)
        result = fixBrokenWords(in: result)
        result = fixMergedWords(in: result)
        result = fixWordBreaks(in: result)
        result = fixCommonSpellingErrors(in: result)
        result = processNumbers(in: result)
        result = processAbbreviations(in: result)
        result = fixWordRepetitions(in: result)
        result = addSpacesBetweenWords(in: result)
        result = normalizeWhitespace(in: result)
        return result
    }
    
    private func fixDotsAndSpacesInWords(in text: String) -> String {
        var result = text
        
        result = result.replacingOccurrences(of: "([а-яёА-ЯЁ]) ([а-яёА-ЯЁ])", with: "$1$2", options: .regularExpression)
        result = result.replacingOccurrences(of: "([а-яё])\\.([А-ЯЁ])", with: "$1$2", options: .regularExpression)
        result = result.replacingOccurrences(of: "([а-яё])\\. ([А-ЯЁ])", with: "$1$2", options: .regularExpression)
        
        let longWordPattern = "([а-яА-ЯёЁ]{10,})"
        if let regex = try? NSRegularExpression(pattern: longWordPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 1 {
                    let fullRange = match.range(at: 0)
                    if let fullSwiftRange = Range(fullRange, in: result) {
                        let word = String(result[fullSwiftRange])
                        
                        for splitPoint in stride(from: min(word.count - 4, 15), through: 4, by: -1) {
                            let firstPart = String(word.prefix(splitPoint))
                            let secondPart = String(word.dropFirst(splitPoint))
                            
                            if isValidRussianWord(firstPart) && isValidRussianWord(secondPart) &&
                               firstPart.count >= 4 && secondPart.count >= 4 {
                                let replacement = "\(firstPart) \(secondPart)"
                                result.replaceSubrange(fullSwiftRange, with: replacement)
                                break
                            }
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func fixBrokenWords(in text: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        guard words.count >= 2 else { return text }
        
        var fixedWords: [String] = []
        var i = 0
        
        while i < words.count {
            let currentWord = words[i]
            
            if currentWord.count <= 4 && i + 1 < words.count {
                var combined = currentWord
                var j = i + 1
                var combinedWords: [String] = [currentWord]
                
                while j < words.count && words[j].count <= 5 && combinedWords.count < 5 {
                    let nextWord = words[j]
                    let testCombined = combined + nextWord
                    
                    if isValidRussianWord(testCombined) {
                        combined = testCombined
                        combinedWords.append(nextWord)
                        j += 1
                    } else {
                        if combinedWords.count >= 2 && combined.count >= 5 && isValidRussianWord(combined) {
                            break
                        }
                        if combinedWords.count < 4 {
                            combined = testCombined
                            combinedWords.append(nextWord)
                            j += 1
                        } else {
                            break
                        }
                    }
                }
                
                if combinedWords.count >= 2 && combined.count >= 5 {
                    if isValidRussianWord(combined) {
                        fixedWords.append(combined)
                        i = j
                        continue
                    }
                }
            }
            
            fixedWords.append(currentWord)
            i += 1
        }
        
        var finalWords: [String] = []
        i = 0
        
        while i < fixedWords.count {
            let currentWord = fixedWords[i]
            
            if currentWord.contains("-") && currentWord.count <= 6 && i + 1 < fixedWords.count {
                let withoutDash = currentWord.replacingOccurrences(of: "-", with: "")
                let combined = withoutDash + fixedWords[i + 1]
                
                if isValidRussianWord(combined) {
                    finalWords.append(combined)
                    i += 2
                    continue
                }
            }
            
            finalWords.append(currentWord)
            i += 1
        }
        
        return finalWords.joined(separator: " ")
    }
    
    private func addSpacesBetweenWords(in text: String) -> String {
        var result = text
        
        guard !result.isEmpty else { return result }
        
        result = result.replacingOccurrences(of: "([а-яё])\\.([А-ЯЁ])", with: "$1$2", options: .regularExpression)
        result = result.replacingOccurrences(of: "([а-яё])\\. ([А-ЯЁ])", with: "$1$2", options: .regularExpression)
        result = result.replacingOccurrences(of: "([а-яё]) ([а-яё])", with: "$1$2", options: .regularExpression)
        
        let pattern1 = "([а-яё])([А-ЯЁ])"
        if let regex = try? NSRegularExpression(pattern: pattern1, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1 $2"
            )
        }
        
        let pattern2 = "([а-яА-ЯёЁ]{4,})([а-яА-ЯёЁ]{1,3})([а-яА-ЯёЁ]{4,})"
        if let regex = try? NSRegularExpression(pattern: pattern2, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 4 {
                    let fullRange = match.range(at: 0)
                    let part1Range = match.range(at: 1)
                    let part2Range = match.range(at: 2)
                    let part3Range = match.range(at: 3)
                    
                    if let fullSwiftRange = Range(fullRange, in: result),
                       let part1SwiftRange = Range(part1Range, in: result),
                       let part2SwiftRange = Range(part2Range, in: result),
                       let part3SwiftRange = Range(part3Range, in: result) {
                        let part1 = String(result[part1SwiftRange])
                        let part2 = String(result[part2SwiftRange])
                        let part3 = String(result[part3SwiftRange])
                        
                        if isValidRussianWord(part1) && isValidRussianWord(part3) {
                            let replacement = "\(part1) \(part2) \(part3)"
                            result.replaceSubrange(fullSwiftRange, with: replacement)
                        }
                    }
                }
            }
        }
        
        let pattern3 = "([а-яА-ЯёЁ]{8,})"
        if let regex = try? NSRegularExpression(pattern: pattern3, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 1 {
                    let fullRange = match.range(at: 0)
                    
                    if let fullSwiftRange = Range(fullRange, in: result) {
                        let word = String(result[fullSwiftRange])
                        
                        if let splitPoint = findWordSplitPoint(word) {
                            let part1 = String(word.prefix(splitPoint))
                            let part2 = String(word.suffix(word.count - splitPoint))
                            
                            if isValidRussianWord(part1) && isValidRussianWord(part2) {
                                let replacement = "\(part1) \(part2)"
                                result.replaceSubrange(fullSwiftRange, with: replacement)
                            }
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    func capitalizeSentences(in text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return text }
        
        let sentenceEndings = CharacterSet(charactersIn: ".!?")
        let sentences = result.components(separatedBy: sentenceEndings)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !sentences.isEmpty else { return text }
        
        let capitalizedSentences = sentences.map { sentence -> String in
            guard !sentence.isEmpty else { return sentence }
            let firstChar = sentence.prefix(1).uppercased()
            let rest = String(sentence.dropFirst())
            return firstChar + rest
        }
        
        result = capitalizedSentences.joined(separator: ". ")
        
        if !result.isEmpty {
            let firstChar = result.prefix(1).uppercased()
            let rest = String(result.dropFirst())
            result = firstChar + rest
        }
        
        return result
    }
    
    private func addCommasBeforeConjunctions(in text: String) -> String {
        var result = text
        
        let conjunctions = [
            "но", "а", "однако", "хотя", "потому что", "так как",
            "чтобы", "что", "если", "когда", "где", "куда",
            "откуда", "как", "чем", "пока", "пока не", "с тех пор как",
            "так что", "хотя бы", "даже если", "не только", "но и",
            "а также", "то есть", "в то время как", "после того как",
            "прежде чем", "для того чтобы", "с тем чтобы", "несмотря на то что",
            "в связи с тем что", "ввиду того что", "благодаря тому что",
            "из-за того что", "вследствие того что", "в результате того что",
            "в случае если", "при условии что", "при том что", "кроме того что",
            "вместо того чтобы", "затем чтобы", "ради того чтобы", "с той целью чтобы"
        ]
        
        guard !result.isEmpty else { return result }
        
        for conjunction in conjunctions {
            let escaped = NSRegularExpression.escapedPattern(for: conjunction)
            let pattern = "([а-яА-ЯёЁ]+)\\s+(\(escaped))\\s+"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                let matches = regex.matches(in: result, options: [], range: range)
                
                for match in matches.reversed() {
                    if match.range.location > 0 {
                        let beforeIndex = result.index(result.startIndex, offsetBy: match.range.location - 1)
                        let beforeChar = result[beforeIndex]
                        if beforeChar != "," && beforeChar != "." && beforeChar != "!" && beforeChar != "?" {
                            result = regex.stringByReplacingMatches(
                                in: result,
                                options: [],
                                range: match.range,
                                withTemplate: "$1 , $2 "
                            )
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func addCommasBeforeIntroductoryWords(in text: String) -> String {
        var result = text
        
        let introductoryWords = [
            "вроде", "кажется", "возможно", "наверное", "конечно", "конечно же",
            "вероятно", "видимо", "очевидно", "безусловно", "несомненно",
            "кстати", "между прочим", "во-первых", "во-вторых", "в-третьих",
            "однако", "тем не менее", "впрочем", "итак", "значит", "следовательно",
            "таким образом", "кроме того", "более того", "в частности", "например",
            "вообще", "вообще-то", "в общем", "в общем-то", "в принципе",
            "по сути", "по существу", "в сущности", "по правде", "по правде говоря",
            "к сожалению", "к счастью", "к несчастью", "к удивлению", "к радости"
        ]
        
        guard !result.isEmpty else { return result }
        
        for word in introductoryWords {
            let escaped = NSRegularExpression.escapedPattern(for: word)
            let pattern = "([а-яА-ЯёЁ])\\s+(\(escaped))\\s+"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                let matches = regex.matches(in: result, options: [], range: range)
                
                for match in matches.reversed() {
                    if match.range.location > 0 {
                        let beforeIndex = result.index(result.startIndex, offsetBy: match.range.location - 1)
                        let beforeChar = result[beforeIndex]
                        if beforeChar != "," && beforeChar != " " {
                            result = regex.stringByReplacingMatches(
                                in: result,
                                options: [],
                                range: match.range,
                                withTemplate: "$1 , $2 "
                            )
                        }
                    }
                }
            }
            
            let startPattern = "^\\s*(\(NSRegularExpression.escapedPattern(for: word)))\\s+"
            if let regex = try? NSRegularExpression(pattern: startPattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                if let match = regex.firstMatch(in: result, options: [], range: range) {
                    let matchRange = Range(match.range, in: result)!
                    if matchRange.upperBound < result.endIndex {
                        let afterIndex = result.index(matchRange.upperBound, offsetBy: 0)
                        let afterText = String(result[afterIndex...]).prefix(2)
                        if !afterText.hasPrefix(", ") {
                            result = regex.stringByReplacingMatches(
                                in: result,
                                options: [],
                                range: match.range,
                                withTemplate: "$1 , "
                            )
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func addCommasInComplexSentences(in text: String) -> String {
        var result = text
        
        var patterns: [(String, String)] = [
            ("([а-яА-ЯёЁ]+)\\s+который\\s+", "$1 , который "),
            ("([а-яА-ЯёЁ]+)\\s+которая\\s+", "$1 , которая "),
            ("([а-яА-ЯёЁ]+)\\s+которое\\s+", "$1 , которое "),
            ("([а-яА-ЯёЁ]+)\\s+которые\\s+", "$1 , которые "),
            ("([а-яА-ЯёЁ]+)\\s+которым\\s+", "$1 , которым "),
            ("([а-яА-ЯёЁ]+)\\s+которой\\s+", "$1 , которой "),
            ("([а-яА-ЯёЁ]+)\\s+которого\\s+", "$1 , которого "),
            ("([а-яА-ЯёЁ]+)\\s+которую\\s+", "$1 , которую ")
        ]
        
        let participlePatterns = [
            ("([а-яА-ЯёЁ]+)\\s+([а-яА-ЯёЁ]+(?:щий|щая|щее|щие|вший|вшая|вшее|вшие|нный|нная|нное|нные))\\s+", "$1 , $2 "),
            ("([а-яА-ЯёЁ]+)\\s+([а-яА-ЯёЁ]+(?:щий|щая|щее|щие|вший|вшая|вшее|вшие|нный|нная|нное|нные)\\s+[а-яА-ЯёЁ]+)\\s+", "$1 , $2 ")
        ]
        patterns.append(contentsOf: participlePatterns)
        
        let adverbialPatterns = [
            ("([а-яА-ЯёЁ]+)\\s+([а-яА-ЯёЁ]+(?:я|в|вши|вшись))\\s+", "$1 , $2 "),
            ("([а-яА-ЯёЁ]+)\\s+([а-яА-ЯёЁ]+(?:я|в|вши|вшись)\\s+[а-яА-ЯёЁ]+)\\s+", "$1 , $2 ")
        ]
        patterns.append(contentsOf: adverbialPatterns)
        
        guard !result.isEmpty else { return result }
        
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                let matches = regex.matches(in: result, options: [], range: range)
                
                for match in matches.reversed() {
                    if match.range.location > 0 {
                        let beforeIndex = result.index(result.startIndex, offsetBy: match.range.location - 1)
                        let beforeChar = result[beforeIndex]
                        if beforeChar != "," {
                            result = regex.stringByReplacingMatches(
                                in: result,
                                options: [],
                                range: match.range,
                                withTemplate: replacement
                            )
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func addPeriodsAtSentenceEnds(in text: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard words.count > 1 else { return text }
        
        var fixedWords: [String] = []
        var currentPhraseLength = 0
        var currentPhraseWords: [String] = []
        let maxPhraseLength = 25

        
        for (index, word) in words.enumerated() {
            let cleanedWord = word.trimmingCharacters(in: .punctuationCharacters)
            let wordLength = cleanedWord.count
            currentPhraseLength += wordLength + 1
            currentPhraseWords.append(word)
            
            let hasPunctuation = word.last != nil && ".!?".contains(word.last!)
            
            let shouldAddPeriod = !hasPunctuation && (
                (currentPhraseLength > maxPhraseLength) ||
                (index < words.count - 1 && words[index + 1].trimmingCharacters(in: .punctuationCharacters).first?.isUppercase == true) ||
                (index == words.count - 1) ||
                (hasSentenceEndMarker(words: currentPhraseWords))
            )
            
            if shouldAddPeriod {
                let hasCompleteStructure = hasCompleteSentenceStructure(words: currentPhraseWords)
                
                if hasCompleteStructure || index == words.count - 1 || currentPhraseLength > maxPhraseLength {
                    if let lastIndex = fixedWords.indices.last {
                        let lastWord = fixedWords[lastIndex]
                        if !lastWord.hasSuffix(".") && !lastWord.hasSuffix("!") && !lastWord.hasSuffix("?") {
                            fixedWords[lastIndex] = lastWord + "."
                            currentPhraseLength = 0
                            currentPhraseWords = []
                        }
                    }
                }
            } else if hasPunctuation {
                currentPhraseLength = 0
                currentPhraseWords = []
            }
            
            fixedWords.append(word)
        }
        
        return fixedWords.joined(separator: " ")
    }
    
    private func hasSentenceEndMarker(words: [String]) -> Bool {
        let text = words.joined(separator: " ").lowercased()
        let markers = [
            "завершено", "закончено", "готово", "все", "вот", "так", "итак",
            "поэтому", "следовательно", "значит", "таким образом",
            "в итоге", "в результате", "в конце концов"
        ]
        return markers.contains { text.hasSuffix($0) || text.contains(" \($0) ") }
    }
    
    private func fixWordBreaks(in text: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard words.count >= 2 else { return text }
        
        var fixedWords: [String] = []
        var i = 0
        
        while i < words.count {
            let currentWord = words[i]
            
            if let combined = tryCombineWords(words: words, startIndex: i, maxParts: 5) {
                fixedWords.append(combined.word)
                i += combined.partsCount
                continue
            }
            
            if i + 1 < words.count {
                let nextWord = words[i + 1]
                let testCombined = currentWord + nextWord
                
                if isValidRussianWord(testCombined) && currentWord.count <= 6 && nextWord.count <= 5 {
                    fixedWords.append(testCombined)
                    i += 2
                    continue
                }
            }
            
            fixedWords.append(currentWord)
            i += 1
        }
        
        return fixedWords.joined(separator: " ")
    }
    
    private func fixGluedWords(in text: String) -> String {
        var result = text
        
        guard !result.isEmpty else { return result }
        
        result = result.replacingOccurrences(of: " ([а-яё])", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "([а-яё])\\.([А-ЯЁ])", with: "$1$2", options: .regularExpression)
        result = result.replacingOccurrences(of: "([а-яё])\\. ([А-ЯЁ])", with: "$1$2", options: .regularExpression)
        
        let pattern1 = "([а-яА-ЯёЁ]{3,})([А-ЯЁ][а-яА-ЯёЁ]{2,})"
        if let regex = try? NSRegularExpression(pattern: pattern1, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1 $2"
            )
        }
        
        let pattern2 = "([а-яА-ЯёЁ]{3,})([а-яё][а-яА-ЯёЁ]{2,})"
        if let regex = try? NSRegularExpression(pattern: pattern2, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 3 {
                    let fullRange = match.range(at: 0)
                    let part1Range = match.range(at: 1)
                    let part2Range = match.range(at: 2)
                    
                    if let fullSwiftRange = Range(fullRange, in: result),
                       let part1SwiftRange = Range(part1Range, in: result),
                       let part2SwiftRange = Range(part2Range, in: result) {
                        let part1 = String(result[part1SwiftRange])
                        let part2 = String(result[part2SwiftRange])
                        
                        if isValidRussianWord(part1) && isValidRussianWord(part2) {
                            let replacement = "\(part1) \(part2)"
                            result.replaceSubrange(fullSwiftRange, with: replacement)
                        }
                    }
                }
            }
        }
        
        let pattern3 = "([а-яА-ЯёЁ]{2,3})([а-яА-ЯёЁ]{4,})"
        if let regex = try? NSRegularExpression(pattern: pattern3, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 3 {
                    let fullRange = match.range(at: 0)
                    let part1Range = match.range(at: 1)
                    let part2Range = match.range(at: 2)
                    
                    if let fullSwiftRange = Range(fullRange, in: result),
                       let part1SwiftRange = Range(part1Range, in: result),
                       let part2SwiftRange = Range(part2Range, in: result) {
                        let part1 = String(result[part1SwiftRange])
                        let part2 = String(result[part2SwiftRange])
                        
                        if isValidRussianWord(part1) && isValidRussianWord(part2) {
                            let replacement = "\(part1) \(part2)"
                            result.replaceSubrange(fullSwiftRange, with: replacement)
                        }
                    }
                }
            }
        }
        
        let pattern4 = "([а-яА-ЯёЁ]{4,})([а-яА-ЯёЁ]{1,3})([а-яА-ЯёЁ]{4,})"
        if let regex = try? NSRegularExpression(pattern: pattern4, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 4 {
                    let fullRange = match.range(at: 0)
                    let part1Range = match.range(at: 1)
                    let part2Range = match.range(at: 2)
                    let part3Range = match.range(at: 3)
                    
                    if let fullSwiftRange = Range(fullRange, in: result),
                       let part1SwiftRange = Range(part1Range, in: result),
                       let part2SwiftRange = Range(part2Range, in: result),
                       let part3SwiftRange = Range(part3Range, in: result) {
                        let part1 = String(result[part1SwiftRange])
                        let part2 = String(result[part2SwiftRange])
                        let part3 = String(result[part3SwiftRange])
                        
                        if isValidRussianWord(part1) && isValidRussianWord(part2) && isValidRussianWord(part3) {
                            let replacement = "\(part1) \(part2) \(part3)"
                            result.replaceSubrange(fullSwiftRange, with: replacement)
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func tryCombineWords(words: [String], startIndex: Int, maxParts: Int) -> (word: String, partsCount: Int)? {
        guard startIndex < words.count else { return nil }
        
        let maxPartsCount = min(maxParts, words.count - startIndex)
        guard maxPartsCount >= 2 else { return nil }
        
        for partsCount in 2...maxPartsCount {
            let endIndex = startIndex + partsCount
            guard endIndex <= words.count else { continue }
            let wordsToCombine = Array(words[startIndex..<endIndex])
            let combined = wordsToCombine.joined(separator: "")
            
            if isValidRussianWord(combined) {
                let allPartsValid = wordsToCombine.allSatisfy { isValidRussianWord($0) }
                let anyPartInvalid = wordsToCombine.contains { !isValidRussianWord($0) }
                
                if anyPartInvalid || (!allPartsValid && combined.count <= 20) {
                    return (combined, partsCount)
                }
            }
        }
        
        return nil
    }
    
    private func fixMergedWords(in text: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var fixedWords: [String] = []
        
        for word in words {
            if word.count > 12 {
                var foundSplit = false
                
                for splitPoint in stride(from: min(word.count - 4, 20), through: 4, by: -1) {
                    let firstPart = String(word.prefix(splitPoint))
                    let secondPart = String(word.dropFirst(splitPoint))
                    
                    if isValidRussianWord(firstPart) && isValidRussianWord(secondPart) &&
                       firstPart.count >= 3 && secondPart.count >= 3 {
                        fixedWords.append(firstPart)
                        fixedWords.append(secondPart)
                        foundSplit = true
                        break
                    }
                }
                
                if foundSplit {
                    continue
                }
                
                if word.count > 20 {
                    if let splitPoint = findWordSplitPoint(word) {
                        let firstPart = String(word.prefix(splitPoint))
                        let secondPart = String(word.dropFirst(splitPoint))
                        
                        if isValidRussianWord(firstPart) && isValidRussianWord(secondPart) &&
                           firstPart.count >= 4 && secondPart.count >= 4 {
                            fixedWords.append(firstPart)
                            fixedWords.append(secondPart)
                            continue
                        }
                    }
                }
            }
            
            fixedWords.append(word)
        }
        
        return fixedWords.joined(separator: " ")
    }
    
    private func fixCommonSpellingErrors(in text: String) -> String {
        var result = text
        
        let commonErrors: [(String, String)] = [
            ("\\s+([а-яА-ЯёЁ]+)\\s+([а-яА-ЯёЁ]{1,2})\\s+", " $1$2 "),
            ("\\bне\\s+то\\b", "не то"),
            ("\\bне\\s+от\\b", "не от"),
            ("\\bне\\s+за\\b", "не за"),
            ("\\bне\\s+с\\b", "не с"),
            ("\\bне\\s+в\\b", "не в"),
            ("\\bне\\s+на\\b", "не на"),
            ("\\bне\\s+к\\b", "не к"),
            ("\\bне\\s+по\\b", "не по"),
            ("\\bне\\s+у\\b", "не у"),
            ("\\bне\\s+о\\b", "не о"),
            ("\\bне\\s+об\\b", "не об"),
            ("\\bне\\s+про\\b", "не про"),
            ("\\bне\\s+под\\b", "не под"),
            ("\\bне\\s+над\\b", "не над"),
            ("\\bне\\s+перед\\b", "не перед"),
            ("\\bне\\s+между\\b", "не между"),
            ("\\bне\\s+среди\\b", "не среди"),
            ("\\bне\\s+около\\b", "не около"),
            ("\\bне\\s+при\\b", "не при"),
            ("\\bне\\s+без\\b", "не без"),
            ("\\bне\\s+для\\b", "не для"),
            ("\\bне\\s+из\\b", "не из"),
            ("\\bне\\s+до\\b", "не до"),
            ("\\bне\\s+через\\b", "не через"),
            ("\\bне\\s+сквозь\\b", "не сквозь"),
            ("\\bне\\s+вместо\\b", "не вместо"),
            ("\\bне\\s+кроме\\b", "не кроме"),
            ("\\bне\\s+сверх\\b", "не сверх"),
            ("\\bне\\s+вопреки\\b", "не вопреки"),
            ("\\bне\\s+благодаря\\b", "не благодаря"),
            ("\\bне\\s+согласно\\b", "не согласно"),
            ("\\bне\\s+вследствие\\b", "не вследствие"),
            ("\\bне\\s+ввиду\\b", "не ввиду"),
            ("\\bне\\s+вроде\\b", "не вроде"),
            ("\\bне\\s+подобно\\b", "не подобно"),
            ("\\bне\\s+навстречу\\b", "не навстречу"),
            ("\\bне\\s+наподобие\\b", "не наподобие"),
            ("\\bне\\s+наперекор\\b", "не наперекор"),
            ("\\bне\\s+наперерез\\b", "не наперерез"),
            ("\\bне\\s+напротив\\b", "не напротив"),
            ("\\bне\\s+наряду\\b", "не наряду")
        ]
        
        for (pattern, replacement) in commonErrors {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: replacement
                )
            }
        }
        
        result = fixThreePartWordBreaks(in: result)
        
        return result
    }
    
    private func fixThreePartWordBreaks(in text: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard words.count >= 3 else { return text }
        
        var fixedWords: [String] = []
        var i = 0
        
        while i < words.count {
            if i + 2 < words.count {
                let part1 = words[i]
                let part2 = words[i + 1]
                let part3 = words[i + 2]
                
                if part1.count <= 3 && part2.count <= 4 && part3.count >= 2 {
                    let combined = part1 + part2 + part3
                    if isValidRussianWord(combined) {
                        let part1Valid = isValidRussianWord(part1)
                        let part2Valid = isValidRussianWord(part2)
                        let _ = isValidRussianWord(part3)
                        
                        if (!part1Valid || !part2Valid) && combined.count <= 20 {
                            fixedWords.append(combined)
                            i += 3
                            continue
                        }
                    }
                }
            }
            
            fixedWords.append(words[i])
            i += 1
        }
        
        return fixedWords.joined(separator: " ")
    }
    
    private func findWordSplitPoint(_ word: String) -> Int? {
        let vowels = CharacterSet(charactersIn: "аеёиоуыэюя")
        let consonants = CharacterSet(charactersIn: "бвгджзйклмнпрстфхцчшщ")
        
        let minFirstPart = 4
        let minSecondPart = 4
        let maxFirstPart = word.count - minSecondPart
        
        let strideFrom = min(maxFirstPart, 12)
        let strideThrough = minFirstPart
        guard strideFrom >= strideThrough else { return nil }
        
        for i in stride(from: strideFrom, through: strideThrough, by: -1) {
            if i >= word.count - 1 || i <= 0 { continue }
            
            let charBefore = word[word.index(word.startIndex, offsetBy: i - 1)]
            let charAfter = word[word.index(word.startIndex, offsetBy: i)]
            
            let charBeforeStr = String(charBefore)
            let charAfterStr = String(charAfter)
            
            if charBeforeStr.rangeOfCharacter(from: vowels) != nil &&
               charAfterStr.rangeOfCharacter(from: consonants) != nil {
                return i
            }
        }
        
        return nil
    }
    
    private func isValidRussianWord(_ word: String) -> Bool {
        let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
        let vowels = CharacterSet(charactersIn: "аеёиоуыэюяАЕЁИОУЫЭЮЯ")
        
        guard cleaned.rangeOfCharacter(from: vowels) != nil else { return false }
        if cleaned.count < 2 || cleaned.count > 25 { return false }
        
        let russianLetters = CharacterSet(charactersIn: "абвгдеёжзийклмннопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ-")
        let wordChars = CharacterSet(charactersIn: cleaned)
        
        return russianLetters.isSuperset(of: wordChars)
    }
    
    private func hasCompleteSentenceStructure(words: [String]) -> Bool {
        guard words.count >= 2 else { return false }
        
        let text = words.joined(separator: " ").lowercased()
        
        let sentenceEndMarkers = ["что", "который", "когда", "где", "как", "чтобы", "потому что", "так как"]
        let hasMarker = sentenceEndMarkers.contains { text.contains($0) }
        
        let verbEndings = ["ет", "ит", "ат", "ят", "ут", "ют", "ал", "ил", "ел", "ся", "сь"]
        let hasVerb = words.contains { word in
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
            return verbEndings.contains { cleaned.hasSuffix($0) }
        }
        
        let nounEndings = ["а", "я", "о", "е", "ы", "и", "у", "ю", "ом", "ем", "ой", "ей"]
        let hasNoun = words.contains { word in
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
            return nounEndings.contains { cleaned.hasSuffix($0) } && cleaned.count >= 3
        }
        
        return hasVerb || (hasNoun && hasMarker) || words.count >= 8
    }
    
    private func normalizeWhitespace(in text: String) -> String {
        var result = text
        
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " .", with: ".")
        result = result.replacingOccurrences(of: " !", with: "!")
        result = result.replacingOccurrences(of: " ?", with: "?")
        result = result.replacingOccurrences(of: " :", with: ":")
        result = result.replacingOccurrences(of: " ;", with: ";")
        
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }
    
    private func processNumbers(in text: String) -> String {
        var result = text
        
        let pattern1 = "([0-9]+)([а-яА-ЯёЁ]{2,})"
        if let regex = try? NSRegularExpression(pattern: pattern1, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1 $2"
            )
        }
        
        let pattern2 = "([а-яА-ЯёЁ]{2,})([0-9]+)"
        if let regex = try? NSRegularExpression(pattern: pattern2, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1 $2"
            )
        }
        
        let pattern3 = "([0-9]{4,})([0-9]{4,})"
        if let regex = try? NSRegularExpression(pattern: pattern3, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 3 {
                    let fullRange = match.range(at: 0)
                    let part1Range = match.range(at: 1)
                    let part2Range = match.range(at: 2)
                    
                    if let fullSwiftRange = Range(fullRange, in: result),
                       let part1SwiftRange = Range(part1Range, in: result),
                       let part2SwiftRange = Range(part2Range, in: result) {
                        let part1 = String(result[part1SwiftRange])
                        let part2 = String(result[part2SwiftRange])
                        
                        if part1.count >= 4 && part2.count >= 4 {
                            let replacement = "\(part1) \(part2)"
                            result.replaceSubrange(fullSwiftRange, with: replacement)
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func processAbbreviations(in text: String) -> String {
        var result = text
        
        let abbreviations: [String: String] = [
            "и т.д.": "и так далее",
            "и т.п.": "и тому подобное",
            "до н.э.": "до нашей эры",
            "т.е.": "то есть",
            "т.д.": "так далее",
            "т.п.": "тому подобное",
            "и др.": "и другие",
            "и пр.": "и прочее",
            "т.к.": "так как",
            "т.н.": "так называемый",
            "н.э.": "нашей эры",
            "гг.": "годы",
            "вв.": "века",
            "чч.": "части",
            "глл.": "главы",
            "пп.": "пункты",
            "сс.": "страницы",
            "кк.": "книги",
            "тт.": "тома",
            "г.": "год",
            "в.": "век",
            "см.": "смотри",
            "стр.": "страница",
            "ч.": "часть",
            "гл.": "глава",
            "п.": "пункт",
            "с.": "страница",
            "к.": "книга",
            "т.": "том",
            "др.": "другие",
            "пр.": "прочее",
            "т.е": "то есть",
            "т.д": "так далее",
            "т.п": "тому подобное",
            "т.к": "так как",
            "т.н": "так называемый"
        ]
        
        for (abbrev, full) in abbreviations {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: abbrev))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: full
                )
            }
        }
        
        return result
    }
    
    private func fixWordRepetitions(in text: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        guard words.count >= 2 else { return text }
        
        var fixedWords: [String] = []
        var i = 0
        
        while i < words.count {
            let currentWord = words[i]
            
            if i + 1 < words.count {
                let nextWord = words[i + 1]
                let currentNormalized = normalizeWord(currentWord)
                let nextNormalized = normalizeWord(nextWord)
                
                if currentNormalized == nextNormalized {
                    fixedWords.append(currentWord)
                    i += 2
                    continue
                }
                
                if i + 2 < words.count {
                    let nextNextWord = words[i + 2]
                    let nextNextNormalized = normalizeWord(nextNextWord)
                    
                    if currentNormalized == nextNextNormalized && currentWord.count >= 3 {
                        if nextWord.count <= 4 {
                            fixedWords.append(currentWord)
                            i += 3
                            continue
                        }
                    }
                }
                
                if i + 3 < words.count {
                    let phrase1 = [currentWord, nextWord]
                    let phrase2 = [words[i + 2], words[i + 3]]
                    
                    let phrase1Normalized = phrase1.map { normalizeWord($0) }
                    let phrase2Normalized = phrase2.map { normalizeWord($0) }
                    
                    if phrase1Normalized == phrase2Normalized {
                        fixedWords.append(contentsOf: phrase1)
                        i += 4
                        continue
                    }
                }
                
                if i + 5 < words.count {
                    let phrase1 = [currentWord, nextWord, words[i + 2]]
                    let phrase2 = [words[i + 3], words[i + 4], words[i + 5]]
                    
                    let phrase1Normalized = phrase1.map { normalizeWord($0) }
                    let phrase2Normalized = phrase2.map { normalizeWord($0) }
                    
                    if phrase1Normalized == phrase2Normalized {
                        fixedWords.append(contentsOf: phrase1)
                        i += 6
                        continue
                    }
                }
            }
            
            fixedWords.append(currentWord)
            i += 1
        }
        
        return fixedWords.joined(separator: " ")
    }
    
    private func removeAllDuplicates(in text: String) -> String {
        var result = text
        
        result = result.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: ",{2,}", with: ",", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\.{2,}", with: ".", options: .regularExpression)
        result = result.replacingOccurrences(of: "!{2,}", with: "!", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\?{2,}", with: "?", options: .regularExpression)
        
        let words = result.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        guard words.count >= 2 else { return result }
        
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
                
                if currentWord.count >= 2 && nextWord.count >= 3 && currentWord.count <= 6 {
                    let combined = currentWord + nextWord
                    if combined.count >= 4 && combined.count <= 25 {
                        let combinedLower = combined.lowercased()
                        let russianChars = combinedLower.filter { $0.isLetter && ($0 >= "а" && $0 <= "я" || $0 == "ё") }
                        if russianChars.count >= combined.count * 2 / 3 {
                            fixedWords.append(combined)
                            i += 2
                            continue
                        }
                    }
                }
                
                if currentWord.count >= 2 && nextWord.count >= 2 {
                    if currentNormalized.hasPrefix(nextNormalized) || nextNormalized.hasPrefix(currentNormalized) {
                        let longerWord = currentWord.count >= nextWord.count ? currentWord : nextWord
                        fixedWords.append(longerWord)
                        i += 2
                        continue
                    }
                }
            }
            
            let alreadyAdded = fixedWords.map { normalizeWord($0) }
            if currentWord.count >= 2 {
                let recentWords = Array(alreadyAdded.suffix(15))
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
        
        result = finalWords.joined(separator: " ")
        
        let resultWords = result.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
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
                result = uniqueWords.joined(separator: " ")
            }
        }
        
        result = removePunctuationDuplicates(in: result)
        result = removeWhitespaceDuplicates(in: result)
        
        return result
    }
    
    private func removePunctuationDuplicates(in text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: ".,", with: ",")
        result = result.replacingOccurrences(of: ",,", with: ",")
        result = result.replacingOccurrences(of: "..", with: ".")
        result = result.replacingOccurrences(of: "!!", with: "!")
        result = result.replacingOccurrences(of: "??", with: "?")
        result = result.replacingOccurrences(of: "::", with: ":")
        result = result.replacingOccurrences(of: ";;", with: ";")
        result = result.replacingOccurrences(of: ",.", with: ".")
        result = result.replacingOccurrences(of: ",,", with: ",")
        return result
    }
    
    private func removeWhitespaceDuplicates(in text: String) -> String {
        var result = text
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        while result.contains("\n\n") {
            result = result.replacingOccurrences(of: "\n\n", with: "\n")
        }
        return result
    }
    
    private func normalizeWord(_ word: String) -> String {
        return word.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }
    
    private func addDashes(in text: String) -> String {
        var result = text
        
        let dashPatterns = [
            ("([а-яА-ЯёЁ]+)\\s+то\\s+([а-яА-ЯёЁ]+)", "$1 - то $2"),
            ("([а-яА-ЯёЁ]+)\\s+либо\\s+([а-яА-ЯёЁ]+)", "$1 - либо $2"),
            ("([а-яА-ЯёЁ]+)\\s+или\\s+([а-яА-ЯёЁ]+)", "$1 - или $2"),
            ("с\\s+([а-яА-ЯёЁ]+)\\s+по\\s+([а-яА-ЯёЁ]+)", "с $1 - по $2"),
            ("от\\s+([а-яА-ЯёЁ]+)\\s+до\\s+([а-яА-ЯёЁ]+)", "от $1 - до $2")
        ]
        
        for (pattern, replacement) in dashPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
            }
        }
        
        return result
    }
    
    private func addColons(in text: String) -> String {
        var result = text
        
        let colonPatterns = [
            ("([а-яА-ЯёЁ]+)\\s+а\\s+именно\\s+", "$1 : "),
            ("([а-яА-ЯёЁ]+)\\s+то\\s+есть\\s+", "$1 : "),
            ("([а-яА-ЯёЁ]+)\\s+как\\s+следующее\\s+", "$1 : "),
            ("([а-яА-ЯёЁ]+)\\s+например\\s+", "$1 : "),
            ("([а-яА-ЯёЁ]+)\\s+следующее\\s+", "$1 : "),
            ("([а-яА-ЯёЁ]+)\\s+такое\\s+", "$1 : ")
        ]
        
        for (pattern, replacement) in colonPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                let matches = regex.matches(in: result, options: [], range: range)
                
                for match in matches.reversed() {
                    if match.range.location > 0 {
                        let beforeIndex = result.index(result.startIndex, offsetBy: match.range.location - 1)
                        let beforeChar = result[beforeIndex]
                        if beforeChar != ":" {
                            result = regex.stringByReplacingMatches(
                                in: result,
                                options: [],
                                range: match.range,
                                withTemplate: replacement
                            )
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func addCommasInEnumerations(in text: String) -> String {
        var result = text
        
        let enumerationPattern = "([а-яА-ЯёЁ]+)\\s+([а-яА-ЯёЁ]{1,4})\\s+([а-яА-ЯёЁ]{1,4})\\s+([а-яА-ЯёЁ]+)"
        if let regex = try? NSRegularExpression(pattern: enumerationPattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 5 {
                    let word1Range = match.range(at: 1)
                    let word2Range = match.range(at: 2)
                    let word3Range = match.range(at: 3)
                    let word4Range = match.range(at: 4)
                    
                    if let word1SwiftRange = Range(word1Range, in: result),
                       let word2SwiftRange = Range(word2Range, in: result),
                       let word3SwiftRange = Range(word3Range, in: result),
                       let word4SwiftRange = Range(word4Range, in: result) {
                        let word1 = String(result[word1SwiftRange])
                        let word2 = String(result[word2SwiftRange])
                        let word3 = String(result[word3SwiftRange])
                        let word4 = String(result[word4SwiftRange])
                        
                        if word2.count <= 4 && word3.count <= 4 && word1.count <= 8 && word4.count <= 8 {
                            let fullRange = Range(match.range(at: 0), in: result)!
                            let replacement = "\(word1), \(word2), \(word3) \(word4)"
                            result.replaceSubrange(fullRange, with: replacement)
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func addCommasInDirectSpeech(in text: String) -> String {
        var result = text
        
        let directSpeechPatterns = [
            ("(сказал|сказала|сказало|сказали|говорит|говорил|говорила|говорили|ответил|ответила|ответили|спросил|спросила|спросили)\\s+([а-яА-ЯёЁ]+)", "$1, $2"),
            ("(подумал|подумала|подумали|решил|решила|решили)\\s+([а-яА-ЯёЁ]+)", "$1, $2")
        ]
        
        for (pattern, replacement) in directSpeechPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                let matches = regex.matches(in: result, options: [], range: range)
                
                for match in matches.reversed() {
                    if match.range.location > 0 {
                        let beforeIndex = result.index(result.startIndex, offsetBy: match.range.location - 1)
                        let beforeChar = result[beforeIndex]
                        if beforeChar != "," {
                            result = regex.stringByReplacingMatches(
                                in: result,
                                options: [],
                                range: match.range,
                                withTemplate: replacement
                            )
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func addQuestionMarks(in text: String) -> String {
        let questionWords = ["что", "как", "где", "когда", "почему", "зачем", "кто", "чей", "какой", "какая", "какое", "какие", "сколько"]
        
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard words.count >= 2 else { return text }
        
        var fixedWords: [String] = []
        for (index, word) in words.enumerated() {
            let cleanedWord = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
            
            if questionWords.contains(cleanedWord) && index == words.count - 1 {
                if !word.hasSuffix("?") && !word.hasSuffix(".") && !word.hasSuffix("!") {
                    fixedWords.append(word + "?")
                    continue
                }
            }
            
            fixedWords.append(word)
        }
        
        return fixedWords.joined(separator: " ")
    }
    
    private func addExclamationMarks(in text: String) -> String {
        let exclamationWords = ["важно", "внимание", "стоп", "хватит", "достаточно", "отлично", "прекрасно", "ура"]
        
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard words.count >= 1 else { return text }
        
        var fixedWords: [String] = []
        for (index, word) in words.enumerated() {
            let cleanedWord = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
            
            if exclamationWords.contains(cleanedWord) && index == words.count - 1 {
                if !word.hasSuffix("!") && !word.hasSuffix(".") && !word.hasSuffix("?") {
                    fixedWords.append(word + "!")
                    continue
                }
            }
            
            fixedWords.append(word)
        }
        
        return fixedWords.joined(separator: " ")
    }
}
