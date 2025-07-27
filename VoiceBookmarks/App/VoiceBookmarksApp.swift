//
//  VoiceBookmarksApp.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

@main
struct VoiceBookmarksApp: App {
    
    private let networkService: NetworkService
    private let authService: AuthService
    private let searchService: SearchService
    private let bookmarkService: BookmarkService
    private let offlineQueueService: OfflineQueueService
    private let shareViewModel: ShareViewModel
    private let searchViewModel: SearchViewModel
    
    
    init() {
        _ = SharedUserDefaults.shared
        
        networkService = NetworkService()
        
        authService = AuthService(
            networkService: networkService,
            keychainService: KeychainService.shared
        )
        
        if ProcessInfo.processInfo.arguments.contains("--UITestSeedFolders") || AppTestHostContext.isUnitTestHostedMainApp {
            searchService = SearchServiceMock(networkService: networkService)
        } else {
        searchService = SearchService(
            networkService: networkService
        )
        }
        
        bookmarkService = BookmarkService(
            networkService: networkService,
            fileService: FileService.shared
        )
        
        offlineQueueService = OfflineQueueService.shared
        if !AppTestHostContext.isUnitTestHostedMainApp {
            offlineQueueService.setBookmarkService(bookmarkService)
        }
        
        shareViewModel = ShareViewModel(
            clipboardService: ClipboardService.shared,
            speechService: SpeechService.shared,
            bookmarkService: bookmarkService,
            offlineQueue: offlineQueueService
        )
        
        searchViewModel = SearchViewModel(
            searchService: searchService,
            speechService: SpeechService.shared
        )
        
        setupApp()
    }
    
    
    var body: some Scene {
        WindowGroup {
            AppContentView(
                shareViewModel: shareViewModel,
                searchViewModel: searchViewModel,
                bookmarkService: bookmarkService,
                offlineQueueService: offlineQueueService
            )
        }
    }
    
    
    private func setupApp() {
        LoggerService.shared.info("Приложение запущено", category: .lifecycle)
        configureAppearance()
        
        if AppTestHostContext.isUnitTestHostedMainApp {
            LoggerService.shared.info("Режим XCTest unit host: пропуск auth/NetworkMonitor/offline startMonitoring", category: .lifecycle)
            return
        }
        
        Task {
            do {
                let userId = try await authService.getOrCreateUserId()
                LoggerService.shared.info("UserId получен: \(userId)", category: .auth)
            } catch {
                LoggerService.shared.error("Ошибка получения userId: \(error)", category: .auth)
            }
        }
        
        _ = NetworkMonitor.shared
        offlineQueueService.startMonitoring()
        
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await offlineQueueService.processQueue()
        }
    }
    
    private func configureAppearance() {
        #if canImport(UIKit)
        UINavigationBar.appearance().tintColor = UIColor(Color.gold)
        #endif
    }
}


struct AppContentView: View {
    let shareViewModel: ShareViewModel
    let searchViewModel: SearchViewModel
    let bookmarkService: BookmarkService
    let offlineQueueService: OfflineQueueService
    
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var globalToast = GlobalToastManager.shared
    @State private var showGlobalToast = false
    @State private var globalToastWorkItem: DispatchWorkItem?
    
    var body: some View {
        ZStack {
            Group {
            if ProcessInfo.processInfo.arguments.contains("--UITestShareSeed") {
                ShareExtensionTestView()
            } else {
                MainTabView(
                    shareViewModel: shareViewModel,
                    searchViewModel: searchViewModel,
                    bookmarkService: bookmarkService
                )
            }
            }
            if let toast = globalToast.currentToast, showGlobalToast {
                VStack {
                    ToastView(
                        message: toast.message,
                        type: toast.type == .success ? .success : .error
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if abs(value.translation.height) > 10 || abs(value.translation.width) > 10 {
                                    dismissGlobalToast(animated: true, clearManager: true)
                                }
                            }
                    )
                    .onTapGesture {
                        dismissGlobalToast(animated: true, clearManager: true)
                    }
                    Spacer()
                }
                .zIndex(1000)
            }
        }
        
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                let hasLastItem = SharedUserDefaults.getLastSharedItem() != nil
                let shouldSelectTab = SharedUserDefaults.consumeShareTabSelectionRequest()
                
                if hasLastItem {
                    shareViewModel.loadLastSharedItemIfAny()
                }
                
                if hasLastItem || shouldSelectTab {
                    NotificationCenter.default.post(name: .init("SelectShareTabRequested"), object: nil)
                }
                
                if let attempt = SharedUserDefaults.getOpenHostAttempt() {
                    let elapsed = Date().timeIntervalSince1970 - attempt
                    LoggerService.shared.info("Приложение активировано после share extension. elapsed=\(elapsed)s", category: .ui)
                    SharedUserDefaults.setOpenHostAttempt(timestamp: 0)
                }
                
                Task {
                    await offlineQueueService.processQueue()
                }
            case .inactive, .background:
                SpeechService.shared.cancelRecording()
            @unknown default:
                break
            }
        }
        
        .onReceive(NotificationCenter.default.publisher(for: .offlineQueueDidChange)) { _ in
            Task {
                await offlineQueueService.processQueue()
            }
        }
        
        .onOpenURL { url in
            LoggerService.shared.info("Открыт по deep link: \(url.absoluteString)", category: .ui)
            
            let hasLastItem = SharedUserDefaults.getLastSharedItem() != nil
            if hasLastItem {
                shareViewModel.loadLastSharedItemIfAny()
            }
            
            NotificationCenter.default.post(name: .init("SelectShareTabRequested"), object: nil)
            Task { await offlineQueueService.processQueue() }
        }
        
        .onChange(of: globalToast.currentToast) { newValue in
            if newValue != nil {
                withAnimation(.easeInOut(duration: 0.25)) { showGlobalToast = true }
                scheduleGlobalToastDismiss()
            } else {
                dismissGlobalToast(animated: true, clearManager: false)
            }
        }
    }
    
    
    private func dismissGlobalToast(animated: Bool, clearManager: Bool) {
        cancelGlobalToastWorkItem()
        
        let animationBlock = {
            showGlobalToast = false
        }
        
        if animated {
            withAnimation(.easeInOut(duration: 0.25), animationBlock)
        } else {
            animationBlock()
        }
        
        guard clearManager else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            GlobalToastManager.shared.dismiss()
        }
    }
    
    private func scheduleGlobalToastDismiss() {
        cancelGlobalToastWorkItem()
        
        let workItem = DispatchWorkItem {
            dismissGlobalToast(animated: true, clearManager: true)
        }
        globalToastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.UI.toastDuration, execute: workItem)
    }
    
    private func cancelGlobalToastWorkItem() {
        globalToastWorkItem?.cancel()
        globalToastWorkItem = nil
    }
}

