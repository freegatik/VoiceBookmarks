//
//  UITestInteractions.swift
//  VoiceBookmarksUITests
//

import XCTest

// MARK: - Общие вспомогательные функции для UI-тестов: отправка текстового поиска и поиск кнопки…

enum UITestInteractions {
    static let searchSubmitButtonIdentifier = "SearchSubmitButton"
    static let webCloseButtonIdentifier = "WebContentClose"
    static let webOverflowMenuIdentifier = "WebContentOverflowMenu"

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

    /// После тапа по карточке файла SwiftUI показывает `confirmationDialog` с «View» — без этого шита с WebContent нет.
    static func confirmOpenBookmarkFromFileListIfNeeded(app: XCUIApplication) {
        let view = app.buttons["View"]
        if view.waitForExistence(timeout: 4) {
            view.tap()
        }
    }

    static func webCloseButton(in app: XCUIApplication) -> XCUIElement {
        let byId = app.descendants(matching: .any).matching(identifier: webCloseButtonIdentifier).firstMatch
        if byId.exists {
            return byId
        }
        let navBars = app.navigationBars
        let count = navBars.count
        if count > 0 {
            for i in stride(from: count - 1, through: 0, by: -1) {
                let nav = navBars.element(boundBy: i)
                let idBtn = nav.buttons[webCloseButtonIdentifier]
                if idBtn.exists { return idBtn }
                let closeBtn = nav.buttons["Close"]
                if closeBtn.exists { return closeBtn }
            }
        }
        return app.buttons[webCloseButtonIdentifier]
    }

    /// Кнопка overflow (⋯) в тулбаре WebContent; на CI не полагаемся на SF Symbol `ellipsis.circle`.
    static func webOverflowMenuButton(in app: XCUIApplication) -> XCUIElement {
        let byId = app.descendants(matching: .any).matching(identifier: webOverflowMenuIdentifier).firstMatch
        if byId.exists {
            return byId
        }
        let navBars = app.navigationBars
        let count = navBars.count
        if count > 0 {
            for i in stride(from: count - 1, through: 0, by: -1) {
                let nav = navBars.element(boundBy: i)
                let sym = nav.buttons.matching(identifier: "ellipsis.circle").firstMatch
                if sym.exists {
                    return sym
                }
                let more = nav.buttons["More"]
                if more.exists {
                    return more
                }
            }
        }
        return app.descendants(matching: .any).matching(identifier: webOverflowMenuIdentifier).firstMatch
    }

    static func waitForSystemShareSheet(app: XCUIApplication, timeout: TimeInterval = 20) -> Bool {
        let marker = app.descendants(matching: .any).matching(identifier: "VoiceBookmarksSharePresenterHost").firstMatch
        if marker.waitForExistence(timeout: timeout) {
            return true
        }
        if app.sheets.firstMatch.waitForExistence(timeout: 2) {
            return true
        }
        let cv = app.collectionViews.firstMatch
        return cv.waitForExistence(timeout: 2)
    }

    static func waitForDeleteBookmarkConfirmation(in app: XCUIApplication, timeout: TimeInterval = 8) -> XCUIElement? {
        let sheet = app.sheets.firstMatch
        if sheet.waitForExistence(timeout: timeout) {
            return sheet
        }
        let alert = app.alerts["Delete bookmark?"]
        return alert.waitForExistence(timeout: 2) ? alert : nil
    }
}
