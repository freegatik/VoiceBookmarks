# Инструкция по настройке конфигурации

Перед использованием приложения необходимо настроить следующие параметры:

## 1. API Server URL

Откройте `VoiceBookmarks/Utils/Constants.swift` и замените:

```swift
static let baseURL = "https://minds.myapp.fund/weaviate"
```

на адрес вашего API сервера.

## 2. Bundle Identifier

В Xcode:
1. Выберите проект в навигаторе
2. Выберите target `VoiceBookmarks`
3. Перейдите в вкладку "Signing & Capabilities"
4. Измените Bundle Identifier (например: `com.yourcompany.yourapp`)
5. Повторите для target `VoiceBookmarksShareExtension`

## 3. App Group Identifier

В Xcode:
1. Выберите target `VoiceBookmarks`
2. Перейдите в "Signing & Capabilities"
3. Добавьте App Groups capability (если еще не добавлена)
4. Добавьте ваш App Group identifier (например: `group.com.yourcompany.yourapp`)
5. Повторите для target `VoiceBookmarksShareExtension`

Затем обновите в `VoiceBookmarks/Utils/Constants.swift`:

```swift
enum AppGroups {
    static let identifier = "group.com.yourcompany.yourapp"
}
```

И в файлах entitlements:
- `VoiceBookmarks/VoiceBookmarks.entitlements`
- `VoiceBookmarksShareExtension/VoiceBookmarksShareExtension.entitlements`

## 4. Keychain Service

Обновите в `VoiceBookmarks/Utils/Constants.swift`:

```swift
enum Keychain {
    static let service = "com.yourcompany.yourapp.keychain"
}
```

## 5. OSLog Subsystem

Обновите в `VoiceBookmarks/Services/Core/LoggerService.swift`:

```swift
private let osLog = OSLog(subsystem: "com.yourcompany.yourapp", category: "app")
```

## 6. URL Scheme

Откройте `VoiceBookmarks/Info.plist` и обновите:

```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>yourapp</string>
</array>
```

И в `VoiceBookmarksShareExtension/ShareViewController.swift`:

```swift
let url = URL(string: "yourapp://share-extension")
```

## 7. Keychain Access Groups

В файлах entitlements обновите:

```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.yourcompany.yourapp</string>
</array>
```

## 8. Тесты

Обновите тесты в `VoiceBookmarksTests/Utils/ConstantsTests.swift`:

```swift
func testConstants_API_BaseURL() {
    XCTAssertEqual(Constants.API.baseURL, "https://minds.myapp.fund/weaviate")
}

func testConstants_Keychain_Service() {
    XCTAssertEqual(Constants.Keychain.service, "com.yourcompany.yourapp.keychain")
}

func testConstants_AppGroups_Identifier() {
    XCTAssertEqual(Constants.AppGroups.identifier, "group.com.yourcompany.yourapp")
}
```

## Проверка

После настройки убедитесь, что:
- Все placeholder значения заменены на реальные
- Bundle Identifier настроен в Xcode для всех targets
- App Group настроен и добавлен в entitlements
- URL Scheme настроен в Info.plist
- Тесты обновлены и проходят

