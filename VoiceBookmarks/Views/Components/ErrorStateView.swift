//
//  ErrorStateView.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

struct ErrorStateView: View {
    
    let message: String
    let retryAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.error)
            
            Text("Error")
                .font(.title2)
                .foregroundColor(.appText)
            
            Text(message)
                .font(.body)
                .foregroundColor(.appSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let retryAction = retryAction {
                Button("Повторить") {
                    retryAction()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.gold)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
