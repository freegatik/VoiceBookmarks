//
//  PasteButtonView.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

struct PasteButtonView: View {
    
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Вставить")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.gold)
                .cornerRadius(8)
        }
    }
}
