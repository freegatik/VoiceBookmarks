//
//  ShareExtensionView.swift
//  VoiceBookmarksShareExtension
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

// MARK: - UI для Share Extension: иконка и статус загрузки

struct ShareExtensionView: View {
    
    @ObservedObject var viewModel: ShareExtensionViewModel
    
    var body: some View {
        ZStack {
            Color.appWhite
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Group {
                    if viewModel.showSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                    } else if viewModel.showError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.error)
                    } else {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.gold)
                    }
                }
                .scaleEffect(viewModel.isLoading ? 1.0 : (viewModel.showSuccess ? 1.2 : 1.0))
                .animation(.easeInOut(duration: 0.3), value: viewModel.showSuccess)
                .animation(.easeInOut(duration: 0.3), value: viewModel.showError)
                
                Text(viewModel.statusMessage)
                    .font(.headline)
                    .foregroundColor(viewModel.showError ? .error : .appText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .gold))
                        .scaleEffect(1.2)
                }
                
                Spacer()
            }
        }
    }
}
