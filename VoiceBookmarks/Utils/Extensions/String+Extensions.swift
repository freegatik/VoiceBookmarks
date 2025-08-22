//
//  String+Extensions.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Расширения String: проверки, валидация URL, расчет высоты текста

extension String {
    
    /// Проверка, что строка не пустая (после обрезки пробелов)
    var isNotEmpty: Bool {
        !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Обрезка пробелов и переносов строк с начала и конца
    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Валидация URL: проверка наличия scheme и host
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    
    #if canImport(UIKit)
    /// Расчет высоты текста для заданной ширины и шрифта
    /// Используется для динамической высоты UI элементов
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        guard width > 0 && width.isFinite else {
            return 0
        }
        
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        let height = ceil(boundingBox.height)
        return height.isFinite ? height : 0
    }
    #endif
}
