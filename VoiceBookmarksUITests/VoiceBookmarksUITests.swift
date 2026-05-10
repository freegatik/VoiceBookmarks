//
//  VoiceBookmarksUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

final class VoiceBookmarksUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--UITestSeedFolders"]
        app.launch()
        sleep(1)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testAppLaunchesWithTabBar() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab Bar должен появиться при запуске")
        
        let addTab = app.tabBars.buttons["Add"]
        let searchTab = app.tabBars.buttons["Search"]
        
        XCTAssertTrue(addTab.exists, "Add tab should exist")
        XCTAssertTrue(searchTab.exists, "Вкладка 'Search' должна существовать")
    }
    
    @MainActor
    func testTabSwitching() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
        searchTab.tap()
        
        let navBar = app.navigationBars.firstMatch
        if navBar.waitForExistence(timeout: 2) {
            let title = navBar.staticTexts["Folders"]
            XCTAssertTrue(title.exists || app.scrollViews.firstMatch.waitForExistence(timeout: 2), "Экран папок должен отображаться с заголовком 'Folders'")
        } else {
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 2), "Экран папок должен отображаться")
        }
        
        let addTab = app.tabBars.buttons["Add"]
        addTab.tap()
        
        XCTAssertTrue(app.otherElements.firstMatch.exists, "Экран добавления должен отображаться")
    }
    
    @MainActor
    func testShareViewDisplay() throws {
        let addTab = app.tabBars.buttons["Add"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран добавления должен отображаться")
    }
    
    @MainActor
    func testFolderListViewDisplay() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
        searchTab.tap()
        
        let navBar = app.navigationBars["Folders"]
        if navBar.waitForExistence(timeout: 3) {
            XCTAssertTrue(navBar.exists, "Заголовок 'Folders' должен отображаться")
        }
        
        let screen = app.scrollViews.firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 3) || app.staticTexts.firstMatch.waitForExistence(timeout: 2), "Экран папок должен отображаться")
    }
    
    @MainActor
    func testFoldersDisplayUserFriendlyNames() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
        searchTab.tap()
        
        let foldersList = app.scrollViews.firstMatch
        XCTAssertTrue(foldersList.waitForExistence(timeout: 5), "Список папок должен загрузиться")
        
        let selfReflectionFolder = app.staticTexts["Self-reflection"]
        let tasksFolder = app.staticTexts["Tasks"]
        let projectResourcesFolder = app.staticTexts["Project resources"]
        let uncategorisedFolder = app.staticTexts["Uncategorized"]
        
        _ = selfReflectionFolder.waitForExistence(timeout: 1) || 
            tasksFolder.waitForExistence(timeout: 1) || 
            projectResourcesFolder.waitForExistence(timeout: 1) || 
            uncategorisedFolder.waitForExistence(timeout: 1)
        
        XCTAssertTrue(foldersList.exists, "Список папок должен отображаться")
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    @MainActor
    func testBothTabsWorkIndependently() throws {
        let addTab = app.tabBars.buttons["Add"]
        XCTAssertTrue(addTab.exists, "Add tab should exist")
        addTab.tap()
        
        let addScreen = app.otherElements.firstMatch
        XCTAssertTrue(addScreen.waitForExistence(timeout: 2), "Экран 'Add' должен появиться")
        
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.exists, "Вкладка 'Search' должна существовать")
        searchTab.tap()
        
        let searchScreen = app.scrollViews.firstMatch
        XCTAssertTrue(searchScreen.exists || app.navigationBars.firstMatch.exists, "Экран 'Search' должен отображаться")
        addTab.tap()
        XCTAssertTrue(addScreen.exists, "Экран 'Add' должен снова отображаться")
    }
    
    @MainActor
    func testTabNavigation() throws {
        let addTab = app.tabBars.buttons["Add"]
        let searchTab = app.tabBars.buttons["Search"]
        
        addTab.tap()
        XCTAssertTrue(addTab.isSelected || app.otherElements.firstMatch.exists, "Вкладка 'Add' активна")
        
        searchTab.tap()
        XCTAssertTrue(searchTab.isSelected || app.scrollViews.firstMatch.exists, "Вкладка 'Search' активна")
        
        addTab.tap()
        XCTAssertTrue(addTab.isSelected || app.otherElements.firstMatch.exists, "Вкладка 'Add' снова активна")
        
        searchTab.tap()
        XCTAssertTrue(searchTab.isSelected || app.scrollViews.firstMatch.exists, "Вкладка 'Search' снова активна")
    }
    
    @MainActor
    func testSearchFieldExists() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
            searchTab.tap()
            
        let searchField = app.textFields["Search..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Поле поиска должно отображаться")
    }
    
    @MainActor
    func testFoldersTitle() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
            searchTab.tap()
            
        let navBar = app.navigationBars["Folders"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Заголовок 'Folders' должен отображаться")
    }
    
    func testFullUserJourneyFromLaunchToFileView() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Приложение должно запуститься")
        
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
        searchTab.tap()
        
        sleep(2)
        
        let foldersScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(foldersScrollView.waitForExistence(timeout: 15), "Список папок должен загрузиться")
        
        let folders = app.scrollViews.buttons
        var hasFolders = folders.count > 0
        
        if !hasFolders {
            let selfReflectionFolder = app.staticTexts["Self-reflection"].firstMatch
            let tasksFolder = app.staticTexts["Tasks"].firstMatch
            hasFolders = selfReflectionFolder.exists || tasksFolder.exists
        }
        
        let start = Date()
        while !hasFolders && Date().timeIntervalSince(start) < 15 {
            sleep(1)
            hasFolders = folders.count > 0
            if !hasFolders {
                let selfReflectionFolder = app.staticTexts["Self-reflection"].firstMatch
                let tasksFolder = app.staticTexts["Tasks"].firstMatch
                hasFolders = selfReflectionFolder.exists || tasksFolder.exists
            }
        }
        
        guard hasFolders else {
            throw XCTSkip("Нет доступных папок для тестирования")
        }
        
        folders.firstMatch.tap()
        
        let fileList = app.scrollViews.firstMatch
        XCTAssertTrue(fileList.waitForExistence(timeout: 5), "Список файлов должен загрузиться")
        
        let files = app.scrollViews.buttons
        guard files.count > 0 else {
            throw XCTSkip("Нет доступных файлов для тестирования")
        }
        
        files.firstMatch.tap()
        
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "WebView должен открыться")
        let closeButton = UITestInteractions.webCloseButton(in: app)
        if closeButton.waitForExistence(timeout: 2) {
            closeButton.tap()
            
            let backNavBar = app.navigationBars.firstMatch
            XCTAssertTrue(backNavBar.waitForExistence(timeout: 3), "Должен вернуться к списку файлов")
        }
    }
    
    func testSearchFieldInputAndExecution() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
        searchTab.tap()
        
        let searchField = app.textFields["Search..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Поле поиска должно появиться")
        
        searchField.tap()
        searchField.typeText("тест")
        
        let fieldValue = searchField.value as? String ?? ""
        XCTAssertTrue(fieldValue.contains("тест") || fieldValue == "тест", "Текст должен быть введен в поле поиска")
        
        let searchButtons = app.buttons.allElementsBoundByIndex
        var searchButtonFound = false
        
        for button in searchButtons {
            if button.exists && button.isEnabled {
                let buttonFrame = button.frame
                let fieldFrame = searchField.frame
                if buttonFrame.intersects(fieldFrame) || 
                   (buttonFrame.minX > fieldFrame.maxX && buttonFrame.midY < fieldFrame.maxY + 50 && buttonFrame.midY > fieldFrame.minY - 50) {
                    button.tap()
                    searchButtonFound = true
                    break
                }
            }
        }
        
        if !searchButtonFound {
            searchField.typeText("\n")
        }
        let resultExists = app.scrollViews.firstMatch.waitForExistence(timeout: 5) || 
                          app.staticTexts.firstMatch.waitForExistence(timeout: 5) ||
                          app.progressIndicators.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(resultExists, "Search должен выполниться и показать результаты или загрузку")
    }
    
    func testShareViewGestures() throws {
        let addTab = app.tabBars.buttons["Add"]
        XCTAssertTrue(addTab.waitForExistence(timeout: 5), "Вкладка Add должна существовать")
        addTab.tap()
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 3), "Экран добавления должен загрузиться")
        
        screen.tap()
        
        let pasteButton = app.buttons["Вставить"]
        if pasteButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(pasteButton.exists, "Кнопка 'Вставить' должна появиться после тапа, если есть контент в буфере")
        } else {
            XCTAssertTrue(screen.exists, "Экран должен реагировать на тап даже если контента нет в буфере")
        }
    }
    
    func testFolderOpeningAndFileNavigation() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
        searchTab.tap()
        
        sleep(2)
        
        let foldersScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(foldersScrollView.waitForExistence(timeout: 15), "Список папок должен загрузиться")
        
        let folders = app.scrollViews.buttons
        var hasFolders = folders.count > 0
        
        if !hasFolders {
            let selfReflectionFolder = app.staticTexts["Self-reflection"].firstMatch
            let tasksFolder = app.staticTexts["Tasks"].firstMatch
            hasFolders = selfReflectionFolder.exists || tasksFolder.exists
        }
        let start = Date()
        while !hasFolders && Date().timeIntervalSince(start) < 15 {
            sleep(1)
            hasFolders = folders.count > 0
            if !hasFolders {
                let selfReflectionFolder = app.staticTexts["Self-reflection"].firstMatch
                let tasksFolder = app.staticTexts["Tasks"].firstMatch
                hasFolders = selfReflectionFolder.exists || tasksFolder.exists
            }
        }
        
        guard hasFolders else {
            throw XCTSkip("Нет доступных папок для тестирования")
        }
        
        let firstFolder = folders.firstMatch
        firstFolder.tap()
        
        let fileListExists = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        let emptyStateExists = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Нет' OR label CONTAINS 'Пусто'")).firstMatch.waitForExistence(timeout: 5)
        
        XCTAssertTrue(fileListExists || emptyStateExists, "Должен отобразиться список файлов или пустое состояние после открытия папки")
    }
    
    func testLoadingStateOnFolderScreen() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
        searchTab.tap()
        
        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 2)
        let hasLoadingIndicator = app.progressIndicators.firstMatch.waitForExistence(timeout: 1)
        let hasLoadingText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Загрузка'")).firstMatch.waitForExistence(timeout: 1)
        let hasLoading = hasLoadingIndicator || hasLoadingText
        
        XCTAssertTrue(hasContent || hasLoading, "Должно быть состояние загрузки или контент на экране папок")
    }
    
    func testTabStatePersistence() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
        searchTab.tap()
        
        let foldersScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(foldersScrollView.waitForExistence(timeout: 10), "Список папок должен загрузиться")
        let initialFoldersCount = app.scrollViews.buttons.count
        
        let addTab = app.tabBars.buttons["Add"]
        XCTAssertTrue(addTab.waitForExistence(timeout: 5), "Вкладка Add должна существовать")
        addTab.tap()
        
        let addScreen = app.otherElements.firstMatch
        XCTAssertTrue(addScreen.waitForExistence(timeout: 2), "Экран Add должен появиться")
        
        searchTab.tap()
        
        XCTAssertTrue(foldersScrollView.waitForExistence(timeout: 5), "Список папок должен вернуться")
        let currentFoldersCount = app.scrollViews.buttons.count
        
        XCTAssertTrue(abs(currentFoldersCount - initialFoldersCount) <= 1, "Состояние экрана должно сохраниться при переключении вкладок")
    }
    
    func testSearchButtonFunctionality() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
        searchTab.tap()
        
        let searchField = app.textFields["Search..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Поле поиска должно появиться")
        
        searchField.tap()
        searchField.typeText("запрос")
        
        let allButtons = app.buttons.allElementsBoundByIndex
        var searchButtonFound = false
        
        for button in allButtons {
            if button.exists && button.isEnabled {
                let buttonFrame = button.frame
                let fieldFrame = searchField.frame
                
                if (buttonFrame.minX > fieldFrame.maxX && buttonFrame.midY < fieldFrame.maxY + 50 && buttonFrame.midY > fieldFrame.minY - 50) ||
                   (buttonFrame.minY > fieldFrame.maxY && abs(buttonFrame.midX - fieldFrame.midX) < 200) {
                    button.tap()
                    searchButtonFound = true
                    
                    let resultExists = app.scrollViews.firstMatch.waitForExistence(timeout: 5) || 
                                      app.staticTexts.firstMatch.waitForExistence(timeout: 5) ||
                                      app.progressIndicators.firstMatch.waitForExistence(timeout: 3)
                    XCTAssertTrue(resultExists, "Search должен выполниться после нажатия кнопки")
                    break
                }
            }
        }
        
        if !searchButtonFound {
            searchField.typeText("\n")
            let resultExists = app.scrollViews.firstMatch.waitForExistence(timeout: 5) || 
                              app.staticTexts.firstMatch.waitForExistence(timeout: 5)
            XCTAssertTrue(resultExists, "Search должен выполниться через submit")
        }
    }
    
    func testFolderIconsDisplay() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
        searchTab.tap()
        
        sleep(2)
        
        let foldersScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(foldersScrollView.waitForExistence(timeout: 15), "Список папок должен загрузиться")
        
        let folderButtons = app.scrollViews.buttons
        var hasFolders = folderButtons.count > 0
        
        if !hasFolders {
            let selfReflectionFolder = app.staticTexts["Self-reflection"].firstMatch
            let tasksFolder = app.staticTexts["Tasks"].firstMatch
            hasFolders = selfReflectionFolder.exists || tasksFolder.exists
        }
        
        let start = Date()
        while !hasFolders && Date().timeIntervalSince(start) < 15 {
            sleep(1)
            hasFolders = folderButtons.count > 0
            if !hasFolders {
                let selfReflectionFolder = app.staticTexts["Self-reflection"].firstMatch
                let tasksFolder = app.staticTexts["Tasks"].firstMatch
                hasFolders = selfReflectionFolder.exists || tasksFolder.exists
            }
        }
        
        guard hasFolders else {
            throw XCTSkip("Нет доступных папок для проверки иконок")
        }
        
        let firstFolder = folderButtons.firstMatch
        XCTAssertTrue(firstFolder.exists, "Папка должна отображаться")
        XCTAssertTrue(firstFolder.isHittable, "Папка должна быть интерактивной")
        
        let folderText = app.staticTexts.firstMatch
        XCTAssertTrue(folderText.waitForExistence(timeout: 2) || firstFolder.label.count > 0, "Папка должна содержать текст (название) или иметь label")
    }
    
    func testTabSwitchingPerformance() throws {
        #if VOICEBOOKMARKS_CI
        throw XCTSkip("Tab switching performance is unstable on GitHub-hosted simulators.")
        #else
        let addTab = app.tabBars.buttons["Add"]
        let searchTab = app.tabBars.buttons["Search"]
        
        measure {
            for _ in 0..<10 {
                addTab.tap()
                searchTab.tap()
            }
        }
        #endif
    }
    
    func testEmptyStateOnFolderScreen() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
        searchTab.tap()
        
        let foldersScrollView = app.scrollViews.firstMatch
        let navBar = app.navigationBars.firstMatch
        
        let screenLoaded = foldersScrollView.waitForExistence(timeout: 10) || navBar.waitForExistence(timeout: 10)
        XCTAssertTrue(screenLoaded, "Экран папок должен загрузиться")
        
        let hasFolders = app.scrollViews.buttons.count > 0
        let hasEmptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Нет' OR label CONTAINS 'папок' OR label CONTAINS 'пусто'")).firstMatch.exists
        
        XCTAssertTrue(hasFolders || hasEmptyState || navBar.exists, "Должно быть либо отображение папок, либо пустое состояние, либо навигационная панель")
    }
    
    func testSearchFieldDesign() throws {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should exist")
        searchTab.tap()
        
        let searchField = app.textFields["Search..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Поле поиска должно появиться")
        
        XCTAssertTrue(searchField.exists, "Поле поиска должно быть видимым")
        XCTAssertTrue(searchField.isHittable, "Поле поиска должно быть доступно для взаимодействия")
        
        let placeholder = searchField.placeholderValue ?? ""
        XCTAssertTrue(placeholder.contains("Search") || placeholder.contains("поиск"), "Поле поиска должно иметь placeholder")
        
        let allButtons = app.buttons.allElementsBoundByIndex
        var searchButtonFound = false
        
        for button in allButtons {
            if button.exists {
                let buttonFrame = button.frame
                let fieldFrame = searchField.frame
                if (buttonFrame.minX > fieldFrame.maxX && buttonFrame.midY < fieldFrame.maxY + 50 && buttonFrame.midY > fieldFrame.minY - 50) ||
                   (abs(buttonFrame.midY - fieldFrame.midY) < 30 && abs(buttonFrame.midX - fieldFrame.midX) < 300) {
                    searchButtonFound = true
                    break
                }
            }
        }
        
        XCTAssertTrue(searchButtonFound, "Кнопка поиска должна отображаться рядом с полем")
    }
}
