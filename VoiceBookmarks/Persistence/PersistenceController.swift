//
//  PersistenceController.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import CoreData
import Foundation

// MARK: - Core Data контроллер: основной экземпляр, Share Extension (App Group), тесты (in-memory)

final class PersistenceController {
    
    static let shared = PersistenceController()
    
    static let sharedForExtension = PersistenceController(inMemory: false, useAppGroup: true)
    
    static let preview = PersistenceController(inMemory: true)
    
    let container: NSPersistentContainer
    
    
    /// Флаг готовности persistent stores (thread-safe через storeLoadLock)
    private var isStoreLoaded = false
    private let storeLoadLock = NSLock()
    
    
    /// Основной view context для UI (main thread)
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    /// Создание background context для async операций (background thread)
    func newBackgroundContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }
    
    /// Проверка готовности persistent stores (thread-safe)
    var isReady: Bool {
        storeLoadLock.lock()
        defer { storeLoadLock.unlock() }
        return isStoreLoaded
    }
    
    private let logger = LoggerService.shared
    
    
    /// Инициализация Core Data контроллера
    /// - Parameters:
    ///   - inMemory: использовать in-memory store (для тестов/preview)
    ///   - useAppGroup: использовать App Group для Share Extension
    init(inMemory: Bool = false, useAppGroup: Bool = false) {
        let bundle: Bundle
        if Bundle.main.bundleURL.pathExtension == "appex" {
            let mainAppBundleURL = Bundle.main.bundleURL
                .deletingLastPathComponent()

                .deletingLastPathComponent()

                .appendingPathComponent("VoiceBookmarks.app")
            
            if let mainAppBundle = Bundle(url: mainAppBundleURL) {
                bundle = mainAppBundle
                logger.info("Share Extension: используем bundle основного приложения для Core Data модели", category: .storage)
            } else {
                bundle = Bundle.main
                logger.warning("Share Extension: не удалось найти bundle основного приложения, используем Bundle.main", category: .storage)
            }
        } else {
            bundle = Bundle.main
        }
        
        let modelURL = bundle.url(forResource: Constants.CoreData.modelName, withExtension: "momd")
        
        if let modelURL = modelURL {
            logger.info("Core Data модель найдена: \(modelURL.path)", category: .storage)
            if let model = NSManagedObjectModel(contentsOf: modelURL) {
                container = NSPersistentContainer(name: Constants.CoreData.modelName, managedObjectModel: model)
            } else {
                logger.critical("Не удалось загрузить Core Data модель из: \(modelURL.path)", category: .storage)
                container = NSPersistentContainer(name: Constants.CoreData.modelName)
            }
        } else {
            logger.critical("Core Data модель не найдена: \(Constants.CoreData.modelName).momd в bundle: \(bundle.bundleIdentifier ?? "unknown")", category: .storage)
            container = NSPersistentContainer(name: Constants.CoreData.modelName)
        }
        
        if container.persistentStoreDescriptions.isEmpty {
            container.persistentStoreDescriptions.append(NSPersistentStoreDescription())
        }
        
        
        if inMemory {
            let description = container.persistentStoreDescriptions.first!
            description.type = NSInMemoryStoreType
            description.url = nil
            logger.debug("Core Data: in-memory mode", category: .storage)
        } else if useAppGroup {
            if let appGroupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Constants.AppGroups.identifier
            ) {
                let storeURL = appGroupURL.appendingPathComponent("\(Constants.CoreData.modelName).sqlite")
                container.persistentStoreDescriptions.first?.url = storeURL
                logger.info("Core Data использует App Group: \(storeURL.path)", category: .storage)
            } else {
                logger.error("Не удалось получить App Group container URL, используем стандартный путь", category: .storage)
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let fallbackURL = documentsPath.appendingPathComponent("\(Constants.CoreData.modelName).sqlite")
                container.persistentStoreDescriptions.first?.url = fallbackURL
                logger.warning("Core Data использует fallback путь: \(fallbackURL.path)", category: .storage)
            }
        }
        
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        
        container.loadPersistentStores { description, error in
            self.storeLoadLock.lock()
            defer { self.storeLoadLock.unlock() }
            
            if let error = error {
                self.isStoreLoaded = false
                self.logger.critical("Core Data ошибка загрузки: \(error.localizedDescription)", category: .storage)
            } else {
                self.isStoreLoaded = true
                self.logger.info("Core Data загружен: \(description.url?.path ?? "unknown")", category: .storage)
            }
        }
    }
    
    
    /// Сохранение view context (только если есть изменения)
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                logger.debug("Core Data контекст сохранен", category: .storage)
            } catch {
                logger.error("Error сохранения Core Data: \(error.localizedDescription)", category: .storage)
            }
        }
    }
    
    
    /// Очистка всех данных для тестов (удаляет все PendingUpload записи)
    func deleteAll() {
        let context = container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
        
        do {
            let objects = try context.fetch(fetchRequest)
            for obj in objects {
                context.delete(obj)
            }
            if context.hasChanges {
                try context.save()
            }
            logger.info("Все PendingUpload удалены", category: .storage)
        } catch {
            logger.error("Error удаления PendingUpload: \(error.localizedDescription)", category: .storage)
        }
    }
}
