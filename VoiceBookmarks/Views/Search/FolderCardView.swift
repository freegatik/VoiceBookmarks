//
//  FolderCardView.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

struct FolderCardView: View {
    
    @ObservedObject var folder: Folder
    let onToggleExpand: (() -> Void)?
    let onTap: (() -> Void)?
    
    init(folder: Folder, onToggleExpand: (() -> Void)? = nil, onTap: (() -> Void)? = nil) {
        self.folder = folder
        self.onToggleExpand = onToggleExpand
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: folder.icon)
                .font(.system(size: 20))
                .foregroundColor(.gold)
                .frame(width: 32, height: 32)
            
            Text(folder.displayName)
                .font(.headline)
                .foregroundColor(.black)
            
            Spacer()
            
            if !folder.hasChildren {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gold.opacity(0.6))
            } else {
                Image(systemName: folder.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gold.opacity(0.6))
            }
        }
        .padding(Constants.UI.cardPadding)
        .background(Color.white)
        .cornerRadius(Constants.UI.cardCornerRadius)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(folder.displayName)
        .accessibilityIdentifier("FolderCard_\(folder.name)")
        .onTapGesture {
            if folder.hasChildren {
                withAnimation(.easeInOut(duration: 0.2)) {
                    folder.isExpanded.toggle()
                    onToggleExpand?()
                }
            } else {
                onTap?()
            }
        }
    }
}
