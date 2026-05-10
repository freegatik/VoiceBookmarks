//
//  FileListView.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
import Combine

struct FileListView: View {
    
    let folder: Folder
    let bookmarkService: BookmarkService
    
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.dismiss) var dismiss
    @State private var displayedBookmarks: [Bookmark]
    @State private var bookmarkToView: Bookmark?
    @State private var showWebView = false
    @State private var itemsToShare: [Any] = []
    @State private var showShareSheet = false
    @State private var bookmarkToDelete: Bookmark?
    @State private var showDeleteConfirmation = false
    @State private var dragOffset: CGSize = .zero
    @State private var showPopoverForBookmark: Bookmark?
    @State private var pendingLongPressEnd = false
    @State private var activePressingBookmarkId: String?
    
    init(folder: Folder, bookmarks: [Bookmark], bookmarkService: BookmarkService, viewModel: SearchViewModel) {
        self.folder = folder
        self.bookmarkService = bookmarkService
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._displayedBookmarks = State(initialValue: bookmarks)
    }
    
    var body: some View {
        mainContent
            .background(Color.appBackground)
        .navigationTitle("Files")
        .navigationBarTitleDisplayMode(.inline)
        .simultaneousGesture(
            DragGesture(minimumDistance: 50)
                .onChanged { value in
                    if value.translation.width > 0 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    let horizontalSwipe = abs(value.translation.width) > abs(value.translation.height)
                    let swipeRight = value.translation.width > 100
                    
                    if horizontalSwipe && swipeRight {
                        viewModel.navigateBack()
                        dismiss()
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .offset(x: dragOffset.width > 0 ? min(dragOffset.width, 100) : 0)

        .sheet(isPresented: $showWebView) {
            if let bookmark = bookmarkToView {
                WebContentView(
                    viewModel: WebViewModel(
                        content: .file(bookmark),
                        bookmarkService: bookmarkService
                    )
                )
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: itemsToShare)
        }
        .confirmationDialog(
            "Delete bookmark?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone")
        }
        .confirmationDialog(
            "",
            isPresented: Binding(
                get: { showPopoverForBookmark != nil },
                set: { if !$0 { showPopoverForBookmark = nil } }
            ),
            titleVisibility: .hidden
        ) {
            if let bookmark = showPopoverForBookmark {
                Button("View") {
                    bookmarkToView = bookmark
                    showPopoverForBookmark = nil
                    showWebView = true
                }
                
                Button("Share") {
                    shareBookmark(bookmark)
                    showPopoverForBookmark = nil
                }
                
                Button("Delete", role: .destructive) {
                    deleteBookmark(bookmark)
                    showPopoverForBookmark = nil
                }
            }
            }
        .onChange(of: viewModel.currentDestination) { destination in
            guard let destination else { return }
            if case .fileList(let destFolder, let results) = destination,
               destFolder.id == folder.id {
                displayedBookmarks = results
            }
        }
        .onReceive(viewModel.$searchResults) { results in
            if let selectedFolder = viewModel.selectedFolder,
               selectedFolder.id == folder.id {
                displayedBookmarks = results
            } else if let destination = viewModel.currentDestination,
                      case .fileList(let destFolder, _) = destination,
                      destFolder.id == folder.id {
                displayedBookmarks = results
            }
        }
        }
        
        private func showPopoverMenu(for bookmark: Bookmark) {
        showPopoverForBookmark = bookmark
    }
    
    private func shareBookmark(_ bookmark: Bookmark) {
        var items: [Any] = []
        
        if let fileUrlString = bookmark.fileUrl,
           let url = URL(string: fileUrlString) {
            items.append(url)
        }
        items.append(bookmark.fileName)
        if !bookmark.displayDescription.isEmpty {
            items.append(bookmark.displayDescription)
        }
        
        itemsToShare = items
        showShareSheet = true
    }
    
    private func deleteBookmark(_ bookmark: Bookmark) {
        bookmarkToDelete = bookmark
        showDeleteConfirmation = true
    }
    
    private func confirmDelete() {
        guard let bookmark = bookmarkToDelete else { return }
        
        Task {
            do {
                _ = try await bookmarkService.deleteBookmark(id: bookmark.id)
                await MainActor.run {
                    withAnimation {
                        displayedBookmarks.removeAll { $0.id == bookmark.id }
                    }
                    viewModel.searchResults.removeAll { $0.id == bookmark.id }
                    BookmarkCacheService.shared.clearCache(for: folder.fullPath)
                    viewModel.toast = .success("Bookmark deleted")
                    bookmarkToDelete = nil
                    
                    if displayedBookmarks.isEmpty {
                        viewModel.navigateToFileList(folder: folder, results: [])
                    }
                }
            } catch {
                await MainActor.run {
                    viewModel.toast = .error("Delete failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if displayedBookmarks.isEmpty {
            EmptyStateView(
                message: folder.hasChildren ? "Эта папка содержит только подпапки. Откройте подпапку для просмотра файлов." : "Files не найдены",
                icon: folder.hasChildren ? "folder.fill" : "doc.badge.gearshape"
            )
        } else {
            listContent
        }
    }
    
    @ViewBuilder
    private var listContent: some View {
        VStack(spacing: 0) {
            if viewModel.isRecording {
                TranscriptionView(text: viewModel.transcription)
                    .transition(.move(edge: .top))
                    .animation(.easeInOut(duration: Constants.UI.animationDuration), value: viewModel.isRecording)
            }
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(displayedBookmarks) { bookmark in
                        bookmarkCard(for: bookmark)
                    }
                }
                .padding(Constants.UI.cardPadding)
                .padding(.top, viewModel.isRecording ? 0 : Constants.UI.cardPadding)
            }
        }
    }
    
    @ViewBuilder
    private func bookmarkCard(for bookmark: Bookmark) -> some View {
        DynamicFileCard(bookmark: bookmark)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                    .stroke(viewModel.selectedBookmark?.id == bookmark.id ? Color.gold.opacity(0.6) : Color.clear, lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.3), value: viewModel.selectedBookmark?.id)
            .onTapGesture {
                if viewModel.selectedBookmark == nil && !viewModel.isRecording {
                    showPopoverMenu(for: bookmark)
                }
            }
            .onLongPressGesture(minimumDuration: Constants.Speech.longPressDuration) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.selectedBookmark = bookmark
                }
                
                Task { @MainActor in
                    viewModel.handleBookmarkLongPressStarted(bookmark)
                }
            } onPressingChanged: { pressing in
                viewModel.handleSearchPressingChanged(isPressing: pressing)
                if !pressing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.selectedBookmark = nil
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
                                viewModel.selectedBookmark = nil
                            }
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 && viewModel.isRecording {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.warning)
                            viewModel.cancelRecording()
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.selectedBookmark = nil
                            }
                        }
                    }
            )
    }
    
    private func handleBookmarkPressChange(pressing: Bool, bookmark: Bookmark) { }
}
