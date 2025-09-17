//
//  FolderListView.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit

private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
#endif

struct FolderListView: View {
    
    @ObservedObject var viewModel: SearchViewModel
    let bookmarkService: BookmarkService
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var selectedFolderId: String?
    
    var body: some View {
        NavigationView {
                ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if !networkMonitor.isConnected {
                        VStack(spacing: 16) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.error)
                            
                            Text("Нет подключения к интернету")
                                .font(.headline)
                                .foregroundColor(.appText)
                            
                            Text("Для работы с поиском требуется подключение к сети")
                                .font(.body)
                                .foregroundColor(.appSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            #if canImport(UIKit)
                            hideKeyboard()
                            #endif
                        }
                        
                    } else {
                        HStack(spacing: 12) {
                            TextField("Поиск...", text: $viewModel.searchQuery)
                                .font(.body)
                                .foregroundColor(.appText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.appWhite)
                                .cornerRadius(Constants.UI.cardCornerRadius)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                                        .stroke(Color.gold.opacity(0.2), lineWidth: 1)
                                )
                                .submitLabel(.search)
                                .onSubmit {
                                    viewModel.performTextSearch(query: viewModel.searchQuery)
                                    #if canImport(UIKit)
                                    hideKeyboard()
                                    #endif
                                }
                            
                            Button {
                                viewModel.performTextSearch(query: viewModel.searchQuery)
                                #if canImport(UIKit)
                                hideKeyboard()
                                #endif
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.gold)
                                    .cornerRadius(Constants.UI.cardCornerRadius)
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .accessibilityIdentifier("SearchSubmitButton")
                            .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                        }
                        .padding(.horizontal, Constants.UI.cardPadding)
                        .padding(.top, Constants.UI.cardPadding)
                        .padding(.bottom, 8)
                        
                        if viewModel.isRecording {
                        TranscriptionView(text: viewModel.transcription)
                            .transition(.move(edge: .top))
                            .animation(.easeInOut(duration: Constants.UI.animationDuration), value: viewModel.isRecording)
                    }
                    
                    if !viewModel.folders.isEmpty {
                        ZStack {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.folders) { folder in
                                    FolderHierarchyView(
                                        folder: folder,
                                        selectedFolderId: $selectedFolderId,
                                        viewModel: viewModel
                                        )
                                }
                            }
                            .padding(.horizontal, Constants.UI.cardPadding)
                            .padding(.top, viewModel.isRecording ? 0 : Constants.UI.cardPadding)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            #if canImport(UIKit)
                            hideKeyboard()
                            #endif
                        }
                            
                            if viewModel.isLoading {
                                VStack {
                                    Spacer()
                                    LoadingView(message: viewModel.loadingMessage ?? "Обновление...")
                                        .padding()
                                    Spacer()
                                }
                                .background(Color.appBackground.opacity(0.7))
                            }
                        }
                    } else if viewModel.isLoading {
                        LoadingView(message: viewModel.loadingMessage ?? "Загрузка...")
                    } else {
                        EmptyStateView(
                            message: "Нет папок",
                            icon: "folder.badge.questionmark"
                        )
                    }
                }
            }
            }
            .navigationTitle("Папки")
            .navigationBarTitleDisplayMode(.inline)
            .background(
                NavigationLink(
                    destination: destinationView,
                    isActive: Binding(
                        get: { viewModel.currentDestination != nil },
                        set: { 
                            if !$0 { 
                                viewModel.currentDestination = nil
                                viewModel.selectedFolder = nil
                            } 
                        }
                    )
                ) {
                    EmptyView()
                }
            )
        }
        .task {
            if viewModel.folders.isEmpty {
            await viewModel.loadFolders()
            }
        }
        .toast($viewModel.toast)
    }
    
    @ViewBuilder
    private var destinationView: some View {
        if let destination = viewModel.currentDestination {
            switch destination {
            case .fileList(let folder, let results):
                FileListView(
                    folder: folder,
                    bookmarks: results,
                    bookmarkService: bookmarkService,
                    viewModel: viewModel
                )
                
            case .webView(let content):
                WebContentView(
                    viewModel: WebViewModel(
                        content: content,
                        bookmarkService: bookmarkService
                    )
                )
            }
        }
    }
}

struct FolderHierarchyView: View {
    @ObservedObject var folder: Folder
    @Binding var selectedFolderId: String?
    @ObservedObject var viewModel: SearchViewModel
    @State private var pendingLongPressEnd = false
    
    var body: some View {
        VStack(spacing: 0) {
            FolderCardView(
                folder: folder,
                onToggleExpand: {
                },
                onTap: {
                    if selectedFolderId == nil && !viewModel.isRecording {
                        viewModel.handleFolderTap(folder)
                    }
                }
            )
            .zIndex(selectedFolderId == folder.id ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: selectedFolderId)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                    .stroke(selectedFolderId == folder.id ? Color.gold.opacity(0.6) : Color.clear, lineWidth: 2)
            )
            .onLongPressGesture(minimumDuration: Constants.Speech.longPressDuration) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedFolderId = folder.id
                }
                
                Task { @MainActor in
                viewModel.handleFolderLongPressStarted(folder)
                }
            } onPressingChanged: { pressing in
                viewModel.handleSearchPressingChanged(isPressing: pressing)
                if !pressing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedFolderId = nil
                        }
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onChanged { value in
                        if value.translation.height > 100 && viewModel.isRecording {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.warning)
                            viewModel.cancelRecording()
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedFolderId = nil
                            }
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 && viewModel.isRecording {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.warning)
                            viewModel.cancelRecording()
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedFolderId = nil
                            }
                        }
                    }
            )
            
            if folder.isExpanded && !folder.children.isEmpty {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, Constants.UI.cardPadding)
                    
                    VStack(spacing: 0) {
                        ForEach(folder.children) { childFolder in
                            HStack(spacing: 12) {
                                Image(systemName: childFolder.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(.gold)
                                    .frame(width: 28, height: 28)
                                
                                Text(childFolder.displayName)
                                    .font(.headline)
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gold.opacity(0.6))
                            }
                            .padding(.horizontal, Constants.UI.cardPadding)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedFolderId == childFolder.id ? Color.gold.opacity(0.6) : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                if selectedFolderId == nil && !viewModel.isRecording {
                                    viewModel.handleFolderTap(childFolder)
                                }
                            }
                            .onLongPressGesture(minimumDuration: Constants.Speech.longPressDuration) {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedFolderId = childFolder.id
                                }
                                
                                Task { @MainActor in
                                viewModel.handleFolderLongPressStarted(childFolder)
                                }
                            } onPressingChanged: { pressing in
                                viewModel.handleSearchPressingChanged(isPressing: pressing)
                                if !pressing {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedFolderId = nil
                                        }
                                    }
                                }
                            }
                            
                            if childFolder.id != folder.children.last?.id {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 1)
                                    .padding(.leading, Constants.UI.cardPadding + 40) // Отступ от иконки
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(Color.white)
                .cornerRadius(Constants.UI.cardCornerRadius)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .padding(.top, 8)
            }
        }
    }
}

