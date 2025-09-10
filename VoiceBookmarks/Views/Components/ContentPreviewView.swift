//
//  ContentPreviewView.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
import Foundation

struct ContentPreviewView: View {
    
    let content: ClipboardContent
    
    private var iconName: String {
        switch content.type {
        case .text: return "doc.text"
        case .url: return "link"
        case .image: return "photo"
        case .unknown:             return "doc"
        }
    }
    
    private var displayText: String {
        if let text = content.text {
            return text
        } else if let url = content.url {
            return url.absoluteString
        } else if content.image != nil {
            return "Изображение из буфера обмена"
        } else if let fileURL = content.fileURL {
            return fileURL.lastPathComponent
        } else {
            return "Контент"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.4))
                .frame(height: 2)
            
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(.gold)
                    .frame(width: 24, height: 24)
                
                if content.type == .url, let url = content.url {
                    Link(destination: url) {
                        Text(displayText)
                            .font(.body)
                            .foregroundColor(.blue)
                            .underline()
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text(displayText)
                        .font(.body)
                        .foregroundColor(.appText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appWhite)
    }
}

