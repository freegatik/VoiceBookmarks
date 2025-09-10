//
//  EmptyStateView.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

struct EmptyStateView: View {
    
    let message: String
    let icon: String
    
    init(message: String, icon: String = "folder.badge.questionmark") {
        self.message = message
        self.icon = icon
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gold.opacity(0.5))
            
            Text(message)
                .font(.headline)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

