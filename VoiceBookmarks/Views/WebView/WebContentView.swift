//
//  WebContentView.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
import WebKit

struct WebContentView: View {
    
    @StateObject var viewModel: WebViewModel
    @Environment(\.dismiss) var dismiss
    @State private var contentURL: URL?
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                if let url = contentURL {
                    previewView(for: viewModel.content, url: url)
                        .offset(dragOffset)
                        .overlay {
                            if viewModel.isLoading {
                                LoadingView(message: "Загрузка...")
                                    .background(Color.appBackground.opacity(0.9))
                            }
                        }
                } else if let error = viewModel.loadError {
                    ErrorStateView(
                        message: error,
                        retryAction: nil
                    )
                } else {
                    LoadingView(message: "Подготовка контента...")
                }
            }
            .navigationTitle(viewModel.content.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("WebContentClose")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            viewModel.handleSaveToFiles()
                        } label: {
                            Label("Сохранить в Файлы", systemImage: "arrow.down.doc")
                        }
                        
                        Button {
                            viewModel.handleShareAction()
                        } label: {
                            Label("Поделиться", systemImage: "square.and.arrow.up")
                        }
                        
                        if viewModel.content.canDelete {
                            Button(role: .destructive) {
                                viewModel.handleDeleteAction()
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.gold)
                    }
                }
            }
        .simultaneousGesture(
                DragGesture(minimumDistance: 50)
                    .onChanged { value in
                        guard value.translation.width.isFinite && value.translation.height.isFinite else {
                            dragOffset = .zero
                            return
                        }
                        
                        let horizontalSwipe = abs(value.translation.width) > abs(value.translation.height)
                        if horizontalSwipe && value.translation.width > 0 {
                            let limitedWidth = min(value.translation.width, 120) // Ограничиваем до 120px
                            if limitedWidth.isFinite {
                            dragOffset = CGSize(width: limitedWidth, height: 0)
                            } else {
                                dragOffset = .zero
                            }
                        } else {
                            dragOffset = .zero
                        }
                    }
                    .onEnded { value in
                        handleSwipeGesture(translation: value.translation)
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragOffset = .zero
                        }
                    }
            )
        .sheet(isPresented: $viewModel.showShareSheet) {
            ShareSheet(items: viewModel.itemsToShare)
        }
        .confirmationDialog(
            "Удалить закладку?",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                Task {
                    await viewModel.confirmDelete()
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить")
        }
        .onChange(of: viewModel.shouldDismiss) { shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
        .task {
            let url = viewModel.prepareContent()
            contentURL = url
            if url != nil {
                LoggerService.shared.info("WebContentView: contentURL установлен: \(url!.absoluteString)", category: .webview)
            } else {
                if case .file(let bookmark) = viewModel.content {
                    let isAsyncLoad = bookmark.contentType == .audio || 
                                     bookmark.contentType == .video ||
                                     bookmark.fileName.lowercased().hasSuffix(".pdf")
                    if isAsyncLoad {
                        LoggerService.shared.info("WebContentView: prepareContent вернул nil для \(bookmark.contentType.rawValue) (загрузка асинхронная)", category: .webview)
                    } else {
                        LoggerService.shared.warning("WebContentView: prepareContent вернул nil для \(bookmark.contentType.rawValue)", category: .webview)
                    }
                } else {
                    LoggerService.shared.warning("WebContentView: prepareContent вернул nil для команды", category: .webview)
                }
            }
        }
        .onChange(of: viewModel.currentHTMLFileURL) { newURL in
            if let newURL = newURL {
                contentURL = newURL
                LoggerService.shared.info("WebContentView: contentURL обновлен с полным контентом: \(newURL.absoluteString)", category: .webview)
            }
        }
        .onChange(of: viewModel.contentURL) { newURL in
            if let newURL = newURL {
                contentURL = newURL
                LoggerService.shared.info("WebContentView: contentURL обновлен из ViewModel: \(newURL.absoluteString)", category: .webview)
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .sheet(isPresented: $viewModel.showDocumentPicker) {
            if let url = viewModel.urlToSave {
                DocumentPicker(url: url) {
                    viewModel.showDocumentPicker = false
                    viewModel.urlToSave = nil
                    dismiss()
                }
            }
        }
    }
    
    @ViewBuilder
    private func previewView(for content: WebViewContent, url: URL) -> some View {
        switch content {
        case .file(let bookmark):
            switch bookmark.contentType {
            case .image:
                if url.pathExtension.lowercased() == "html" {
                    WKWebViewRepresentable(
                        url: url,
                        htmlString: viewModel.htmlContent,
                        configuration: viewModel.content.webViewConfiguration,
                        headers: viewModel.requestHeaders(for: url),
                        onLoadFinish: {
                            viewModel.loadingDidFinish()
                        },
                        onLoadFail: { error in
                            viewModel.loadingDidFail(error: error)
                        }
                    )
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    ImagePreviewView(
                        imageURL: url,
                        onLoadFinish: {
                            viewModel.loadingDidFinish()
                        },
                        onLoadFail: { error in
                            viewModel.loadingDidFail(error: error)
                        },
                        headers: viewModel.requestHeaders(for: url)
                    )
                }
            case .video:
                VideoPreviewView(
                    videoURL: url,
                    onLoadFinish: {
                        viewModel.loadingDidFinish()
                    },
                    onLoadFail: { error in
                        viewModel.loadingDidFail(error: error)
                    }
                )
            case .audio:
                AudioPreviewView(
                    audioURL: url,
                    onLoadFinish: {
                        LoggerService.shared.info("AudioPreviewView: загрузка завершена для URL: \(url.absoluteString)", category: .webview)
                        viewModel.loadingDidFinish()
                    },
                    onLoadFail: { error in
                        LoggerService.shared.error("AudioPreviewView: ошибка загрузки для URL: \(url.absoluteString), ошибка: \(error.localizedDescription)", category: .webview)
                        viewModel.loadingDidFail(error: error)
                    }
                )
                .id(url.absoluteString) // Принудительно пересоздаем view при изменении URL
            case .file:
                let ext = url.pathExtension.lowercased()
                if ext == "pdf" {
                        PDFPreviewView(
                            pdfURL: url,
                            onLoadFinish: {
                                viewModel.loadingDidFinish()
                            },
                            onLoadFail: { error in
                                viewModel.loadingDidFail(error: error)
                            }
                        )
                    } else if ["doc", "docx", "ppt", "pptx", "xls", "xlsx"].contains(ext) || (!url.isFileURL && ext.isEmpty) {
                        QuickLookPreviewView(
                            sourceURL: url,
                            onLoadFinish: {
                                viewModel.loadingDidFinish()
                            },
                            onLoadFail: { error in
                                viewModel.loadingDidFail(error: error)
                            },
                            headers: viewModel.requestHeaders(for: url)
                        )
                    } else {
                        WKWebViewRepresentable(
                        url: url,
                        htmlString: viewModel.htmlContent,
                        configuration: viewModel.content.webViewConfiguration,
                        headers: viewModel.requestHeaders(for: url),
                        onLoadFinish: {
                            viewModel.loadingDidFinish()
                        },
                        onLoadFail: { error in
                            viewModel.loadingDidFail(error: error)
                        }
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
            default:
                WKWebViewRepresentable(
                    url: url,
                    htmlString: viewModel.htmlContent,
                    configuration: viewModel.content.webViewConfiguration,
                    headers: viewModel.requestHeaders(for: url),
                    onLoadFinish: {
                        viewModel.loadingDidFinish()
                    },
                    onLoadFail: { error in
                        viewModel.loadingDidFail(error: error)
                    }
                )
                .ignoresSafeArea(edges: .bottom)
            }
        case .command:
            WKWebViewRepresentable(
                url: url,
                htmlString: viewModel.htmlContent,
                configuration: viewModel.content.webViewConfiguration,
                headers: nil,
                onLoadFinish: {
                    viewModel.loadingDidFinish()
                },
                onLoadFail: { error in
                    viewModel.loadingDidFail(error: error)
                },
                onLongPressEmptyArea: {
                    viewModel.handleShareAction()
                }
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    private func handleSwipeGesture(translation: CGSize) {
        guard translation.width.isFinite && translation.height.isFinite else {
            return
        }
        
        let horizontalSwipe = abs(translation.width) > abs(translation.height)
        let swipeRight = translation.width > 100
        
        if horizontalSwipe && swipeRight {
            dismiss()
        }
    }
}

extension WebViewContent {
    
    var webViewConfiguration: WKWebViewConfiguration {
        switch self {
        case .file:
            return .filePreviewConfiguration()
        case .command:
            return .htmlRenderConfiguration()
        }
    }
}

