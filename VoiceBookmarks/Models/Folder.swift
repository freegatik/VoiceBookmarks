//
//  Folder.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Folder tree with predefined categories, icons, and API name mapping.

class Folder: ObservableObject, Identifiable, Codable {
    var id: String { name }
    let name: String
    
    
    /// Child folders (published for SwiftUI updates).
    @Published var children: [Folder] = []
    weak var parent: Folder?
    @Published var isExpanded: Bool = false
    
    
    /// Folder path key using "_" between parents (e.g. nested segments from server).
    var fullPath: String {
        if let parent = parent {
            return "\(parent.fullPath)_\(name)"
        }
        return name
    }
    
    /// Backend category token derived from localized segment names.
    var apiName: String {
        let parts = name.split(separator: "_")
        let baseName = String(parts.last ?? Substring(name))
        
        switch baseName {
        case "Все остальное", "Без категории":
            return "Uncategorised"
        case "Self-reflection", "Самоанализ":
            return "SelfReflection"
        case "Tasks":
            return "Tasks"
        case "Ресурсы проекта":
            return "ProjectResources"
        case "Команды":
            return baseName
        default:
            if Folder.predefined.contains(baseName) {
                return baseName
            }
            if displayName == "Uncategorized" {
                return "Uncategorised"
            } else if displayName == "Self-reflection" || displayName == "Самоанализ" {
                return "SelfReflection"
            } else if displayName == "Tasks" {
                return "Tasks"
            } else if displayName == "Project resources" {
                return "ProjectResources"
            }
            return baseName
        }
    }
    
    /// English API path joining parent segments with "_".
    var apiPath: String {
        if let parent = parent {
            return "\(parent.apiPath)_\(apiName)"
        }
        return apiName
    }
    
    /// Depth in the tree (drives indentation).
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
    
    
    /// Human-readable folder title for lists (maps API tokens to UI labels).
    var displayName: String {
        let parts = name.split(separator: "_")
        let displayName = String(parts.last ?? Substring(name))
        
        switch displayName {
        case "SelfReflection":
            return "Self-reflection"
        case "Tasks":
            return "Tasks"
        case "ProjectResources":
            return "Project resources"
        case "Uncategorised":
            return "Uncategorized"
        default:
            return displayName
        }
    }
    
    /// SF Symbol name for the folder row.
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
    
    
    func addChild(_ folder: Folder) {
        folder.parent = self
        children.append(folder)
    }
    
    var hasChildren: Bool {
        return !children.isEmpty
    }
    
    func getAllChildren() -> [Folder] {
        var allChildren: [Folder] = []
        for child in children {
            allChildren.append(child)
            allChildren.append(contentsOf: child.getAllChildren())
        }
        return allChildren
    }
}
