//
//  ShareExtensionTestView.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

struct ShareExtensionTestView: View {
    @StateObject private var viewModel = ShareExtensionViewModel()
    @State private var currentState: TestState = .loading
    @State private var showShareSheet: Bool = false
    
    enum TestState {
        case loading
        case success
        case error
        case defaultState
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Button("Loading") {
                        currentState = .loading
                        viewModel.isLoading = true
                        viewModel.statusMessage = "Добавление контента..."
                        viewModel.showSuccess = false
                        viewModel.showError = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Processing") {
                        currentState = .loading
                        viewModel.updateStatus(message: "Обработка контента...", isSuccess: false)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Processing Image") {
                        currentState = .loading
                        viewModel.updateStatus(message: "Обработка изображения...", isSuccess: false)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Success") {
                        currentState = .success
                        viewModel.updateStatus(message: "Контент успешно добавлен", isSuccess: true)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Error") {
                        currentState = .error
                        viewModel.showError("Нет контента для добавления")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    
                    Button("Default") {
                        currentState = .defaultState
                        viewModel.isLoading = false
                        viewModel.statusMessage = "Добавление контента..."
                        viewModel.showSuccess = false
                        viewModel.showError = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Open Share Sheet") {
                        showShareSheet = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Share Extension Test")
            .navigationBarTitleDisplayMode(.inline)
            #if canImport(UIKit)
            .sheet(isPresented: $showShareSheet) {
                ActivityView(activityItems: ["Test share content"])
            }
            #endif
        }
    }
}

#if canImport(UIKit)
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

