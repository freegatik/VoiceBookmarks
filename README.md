<div align="center">
  <img src="logo.png" alt="Voice Bookmarks" width="200"/>
</div>

# Voice Bookmarks

Нативное iOS приложение для сохранения и организации контента с голосовыми заметками и интеллектуальным поиском.

## Описание

Voice Bookmarks позволяет быстро сохранять различные типы контента (файлы, ссылки, изображения, видео) с добавлением голосовых заметок на русском языке. Приложение использует AI для автоматической категоризации и предоставляет семантический поиск по сохраненному контенту.

Проект полностью документирован краткими комментариями по сути, которые помогают разработчикам быстро понимать архитектуру и логику работы приложения.

## Основные возможности

### Сохранение контента
- **Share Extension** — сохранение контента из любых iOS приложений
- **Буфер обмена** — быстрое сохранение из буфера обмена
- **Множественные форматы** — поддержка текста, изображений, аудио, видео, PDF и других файлов
- **Автоматическое определение типа** — определение типа контента по расширению и содержимому

### Голосовые функции
- **Голосовые заметки** — распознавание речи на русском языке с улучшенной обработкой
- **Обработка транскрипции** — автоматическое исправление ошибок распознавания, добавление пунктуации
- **Слияние частичных результатов** — умное объединение частичных результатов распознавания речи
- **Голосовой поиск** — поиск с помощью голосовых команд

### Организация и поиск
- **AI-категоризация** — автоматическое распределение контента по категориям
- **Иерархические папки** — поддержка вложенных папок и категорий
- **Семантический поиск** — поиск по содержимому с поддержкой естественного языка
- **Поиск внутри файлов** — глубокий поиск по содержимому сохраненных файлов
- **Выполнение команд** — генерация HTML-ответов на основе сохраненного контента

### Производительность и надежность
- **Кеширование** — кеширование закладок и папок для быстрого доступа (5 минут)
- **Офлайн режим** — работа без интернета с автоматической синхронизацией при восстановлении связи
- **Очередь загрузок** — автоматическая обработка отложенных загрузок с защитой от дубликатов
- **Мониторинг сети** — автоматическое определение состояния сети и обработка очереди

### Безопасность и логирование
- **Безопасное хранение** — UUID пользователя хранится в Keychain
- **Система логирования** — структурированное логирование с категориями и уровнями
- **App Groups** — безопасный обмен данными между приложением и Share Extension

## Требования

- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

## Версия

- Версия: 1.0
- Build: 1

## Установка

1. Клонируйте репозиторий:
```bash
git clone https://github.com/yourusername/VoiceBookmarks.git
cd VoiceBookmarks
```

2. Откройте проект в Xcode:
```bash
open VoiceBookmarks.xcodeproj
```

3. **Настройте конфигурацию приложения** (обязательно перед использованием):
   
   **Подробная инструкция**: См. файл [CONFIGURATION.md](CONFIGURATION.md)
   
   ### 3.1. Настройка API сервера
   
   Откройте `VoiceBookmarks/Utils/Constants.swift` и замените:
   ```swift
   static let baseURL = "https://minds.myapp.fund/weaviate"
   ```
   на адрес вашего API сервера.

   ### 3.2. Настройка Bundle Identifier и App Groups
   
   В Xcode:
   - Выберите проект в навигаторе
   - Выберите target `VoiceBookmarks`
   - Перейдите в вкладку "Signing & Capabilities"
   - Настройте Bundle Identifier (например: `com.yourcompany.yourapp`)
   - Добавьте App Groups capability
   - Добавьте ваш App Group identifier (например: `group.com.yourcompany.yourapp`)
   - Повторите для target `VoiceBookmarksShareExtension`
   
   Затем обновите в `Constants.swift`:
   ```swift
   // В enum Keychain
   static let service = "com.yourcompany.yourapp.keychain"
   
   // В enum AppGroups
   static let identifier = "group.com.yourcompany.yourapp"
   ```
   
   И в `LoggerService.swift`:
   ```swift
   private let osLog = OSLog(subsystem: "com.yourcompany.yourapp", category: "app")
   ```

   ### 3.3. Настройка URL Scheme
   
   Откройте `VoiceBookmarks/Info.plist` и обновите:
   ```xml
   <key>CFBundleURLSchemes</key>
   <array>
       <string>yourapp</string>
   </array>
   ```
   Замените `yourapp` на ваш URL scheme.
   
   Также обновите в `ShareViewController.swift`:
   ```swift
   let url = URL(string: "yourapp://share-extension")
   ```

4. Запустите на симуляторе или устройстве

## Использование

### Добавление контента

- **Из буфера обмена**: Откройте приложение, нажмите на экран и используйте кнопку "Вставить"
- **Из других приложений**: Используйте Share Extension для сохранения контента из любого приложения
- **Голосовая заметка**: Удерживайте палец на контенте для записи голосовой заметки

### Поиск

- **Текстовый поиск**: Введите запрос в поле поиска
- **Голосовой поиск**: Удерживайте палец на папке для голосового поиска
- **Поиск внутри файла**: Удерживайте палец на файле для вложенного поиска

### Навигация

- **Tap на папке** — открыть список файлов в папке
- **Long press на папке** — голосовой поиск в папке
- **Long press на файле** — поиск внутри файла
- **Swipe вниз** — закрыть экран
- **Swipe вверх** — сохранить файл (в просмотре)

### Обработка голосовых заметок

Приложение включает продвинутую обработку транскрипции речи:

- **Автоматическое исправление ошибок** — исправление типичных ошибок распознавания речи
- **Добавление пунктуации** — автоматическое добавление запятых, точек, тире
- **Слияние результатов** — умное объединение частичных результатов распознавания
- **Удаление дубликатов** — автоматическое удаление повторяющихся слов и фраз
- **Нормализация текста** — приведение текста к читаемому виду с правильными пробелами

## API

### Базовые настройки

- **Base URL**: Настраивается в `Constants.swift` (по умолчанию: `https://minds.myapp.fund/weaviate`)
- **Авторизация**: Header `X-User-ID` с UUID пользователя
- **Timeout**: 30 секунд
- **Retry**: до 3 попыток с задержкой 1 секунда

**⚠️ ВНИМАНИЕ**: Перед использованием приложения необходимо настроить Base URL в `VoiceBookmarks/Utils/Constants.swift`

### Endpoints

- `/api/auth/anonymous` — анонимная авторизация
- `/api/folders` — управление папками/категориями
- `/api/bookmarks` — работа с закладками
- `/api/search` — семантический поиск
- `/api/download` — загрузка файлов
- `/api/categories/{category}/bookmarks` — закладки по категории

Полная спецификация API доступна в [swagger.yaml](swagger.yaml)

### Backend архитектура

- **Backend**: Python FastAPI
- **Vector DB**: Weaviate (Documents + Chunks)
- **Storage**: Supabase Storage
- **AI**: OpenAI (GPT-4, Vision, Whisper)

## Архитектура

Проект построен на архитектуре MVVM с использованием SwiftUI и dependency injection:

### Слои приложения

- **Models** — модели данных (Bookmark, Folder, ContentType, SearchResponse, CommandResponse)
- **Views** — SwiftUI представления с компонентами для различных типов контента
- **ViewModels** — бизнес-логика и состояние (ShareViewModel, SearchViewModel, WebViewModel)
- **Services** — сервисы для работы с сетью, файлами, речью, кешированием
- **Persistence** — Core Data для локального хранения офлайн очереди

### Сервисы

#### API Services
- **AuthService** — анонимная авторизация и управление userId
- **BookmarkService** — загрузка, сохранение и удаление закладок
- **SearchService** — семантический поиск и выполнение команд

#### Core Services
- **NetworkService** — HTTP запросы с retry логикой и обработкой ошибок
- **NetworkMonitor** — мониторинг состояния сети
- **OfflineQueueService** — управление офлайн очередью с автоматической синхронизацией
- **SpeechService** — распознавание речи на русском языке
- **TextPostProcessor** — постобработка транскрипции (исправление ошибок, пунктуация)
- **TranscriptionMerger** — слияние частичных результатов распознавания речи
- **FileService** — работа с файлами и данными
- **ClipboardService** — работа с буфером обмена
- **BookmarkCacheService** — кеширование закладок по категориям
- **FolderCacheService** — кеширование иерархии папок
- **LoggerService** — структурированное логирование с категориями
- **KeychainService** — безопасное хранение данных в Keychain
- **GlobalToastManager** — глобальные уведомления

### Особенности архитектуры

- **Dependency Injection** — все сервисы создаются в точке входа приложения
- **Thread Safety** — использование actors и locks для защиты от гонок данных
- **Error Handling** — централизованная обработка ошибок с логированием
- **Offline First** — приоритет локального кеша и офлайн очереди
- **Reactive Programming** — использование Combine для реактивных обновлений UI

## Технологии

Проект использует только нативные фреймворки iOS, внешние зависимости отсутствуют:

### UI и взаимодействие
- **SwiftUI** — пользовательский интерфейс
- **Combine** — реактивное программирование и потоки данных
- **UIKit** — интеграция с системными компонентами

### Хранение данных
- **Core Data** — локальное хранение офлайн очереди
- **UserDefaults** — кеширование и настройки (с App Groups для Share Extension)
- **Keychain** — безопасное хранение пользовательских данных

### Сеть и коммуникация
- **Network** — мониторинг состояния сети (NWPathMonitor)
- **URLSession** — HTTP запросы к API

### Мультимедиа
- **Speech** — распознавание речи на русском языке (SFSpeechRecognizer)
- **AVFoundation** — обработка видео и аудио
- **WebKit** — отображение контента (WKWebView для HTML, PDF, изображений)

### Безопасность
- **Security** — хранение данных в Keychain
- **App Groups** — безопасный обмен данными между приложением и расширениями

## Тестирование

Проект включает comprehensive тестовое покрытие:

### Типы тестов

- **Unit тесты** — тестирование моделей, сервисов, ViewModels
- **UI тесты** — автоматизированное тестирование пользовательского интерфейса
- **Share Extension тесты** — тестирование функциональности Share Extension

### Запуск тестов

```bash
# Запуск всех тестов
xcodebuild test -scheme VoiceBookmarks -destination 'platform=iOS Simulator,name=iPhone 15'

# Запуск только unit тестов
xcodebuild test -scheme VoiceBookmarks -only-testing:VoiceBookmarksTests -destination 'platform=iOS Simulator,name=iPhone 15'

# Запуск только UI тестов
xcodebuild test -scheme VoiceBookmarks -only-testing:VoiceBookmarksUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

### UI тесты с моками

Приложение поддерживает специальные режимы для UI тестов:
- `--UITestSeedFolders` — использование мокового SearchService для тестирования
- `--UITestShareSeed` — специальный режим для тестирования Share Extension

## Структура проекта

```
VoiceBookmarks/
├── VoiceBookmarks/                      # Основное приложение
│   ├── App/
│   │   └── VoiceBookmarksApp.swift      # Точка входа, инициализация сервисов
│   ├── Models/                          # Модели данных
│   │   ├── Bookmark.swift               # Модель закладки с нормализацией типа
│   │   ├── Folder.swift                 # Иерархические папки
│   │   ├── ContentType.swift            # Типы контента (text, audio, video, image, file)
│   │   ├── SearchResponse.swift          # Результаты поиска
│   │   ├── CommandResponse.swift        # Результаты выполнения команд
│   │   └── ...
│   ├── Views/                           # SwiftUI представления
│   │   ├── MainTabView.swift            # Главный экран с вкладками
│   │   ├── Components/                  # Переиспользуемые компоненты
│   │   │   ├── ContentPreviewView.swift # Превью контента
│   │   │   ├── ToastView.swift          # Уведомления
│   │   │   ├── TranscriptionView.swift  # Отображение транскрипции
│   │   │   └── ...
│   │   ├── Search/                      # Экран поиска
│   │   │   ├── SearchView.swift
│   │   │   ├── FolderListView.swift     # Список папок
│   │   │   ├── FileListView.swift       # Список файлов
│   │   │   └── ...
│   │   ├── Share/                       # Экран сохранения
│   │   │   └── ShareView.swift
│   │   └── WebView/                     # Просмотр контента
│   │       ├── WebContentView.swift
│   │       ├── ImagePreviewView.swift
│   │       ├── VideoPreviewView.swift
│   │       └── ...
│   ├── ViewModels/                      # Бизнес-логика
│   │   ├── ShareViewModel.swift         # Логика сохранения контента
│   │   ├── SearchViewModel.swift        # Логика поиска
│   │   ├── WebViewModel.swift           # Логика просмотра контента
│   │   └── TranscriptionProcessingExtension.swift
│   ├── Services/
│   │   ├── API/                         # API сервисы
│   │   │   ├── AuthService.swift
│   │   │   ├── BookmarkService.swift
│   │   │   └── SearchService.swift
│   │   └── Core/                        # Основные сервисы
│   │       ├── NetworkService.swift
│   │       ├── NetworkMonitor.swift
│   │       ├── OfflineQueueService.swift
│   │       ├── SpeechService.swift
│   │       ├── TextPostProcessor.swift  # Обработка транскрипции
│   │       ├── TranscriptionMerger.swift # Слияние результатов
│   │       ├── BookmarkCacheService.swift
│   │       ├── FolderCacheService.swift
│   │       ├── LoggerService.swift
│   │       └── ...
│   ├── Persistence/
│   │   └── PersistenceController.swift  # Core Data контроллер
│   └── Utils/
│       ├── Constants.swift              # Централизованные константы
│       ├── SharedUserDefaults.swift     # Общий UserDefaults для App Group
│       └── Extensions/                  # Расширения Swift
├── VoiceBookmarksShareExtension/        # Share Extension
│   ├── ShareViewController.swift
│   └── ShareExtensionView.swift
├── VoiceBookmarksTests/                 # Unit тесты
│   ├── Models/
│   ├── Services/
│   ├── ViewModels/
│   └── Mocks/                           # Моки для тестирования
├── VoiceBookmarksUITests/               # UI тесты
├── VoiceBookmarksShareExtensionTests/   # Тесты Share Extension
├── VoiceBookmarks.xcodeproj/            # Xcode проект
├── swagger.yaml                         # API спецификация
└── LICENSE                              # Лицензия Apache 2.0
```

## Разрешения

Приложение запрашивает следующие разрешения:

- **Микрофон** (`NSMicrophoneUsageDescription`) — для записи голосовых заметок
- **Распознавание речи** (`NSSpeechRecognitionUsageDescription`) — для голосового ввода на русском языке

Разрешения запрашиваются только при первом использовании соответствующих функций.

## Настройки и конфигурация

### Константы приложения

Все настройки централизованы в `Constants.swift`:

- **API**: base URL, таймауты, endpoints, заголовки
- **Speech**: locale (ru-RU), таймауты распознавания, максимальная длительность
- **Files**: максимальный размер (500 MB), качество сжатия
- **UI**: анимации, размеры, цвета, иконки
- **Keychain**: ключи для хранения данных
- **App Groups**: identifier для обмена данными
- **Core Data**: имя модели и контейнера
- **Categories**: предопределенные категории

### Чувствительные данные

Перед публикацией в публичный репозиторий все чувствительные данные заменены на placeholder значения:

- API Base URL: `https://minds.myapp.fund/weaviate`
- App Group Identifier: `group.com.yourcompany.yourapp` (замените на ваш)
- Keychain Service: `com.yourcompany.yourapp.keychain` (замените на ваш bundle identifier)
- URL Scheme: `yourapp` (замените на ваш)
- OSLog Subsystem: `com.yourcompany.yourapp` (замените на ваш bundle identifier)

Все эти значения необходимо настроить перед использованием приложения (см. раздел "Установка").

### App Groups

Для работы Share Extension необходимо настроить App Group:
- **Identifier**: Настраивается в Xcode Capabilities (по умолчанию: `group.com.yourcompany.yourapp`)
- Используется для обмена данными между приложением и Share Extension
- Не забудьте обновить значение в `Constants.swift` после настройки в Xcode

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Лицензия

Проект распространяется под лицензией Apache License 2.0. См. файл [LICENSE](LICENSE) для подробностей.

## Контакты

Для вопросов и предложений создайте issue в репозитории.
