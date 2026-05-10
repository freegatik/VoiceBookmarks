//
//  TranscriptionView.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

struct TranscriptionView: View {
    
    let text: String
    var onTap: (() -> Void)?
    
    var body: some View {
        Group {
            if text.isEmpty {
                if onTap != nil {
                    Text("Нажмите для вставки из буфера")
                        .font(.body)
                        .foregroundColor(.gray.opacity(0.5))
                } else {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Speak...")
                            .font(.body)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
            } else {
                Text(text)
                    .font(.body)
                    .foregroundColor(.black)
            }
        }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.95))
            .cornerRadius(12)
            .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}
