//
//  Folder.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
import Foundation

/// Папка: предопределенные категории с локализованными названиями и иконками
/// Поддерживает иерархическую структуру (родительские и дочерние папки)
/// 
/// Архитектура:
/// - Иерархическая структура с поддержкой вложенных папок
/// - Маппинг русских названий на английские для API (apiName, apiPath)
/// - Маппинг английских названий на русские для UI (displayName)
/// - Предопределенные категории с иконками
/// - Поддержка Codable с восстановлением связей parent-child
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Folder tree with predefined categories, icons, and API name mapping.

class Folder: ObservableObject, Identifiable, Codable {
    var id: String { name }
    let name: String
    
    
    /// Дочерние папки (опубликовано для обновления UI)
    @Published var children: [Folder] = []
    weak var parent: Folder?
    @Published var isExpanded: Bool = false
    
    
    /// Полный путь папки (для API запросов): объединяет родительские папки через "_"
    /// Например: "Аудиозаписи_Самоанализ" для вложенной папки
    var fullPath: String {
        if let parent = parent {
            return "\(parent.fullPath)_\(name)"
        }
        return name
    }
    
    /// API-имя категории: маппинг русских названий на английские для API запросов
    /// Необходимо для корректной работы с сервером, который использует английские названия
    var apiName: String {
        let parts = name.split(separator: "_")
        let baseName = String(parts.last ?? Substring(name))
        
        switch baseName {
        case "Все остальное", "Без категории":
            return "Uncategorised"
        case "Саморефлексия", "Самоанализ":
            return "SelfReflection"
        case "Задачи":
            return "Tasks"
        case "Ресурсы проекта":
            return "ProjectResources"
        case "Команды":
            return baseName
        default:
            if Folder.predefined.contains(baseName) {
                return baseName
            }
            if displayName == "Без категории" {
                return "Uncategorised"
            } else if displayName == "Саморефлексия" || displayName == "Самоанализ" {
                return "SelfReflection"
            } else if displayName == "Задачи" {
                return "Tasks"
            } else if displayName == "Ресурсы проекта" {
                return "ProjectResources"
            }
            return baseName
        }
    }
    
    /// Полный путь для API: объединяет родительские папки через "_" с английскими названиями
    /// Используется для запросов к серверу (например: "SelfReflection_SubFolder")
    var apiPath: String {
        if let parent = parent {
            return "\(parent.apiPath)_\(apiName)"
        }
        return apiName
    }
    
    /// Уровень вложенности: 0 для корневых папок, увеличивается для вложенных
    /// Используется для отступа в UI (визуальная иерархия)
    var level: Int {
        if let parent = parent {
            return parent.level + 1
        }
        return 0
    }
    
    static let predefined = [
        "SelfReflection",
        "Tasks", 
        "ProjectResources",
        "Uncategorised"
    ]
    
    
    /// Отображаемое имя: маппинг английских названий на русские для UI
    /// Пользователь видит русские названия, но API работает с английскими
    var displayName: String {
        let parts = name.split(separator: "_")
        let displayName = String(parts.last ?? Substring(name))
        
        switch displayName {
        case "SelfReflection":
            return "Саморефлексия"
        case "Tasks":
            return "Задачи"
        case "ProjectResources":
            return "Ресурсы проекта"
        case "Uncategorised":
            return "Без категории"
        default:
            return displayName
        }
    }
    
    /// Иконка папки в зависимости от типа категории
    var icon: String {
        let parts = name.split(separator: "_")
        let baseName = String(parts.last ?? Substring(name))
        
        switch baseName {
        case "SelfReflection":
            return "person.circle.fill"
        case "Tasks":
            return "checklist"
        case "ProjectResources":
            return "folder.fill"
        case "Uncategorised":
            return "questionmark.folder.fill"
        default:
            return "folder.fill"
        }
    }
    
    
    /// Создание папки с указанием имени и опционального родителя
    init(name: String, parent: Folder? = nil) {
        self.name = name
        self.parent = parent
        self.children = []
        self.isExpanded = false
    }
    
    
    enum CodingKeys: String, CodingKey {
        case name
        case children
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        let decodedChildren = try container.decodeIfPresent([Folder].self, forKey: .children) ?? []
        isExpanded = false
        
        children = []
        for child in decodedChildren {
            child.parent = self
            children.append(child)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(children, forKey: .children)
    }
    
    
    /// Добавляет дочернюю папку и устанавливает связь parent-child
    func addChild(_ folder: Folder) {
        folder.parent = self
        children.append(folder)
    }
    
    /// Проверяет, является ли папка родительской (имеет дочерние папки)
    var hasChildren: Bool {
        return !children.isEmpty
    }
    
    /// Получает все дочерние папки рекурсивно (включая вложенные)
    /// Используется для получения полного списка файлов в иерархии
    func getAllChildren() -> [Folder] {
        var allChildren: [Folder] = []
        for child in children {
            allChildren.append(child)
            allChildren.append(contentsOf: child.getAllChildren())
        }
        return allChildren
    }
}
