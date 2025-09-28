//
//  ShareViewController.swift
//  VoiceBookmarksShareExtension
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers
import SwiftUI

// MARK: - Share Extension: принимает контент из других приложений и добавляет в очередь загрузки

class ShareViewController: UIViewController {
    
    private let logger = LoggerService.shared
    
    
    /// Lazy очередь: Core Data может быть не готов при старте, используем общий App Group контейнер
    /// Share Extension использует PersistenceController.sharedForExtension для доступа к Core Data
    private lazy var offlineQueue: OfflineQueueService = {
        print("[SHARE EXT] Инициализация OfflineQueueService с PersistenceController.sharedForExtension")
        let controller = PersistenceController.sharedForExtension
        let hasStores = !controller.container.persistentStoreDescriptions.isEmpty
        if hasStores {
            print("[SHARE EXT] Core Data persistentStoreCoordinator загружен")
        } else {
            print("[SHARE EXT] ОШИБКА: Core Data persistentStoreDescriptions пуст")
            logger.error("Core Data не загружен в Share Extension", category: .storage)
        }
        return OfflineQueueService(persistenceController: controller)
    }()
    private let fileService = FileService.shared
    
    
    private var hostingController: UIHostingController<ShareExtensionView>?
    private var shareExtensionViewModel: ShareExtensionViewModel?
    
    
    /// Сохраняем контекст из beginRequest, так как extensionContext может быть nil в viewDidLoad
    private var extensionContextForRequest: NSExtensionContext?
    private var lastAddedFilePath: String?
    private var hasCompletedContext = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.extensionContextForRequest != nil || self.extensionContext != nil {
                self.extractSharedContent()
            }
        }
    }
    
    
    /// Настройка UI: создание SwiftUI view через UIHostingController
    private func setupUI() {
        let viewModel = ShareExtensionViewModel()
        self.shareExtensionViewModel = viewModel
        
        viewModel.isLoading = true
        viewModel.statusMessage = "Добавление контента..."
        viewModel.showSuccess = false
        viewModel.showError = false
        
        let shareView = ShareExtensionView(viewModel: viewModel)
        
        let hostingController = UIHostingController(rootView: shareView)
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }

    
    /// Извлекает контент из Share Extension: приоритет обработки — изображения > видео > аудио > URL > текст > файлы
    /// Проверяет оба источника контекста (extensionContextForRequest и extensionContext)
    private func extractSharedContent() {
        shareExtensionViewModel?.isLoading = true
        shareExtensionViewModel?.updateStatus(message: "Обработка контента...", isSuccess: false)
        
        let extensionContext = extensionContextForRequest ?? self.extensionContext
        
        guard let extensionContext = extensionContext else {
            logger.error("Extension context недоступен", category: .fileOperation)
            logger.error("extensionContextForRequest: \(extensionContextForRequest != nil ? "есть" : "nil")", category: .fileOperation)
            logger.error("self.extensionContext: \(self.extensionContext != nil ? "есть" : "nil")", category: .fileOperation)
            shareExtensionViewModel?.showError("Ошибка доступа к контенту")
            showErrorAndClose()
            return
        }
        
        guard !extensionContext.inputItems.isEmpty else {
            logger.error("Нет inputItems в extension context", category: .fileOperation)
            shareExtensionViewModel?.showError("Нет контента для добавления")
            showErrorAndClose()
            return
        }
        
        var foundItem = false
        
        for inputItem in extensionContext.inputItems {
            guard let extensionItem = inputItem as? NSExtensionItem,
                  let attachments = extensionItem.attachments,
                  !attachments.isEmpty else {
                continue
            }
            
            for (_, itemProvider) in attachments.enumerated() {
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            shareExtensionViewModel?.updateStatus(message: "Обработка изображения...", isSuccess: false)
            handleImage(itemProvider)
                    foundItem = true
                    return
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            shareExtensionViewModel?.updateStatus(message: "Обработка видео...", isSuccess: false)
            handleVideo(itemProvider)
                    foundItem = true
                    return
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
            shareExtensionViewModel?.updateStatus(message: "Обработка аудио...", isSuccess: false)
            handleAudio(itemProvider, preferredIdentifier: UTType.audio.identifier)
                    foundItem = true
                    return
                } else if itemProvider.hasItemConformingToTypeIdentifier("public.audio") {
                    shareExtensionViewModel?.updateStatus(message: "Обработка аудио...", isSuccess: false)
                    handleAudio(itemProvider, preferredIdentifier: "public.audio")
                    foundItem = true
                    return
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            shareExtensionViewModel?.updateStatus(message: "Обработка ссылки...", isSuccess: false)
            handleURL(itemProvider)
                    foundItem = true
                    return
                } else if itemProvider.hasItemConformingToTypeIdentifier("public.url") {
                    shareExtensionViewModel?.updateStatus(message: "Обработка ссылки...", isSuccess: false)
                    handleURL(itemProvider)
                    foundItem = true
                    return
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            shareExtensionViewModel?.updateStatus(message: "Обработка текста...", isSuccess: false)
            handleText(itemProvider)
                    foundItem = true
                    return
                } else if itemProvider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    shareExtensionViewModel?.updateStatus(message: "Обработка текста...", isSuccess: false)
                    handleText(itemProvider)
                    foundItem = true
                    return
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            shareExtensionViewModel?.updateStatus(message: "Обработка файла...", isSuccess: false)
            handleFile(itemProvider)
                    foundItem = true
                    return
                } else if itemProvider.hasItemConformingToTypeIdentifier("public.file-url") {
                    shareExtensionViewModel?.updateStatus(message: "Обработка файла...", isSuccess: false)
                    handleFile(itemProvider)
                    foundItem = true
                    return
                }
            }
        }
        
        if !foundItem {
            let allTypes = extensionContext.inputItems
                .compactMap { $0 as? NSExtensionItem }
                .flatMap { $0.attachments ?? [] }
                .flatMap { $0.registeredTypeIdentifiers }
            
            logger.error("Неподдерживаемый тип контента. Доступные типы: \(allTypes)", category: .fileOperation)
            shareExtensionViewModel?.isLoading = false
            shareExtensionViewModel?.showError("Неподдерживаемый тип контента")
            showErrorAndClose()
        }
    }
    
    
    /// Обработка изображения: поддержка URL/UIImage/Data, копирование в App Group
    /// Приоритет: URL > UIImage (конвертация в JPEG) > Data
    private func handleImage(_ itemProvider: NSItemProvider) {
        let typeIdentifier = itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            ? UTType.image.identifier
            : "public.image"
        
        let options: [AnyHashable: Any] = [:]
        
        itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: options) { item, error in
            DispatchQueue.main.async {
            if let error = error {
                self.logger.error("Ошибка загрузки изображения: \(error.localizedDescription)", category: .fileOperation)
                self.shareExtensionViewModel?.isLoading = false
                self.shareExtensionViewModel?.showError("Ошибка загрузки изображения: \(error.localizedDescription)")
                self.showErrorAndClose()
                return
            }
            
            guard let item = item else {
                self.logger.error("loadItem вернул nil (item = nil, error = \(error?.localizedDescription ?? "nil"))", category: .fileOperation)
                self.shareExtensionViewModel?.isLoading = false
                self.shareExtensionViewModel?.showError("Не удалось загрузить изображение")
                self.showErrorAndClose()
                return
            }
            
            if let url = item as? URL {
                self.saveToQueue(fileURL: url)
                } else if let image = item as? UIImage {
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        if let tempURL = self.fileService.saveToTemporaryDirectory(data: imageData, fileName: "image_\(Date().timeIntervalSince1970).jpg") {
                            self.saveToQueue(fileURL: tempURL)
                        } else {
                            self.logger.error("Не удалось сохранить временный файл изображения", category: .fileOperation)
                            self.shareExtensionViewModel?.isLoading = false
                            self.shareExtensionViewModel?.showError("Не удалось сохранить изображение")
                            self.showErrorAndClose()
                        }
                    } else {
                        self.logger.error("Не удалось конвертировать UIImage в JPEG", category: .fileOperation)
                        self.shareExtensionViewModel?.isLoading = false
                        self.shareExtensionViewModel?.showError("Не удалось обработать изображение")
                        self.showErrorAndClose()
                    }
                } else if let data = item as? Data {
                    if let tempURL = self.fileService.saveToTemporaryDirectory(data: data, fileName: "image_\(Date().timeIntervalSince1970).jpg") {
                        self.saveToQueue(fileURL: tempURL)
                    } else {
                        self.logger.error("Не удалось сохранить временный файл изображения", category: .fileOperation)
                        self.shareExtensionViewModel?.isLoading = false
                        self.shareExtensionViewModel?.showError("Не удалось сохранить изображение")
                        self.showErrorAndClose()
                    }
                } else {
                    self.logger.error("Неизвестный тип изображения. Тип элемента: \(type(of: item))", category: .fileOperation)
                    self.logger.error("Значение элемента: \(String(describing: item))", category: .fileOperation)
                    self.shareExtensionViewModel?.isLoading = false
                    self.shareExtensionViewModel?.showError("Не удалось обработать изображение")
                    self.showErrorAndClose()
                }
            }
        }
    }
    
    /// Обработка видео: URL из itemProvider, копирование в App Group
    private func handleVideo(_ itemProvider: NSItemProvider) {
        let typeIdentifier = itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            ? UTType.movie.identifier
            : "public.movie"
        
        let options: [AnyHashable: Any] = [:]
        
        itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: options) { item, error in
            DispatchQueue.main.async {
            if let error = error {
                self.logger.error("Ошибка загрузки видео: \(error.localizedDescription)", category: .fileOperation)
                self.shareExtensionViewModel?.isLoading = false
                self.shareExtensionViewModel?.showError("Ошибка загрузки видео: \(error.localizedDescription)")
                self.showErrorAndClose()
                return
            }
            
            guard let item = item else {
                self.logger.error("loadItem вернул nil для видео", category: .fileOperation)
                self.shareExtensionViewModel?.isLoading = false
                self.shareExtensionViewModel?.showError("Не удалось загрузить видео")
                self.showErrorAndClose()
                return
            }
            
            if let url = item as? URL {
                self.saveToQueue(fileURL: url)
                } else {
                    self.logger.error("Не удалось обработать видео. Тип элемента: \(type(of: item))", category: .fileOperation)
                    self.logger.error("Значение элемента: \(String(describing: item))", category: .fileOperation)
                    self.shareExtensionViewModel?.isLoading = false
                    self.shareExtensionViewModel?.showError("Не удалось обработать видео")
                    self.showErrorAndClose()
                }
            }
        }
    }
    
    /// Обработка аудио: поддержка URL/Data, копирование в App Group
    /// Использует loadFileRepresentation для получения файла, fallback на loadItem
    private func handleAudio(_ itemProvider: NSItemProvider, preferredIdentifier: String) {
        let audioIdentifier = preferredIdentifier
        itemProvider.loadFileRepresentation(forTypeIdentifier: audioIdentifier) { url, error in
            if error != nil {
                self.loadAudioItem(itemProvider: itemProvider, typeIdentifier: audioIdentifier)
                return
            }
            
            guard let fileURL = url else {
                self.loadAudioItem(itemProvider: itemProvider, typeIdentifier: audioIdentifier)
                return
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                let fileName = self.generateAudioFileName(originalName: fileURL.lastPathComponent, typeIdentifier: audioIdentifier)
                
                DispatchQueue.main.async {
                    if let tempURL = self.fileService.saveToTemporaryDirectory(data: data, fileName: fileName) {
                        self.saveToQueue(fileURL: tempURL)
                    } else {
                        self.logger.error("Не удалось сохранить временный аудио файл", category: .fileOperation)
                        self.shareExtensionViewModel?.isLoading = false
                        self.shareExtensionViewModel?.showError("Не удалось сохранить аудио")
                        self.showErrorAndClose()
                    }
                }
            } catch {
                self.logger.error("Ошибка чтения аудио из временного файла: \(error.localizedDescription)", category: .fileOperation)
                self.loadAudioItem(itemProvider: itemProvider, typeIdentifier: audioIdentifier)
            }
        }
    }
    
    private func loadAudioItem(itemProvider: NSItemProvider, typeIdentifier: String) {
        let options: [AnyHashable: Any] = [:]
        
        itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: options) { item, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.logger.error("Ошибка загрузки аудио: \(error.localizedDescription)", category: .fileOperation)
                    self.shareExtensionViewModel?.isLoading = false
                    self.shareExtensionViewModel?.showError("Ошибка загрузки аудио: \(error.localizedDescription)")
                    self.showErrorAndClose()
                    return
                }
                
                guard let item = item else {
                    self.logger.error("loadItem для аудио вернул nil", category: .fileOperation)
                    self.shareExtensionViewModel?.isLoading = false
                    self.shareExtensionViewModel?.showError("Не удалось загрузить аудио")
                    self.showErrorAndClose()
                    return
                }
                
                if let url = item as? URL {
                    self.saveToQueue(fileURL: url)
                } else if let data = item as? Data {
                    let fileName = self.generateAudioFileName(originalName: "audio", typeIdentifier: typeIdentifier)
                    if let tempURL = self.fileService.saveToTemporaryDirectory(data: data, fileName: fileName) {
                        self.saveToQueue(fileURL: tempURL)
                    } else {
                        self.logger.error("Не удалось сохранить аудио во временный файл", category: .fileOperation)
                        self.shareExtensionViewModel?.isLoading = false
                        self.shareExtensionViewModel?.showError("Не удалось сохранить аудио")
                        self.showErrorAndClose()
                    }
                } else {
                    self.logger.error("Неизвестный тип аудио элемента: \(type(of: item))", category: .fileOperation)
                    self.shareExtensionViewModel?.isLoading = false
                    self.shareExtensionViewModel?.showError("Не удалось обработать аудио")
                    self.showErrorAndClose()
                }
            }
        }
    }
    
    private func generateAudioFileName(originalName: String, typeIdentifier: String) -> String {
        if !originalName.isEmpty, originalName.contains(".") {
            return originalName
        }
        
        if let utType = UTType(typeIdentifier) {
            let ext = utType.preferredFilenameExtension ?? "m4a"
            return "audio_\(UUID().uuidString.prefix(8)).\(ext)"
        }
        
        return "audio_\(UUID().uuidString.prefix(8)).m4a"
    }
    
    /// Обработка URL: создание HTML страницы для сохранения ссылки
    /// Если URL является file URL, сохраняет файл напрямую, иначе создает HTML страницу
    private func handleURL(_ itemProvider: NSItemProvider) {
        let typeIdentifier = itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) 
            ? UTType.url.identifier 
            : "public.url"
        
        itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
            DispatchQueue.main.async {
            if let error = error {
                self.logger.error("Ошибка загрузки URL: \(error.localizedDescription)", category: .fileOperation)
                self.shareExtensionViewModel?.isLoading = false
                self.shareExtensionViewModel?.showError("Ошибка загрузки URL: \(error.localizedDescription)")
                self.showErrorAndClose()
                return
            }
            
            guard let item = item else {
                self.logger.error("loadItem вернул nil для URL", category: .fileOperation)
                self.shareExtensionViewModel?.isLoading = false
                self.shareExtensionViewModel?.showError("Не удалось загрузить URL")
                self.showErrorAndClose()
                return
            }
            
                var url: URL?
                
                if let urlValue = item as? URL {
                    url = urlValue
                } else if let urlString = item as? String {
                    url = URL(string: urlString)
                } else if let data = item as? Data,
                          let urlString = String(data: data, encoding: .utf8) {
                    url = URL(string: urlString)
                }
                
                if let url = url {
                    if url.isFileURL {
                        self.saveToQueue(fileURL: url)
                    } else {
                        self.downloadAndSaveURL(url: url)
                    }
                } else {
                    self.logger.error("Не удалось конвертировать URL. Тип элемента: \(type(of: item))", category: .fileOperation)
                    self.logger.error("Значение элемента: \(String(describing: item))", category: .fileOperation)
                    self.shareExtensionViewModel?.isLoading = false
                    self.shareExtensionViewModel?.showError("Не удалось обработать URL")
                    self.showErrorAndClose()
                }
            }
        }
    }
    
    private func downloadAndSaveURL(url: URL) {
        let urlString = url.absoluteString
        let html = """
        <!doctype html>
        <html lang="ru"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Saved Link</title>
        <style>
          body { font-family: -apple-system, system-ui, Helvetica, Arial; padding: 16px; background: white; }
          .link-container { max-width: 600px; margin: 0 auto; }
          h1 { color: #333; border-bottom: 2px solid #FFD700; padding-bottom: 10px; }
          a { color: #007AFF; text-decoration: none; word-break: break-all; }
          a:hover { text-decoration: underline; }
          .timestamp { color: #999; font-size: 0.9em; margin-top: 20px; }
        </style></head><body>
        <div class="link-container">
          <h1>Сохраненная ссылка</h1>
          <p><a href="\(urlString)" target="_blank">\(urlString)</a></p>
          <p class="timestamp">Сохранено: \(self.getCurrentTimestamp())</p>
        </div>
        </body></html>
        """
        
        guard let htmlData = html.data(using: .utf8) else {
            logger.error("Не удалось создать HTML данные", category: .fileOperation)
            shareExtensionViewModel?.isLoading = false
            shareExtensionViewModel?.showError("Не удалось обработать ссылку")
            showErrorAndClose()
            return
        }
        
        self.saveDataToQueue(data: htmlData, fileName: "webpage.html")
    }
    
    private func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: Date())
    }
    
    /// Обработка текста: сохранение в очередь как текстовый файл
    /// Если текст является URL, обрабатывает как URL, иначе сохраняет как текстовый файл
    private func handleText(_ itemProvider: NSItemProvider) {
        let typeIdentifier = itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier)
            ? UTType.text.identifier
            : "public.plain-text"
        
        itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
            DispatchQueue.main.async {
            if let error = error {
                self.logger.error("Ошибка загрузки текста: \(error.localizedDescription)", category: .fileOperation)
                self.shareExtensionViewModel?.isLoading = false
                self.shareExtensionViewModel?.showError("Ошибка загрузки текста: \(error.localizedDescription)")
                self.showErrorAndClose()
                return
            }
            
            guard let item = item else {
                self.logger.error("loadItem вернул nil для текста", category: .fileOperation)
                self.shareExtensionViewModel?.isLoading = false
                self.shareExtensionViewModel?.showError("Не удалось загрузить текст")
                self.showErrorAndClose()
                return
            }
            
                var text: String?
                
                if let textValue = item as? String {
                    text = textValue
                } else if let data = item as? Data,
                          let textValue = String(data: data, encoding: .utf8) {
                    text = textValue
                } else if let url = item as? URL {
                    self.downloadAndSaveURL(url: url)
                    return
                }
                
                if let text = text {
                    if let url = URL(string: text), url.scheme != nil {
                        self.downloadAndSaveURL(url: url)
                    } else {
                        self.saveTextToQueue(text: text)
                    }
                } else {
                    self.logger.error("Не удалось конвертировать текст. Тип элемента: \(type(of: item))", category: .fileOperation)
                    self.logger.error("Значение элемента: \(String(describing: item))", category: .fileOperation)
                    self.shareExtensionViewModel?.isLoading = false
                    self.shareExtensionViewModel?.showError("Не удалось обработать текст")
                    self.showErrorAndClose()
                }
            }
        }
    }
    
    /// Обработка файла: поддержка URL/String, копирование в App Group
    private func handleFile(_ itemProvider: NSItemProvider) {
        let typeIdentifier = itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            ? UTType.fileURL.identifier
            : "public.file-url"
        
        let options: [AnyHashable: Any] = [:]
        
        itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: options) { item, error in
            DispatchQueue.main.async {
            if let error = error {
                self.logger.error("Ошибка загрузки файла: \(error.localizedDescription)", category: .fileOperation)
                self.shareExtensionViewModel?.isLoading = false
                self.shareExtensionViewModel?.showError("Ошибка загрузки файла: \(error.localizedDescription)")
                self.showErrorAndClose()
                return
            }
            
            guard let item = item else {
                self.logger.error("loadItem вернул nil для файла", category: .fileOperation)
                self.shareExtensionViewModel?.isLoading = false
                self.shareExtensionViewModel?.showError("Не удалось загрузить файл")
                self.showErrorAndClose()
                return
            }
            
            if let url = item as? URL {
                    self.saveToQueue(fileURL: url)
                } else if let urlString = item as? String,
                          let url = URL(string: urlString) {
                self.saveToQueue(fileURL: url)
                } else {
                    self.logger.error("Не удалось обработать файл. Тип элемента: \(type(of: item))", category: .fileOperation)
                    self.logger.error("Значение элемента: \(String(describing: item))", category: .fileOperation)
                    self.shareExtensionViewModel?.isLoading = false
                    self.shareExtensionViewModel?.showError("Не удалось обработать файл")
                    self.showErrorAndClose()
                }
            }
        }
    }
    
    
    /// Сохраняет файл в офлайн очередь: копирует в App Group контейнер, проверяет дубликаты, освобождает security-scoped URL
    /// Использует background queue для копирования файла, чтобы не блокировать UI
    private func saveToQueue(fileURL: URL) {
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        
        Task.detached(priority: .userInitiated) {
            do {
                let copiedURL = try await MainActor.run {
                    try self.fileService.copyToAppGroupContainer(from: fileURL)
                }
                
                if hasAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
                
                let fileInQueue = await self.offlineQueue.isFileInQueue(filePath: copiedURL.path)
                if fileInQueue {
                    
                    await MainActor.run {
                        SharedUserDefaults.clearLastSharedItem()
                        self.shareExtensionViewModel?.isLoading = false
                        self.shareExtensionViewModel?.updateStatus(
                            message: "Контент уже в очереди",
                            isSuccess: true
                        )
                        self.showSuccessAndClose()
                    }
                    return
                }
                
                var success = await MainActor.run {
                    self.offlineQueue.addToQueue(
                    filePath: copiedURL.path,
                    voiceNote: nil,
                    summary: nil
                )
                }
                
                if !success {
                    success = SharedUserDefaults.saveShareExtensionQueueItem(
                        filePath: copiedURL.path,
                        voiceNote: nil,
                        summary: nil
                    )
                }
                
                let finalSuccess = success
                
                await MainActor.run {
                    if finalSuccess {
                        self.lastAddedFilePath = copiedURL.path
                        
                        SharedUserDefaults.setLastSharedItem(filePath: copiedURL.path)
                        SharedUserDefaults.requestShareTabSelection()
                        self.shareExtensionViewModel?.isLoading = false
                        self.shareExtensionViewModel?.updateStatus(
                            message: "Контент успешно добавлен",
                            isSuccess: true
                        )
                        self.showSuccessAndClose()
                    } else {
                        print("[SHARE EXT] ОШИБКА: Не удалось добавить в очередь")
                        self.logger.error("Не удалось добавить в очередь", category: .fileOperation)
                        self.shareExtensionViewModel?.isLoading = false
                        self.shareExtensionViewModel?.showError("Не удалось добавить в очередь")
                        self.showErrorAndClose()
                    }
                }
                
            } catch {
                print("[SHARE EXT] ОШИБКА копирования: \(error.localizedDescription)")
                self.logger.error("Ошибка копирования файла: \(error.localizedDescription)", category: .fileOperation)
                self.logger.error("Детали ошибки: \(error)", category: .fileOperation)
                
                if hasAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
                
                await MainActor.run {
                    self.shareExtensionViewModel?.isLoading = false
                    
                    let userMessage = error.localizedDescription.contains("App Group") 
                        ? "Ошибка доступа к хранилищу. Попробуйте еще раз."
                        : "Ошибка обработки файла: \(error.localizedDescription)"
                    
                    self.shareExtensionViewModel?.showError(userMessage)
                    self.showErrorAndClose()
                }
            }
        }
    }
    
    private func saveTextToQueue(text: String) {
        DispatchQueue.main.async {
        let data = text.data(using: .utf8) ?? Data()
            self.saveDataToQueue(data: data, fileName: "text.txt")
        }
    }
    
    /// Сохранение данных в очередь: создает временный файл и добавляет в очередь
    private func saveDataToQueue(data: Data, fileName: String) {
        DispatchQueue.main.async {
            if let tempURL = self.fileService.saveToTemporaryDirectory(data: data, fileName: fileName) {
                self.saveToQueue(fileURL: tempURL)
        } else {
                self.shareExtensionViewModel?.showError("Не удалось сохранить файл")
                self.showErrorAndClose()
            }
        }
    }
    
    
    /// Показ успеха и закрытие Share Extension
    private func showSuccessAndClose() {
        finishAndOpenHost(success: true)
    }
    
    /// Показ ошибки и закрытие Share Extension
    private func showErrorAndClose() {
        finishAndOpenHost(success: false)
    }
    
    
    /// Открывает основное приложение через deep link: пробует extensionContext → windowScene → UIApplication → responder chain
    /// Fallback цепочка для надежного открытия основного приложения из Share Extension
    /// Замените на ваш URL scheme (должен быть настроен в Info.plist)
    private func openHostApp(completion: ((Bool) -> Void)? = nil) {
        guard !ProcessInfo.processInfo.arguments.contains("--UITestShareDisableLaunch"),
              let url = URL(string: "yourapp://share-extension") else {
            completion?(false)
            return
        }
        
        DispatchQueue.main.async {
            let attemptRequestScene: () -> Void = {
                if self.requestSceneActivation(url: url) {
                    completion?(true)
                } else {
                    completion?(false)
                }
            }
            
            let attemptResponderChain: () -> Void = {
                if self.openHostAppViaResponderChain(url: url, completion: completion, onFailure: attemptRequestScene) == false {
                    attemptRequestScene()
                }
            }
            
            let attemptUIApplication: () -> Void = {
                if self.openHostAppViaUIApplication(url: url, completion: completion, onFailure: attemptResponderChain) == false {
                    attemptResponderChain()
                }
            }
            
            let attemptWindowScene: () -> Void = {
                if self.openHostAppViaWindowScene(url: url, completion: completion, onFailure: attemptUIApplication) == false {
                    attemptUIApplication()
                }
            }
            
            if let context = self.extensionContextForRequest ?? self.extensionContext {
                context.open(url, completionHandler: { success in
                    success ? completion?(true) : attemptWindowScene()
                })
            } else {
                attemptWindowScene()
            }
        }
    }
    
#if canImport(UIKit)
    @discardableResult
    private func openHostAppViaWindowScene(url: URL, completion: ((Bool) -> Void)?, onFailure: @escaping () -> Void) -> Bool {
        if #available(iOS 13.0, *), let scene = self.view.window?.windowScene {
            scene.open(url, options: UIScene.OpenExternalURLOptions()) { success in
                success ? completion?(true) : onFailure()
            }
            return true
        }
        return false
    }
    
    @discardableResult
    private func openHostAppViaUIApplication(url: URL, completion: ((Bool) -> Void)?, onFailure: @escaping () -> Void) -> Bool {
        if let sharedApplication = UIApplication.perform(NSSelectorFromString("sharedApplication"))?
            .takeUnretainedValue() as? UIApplication {
            sharedApplication.open(url, options: [:]) { success in
                success ? completion?(true) : onFailure()
            }
            return true
        }
        return false
    }
    
    private func openHostAppViaResponderChain(url: URL, completion: ((Bool) -> Void)?, onFailure: @escaping () -> Void) -> Bool {
        var responder: UIResponder? = self.view
        
        while let currentResponder = responder {
            if let application = currentResponder as? UIApplication {
                application.open(url, options: [:]) { success in
                    success ? completion?(true) : onFailure()
                }
                return true
            }
            responder = currentResponder.next
        }
        
        return false
    }
    
    @discardableResult
    private func requestSceneActivation(url: URL) -> Bool {
        if #available(iOS 13.0, *),
           let sharedApplication = UIApplication.perform(NSSelectorFromString("sharedApplication"))?
                .takeUnretainedValue() as? UIApplication {
            let activationOptions = UIScene.ActivationRequestOptions()
            sharedApplication.requestSceneSessionActivation(nil, userActivity: nil, options: activationOptions) { _ in }
            sharedApplication.open(url, options: [:]) { _ in }
            return true
        }
        return false
    }
#endif
    
    /// Завершает Share Extension: открывает основное приложение через deep link, вызывает completeRequest
    /// Сохраняет timestamp для отслеживания времени открытия основного приложения
    private func finishAndOpenHost(success: Bool) {
        guard !hasCompletedContext else {
            return
        }
        hasCompletedContext = true

        let context = extensionContextForRequest ?? self.extensionContext
        let attemptTimestamp = Date().timeIntervalSince1970
        SharedUserDefaults.setOpenHostAttempt(timestamp: attemptTimestamp)

        openHostApp { _ in
            if let context = context {
                context.completeRequest(returningItems: [], completionHandler: { _ in })
            }
        }
    }
}

