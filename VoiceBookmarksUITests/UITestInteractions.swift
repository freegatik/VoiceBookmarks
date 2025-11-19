//
//  UITestInteractions.swift
//  VoiceBookmarksUITests
//

import XCTest

// MARK: - Общие вспомогательные функции для UI-тестов: отправка текстового поиска и поиск кнопки…

enum UITestInteractions {
    static let searchSubmitButtonIdentifier = "SearchSubmitButton"
    static let webCloseButtonIdentifier = "WebContentClose"

    /// Запускает текстовый поиск на экране списка папок без совпадения с вкладкой «Search» в tab bar.
    static func submitFolderSearch(app: XCUIApplication, searchField: XCUIElement) {
        let submit = app.buttons[searchSubmitButtonIdentifier]
        if submit.waitForExistence(timeout: 4), submit.isEnabled, submit.isHittable {
            submit.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            return
        }
        guard searchField.exists else { return }
        searchField.typeText("\n")
    }

    static func webCloseButton(in app: XCUIApplication) -> XCUIElement {
        let global = app.buttons[webCloseButtonIdentifier]
        if global.exists { return global }
        let nav = app.navigationBars.firstMatch
        let inNav = nav.buttons[webCloseButtonIdentifier]
        if inNav.exists { return inNav }
        return nav.buttons["Close"]
    }
}
