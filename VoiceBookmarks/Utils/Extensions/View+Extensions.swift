//
//  View+Extensions.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

// MARK: - Расширения View: стили карточек, swipe жесты, условные модификаторы

extension View {
    
    
    /// Золотой стиль карточки (для особых элементов)
    func goldCardStyle() -> some View {
        self
            .padding(Constants.UI.cardPadding)
            .background(Color.gold)
            .cornerRadius(Constants.UI.cardCornerRadius)
    }
    
    /// Стандартный стиль карточки (белый фон, тень)
    func cardStyle() -> some View {
        self
            .padding(Constants.UI.cardPadding)
            .background(Color.appWhite)
            .cornerRadius(Constants.UI.cardCornerRadius)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    
    /// Swipe вниз для закрытия (порог 100px)
    func swipeDownToDismiss(action: @escaping () -> Void) -> some View {
        self.gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        action()
                    }
                }
        )
    }
    
    /// Swipe вверх для действия (порог 100px)
    func swipeUpAction(action: @escaping () -> Void) -> some View {
        self.gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height < -100 {
                        action()
                    }
                }
        )
    }
    
    /// Swipe вправо для закрытия (порог 100px)
    func swipeRightToDismiss(action: @escaping () -> Void) -> some View {
        self.gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 {
                        action()
                    }
                }
        )
    }
    
    
    /// Скрытие/показ view через opacity (сохраняет место в layout)
    func hidden(_ hidden: Bool) -> some View {
        opacity(hidden ? 0 : 1)
    }
    
    /// Условное применение модификатора (аналог if-else для View)
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
