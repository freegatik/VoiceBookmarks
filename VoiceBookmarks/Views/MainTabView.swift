//
//  MainTabView.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

struct MainTabView: View {
    
    let shareViewModel: ShareViewModel
    let searchViewModel: SearchViewModel
    let bookmarkService: BookmarkService
    
    @State private var selectedTab = 1
    
    func selectShareTab() {
        selectedTab = 0
    }
    
    init(
        shareViewModel: ShareViewModel,
        searchViewModel: SearchViewModel,
        bookmarkService: BookmarkService
    ) {
        self.shareViewModel = shareViewModel
        self.searchViewModel = searchViewModel
        self.bookmarkService = bookmarkService
        
        let appearance = UITabBarAppearance()
        appearance.backgroundColor = UIColor.white
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            if ProcessInfo.processInfo.arguments.contains("--ShareExtensionTesting") {
                ShareExtensionTestView()
                    .tabItem {
                        Label("Test SE", systemImage: "wrench.and.screwdriver")
                    }
                    .tag(2)
            }
            ShareView(viewModel: shareViewModel)
                .tabItem {
                    Image(systemName: "plus")
                    Text("Добавить")
                }
                .tag(0)
            
            SearchView(viewModel: searchViewModel, bookmarkService: bookmarkService)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Поиск")
                }
                .tag(1)
        }
        .accentColor(.gold)
        .onReceive(NotificationCenter.default.publisher(for: .init("SelectShareTabRequested"))) { _ in
            selectedTab = 0
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == 1 {
                searchViewModel.navigateBack()
                searchViewModel.resetSearch()
            }
        }
        .onChange(of: shareViewModel.shouldDismiss) { shouldDismiss in
            if shouldDismiss {
                selectedTab = 1
                shareViewModel.shouldDismiss = false
            }
        }
        .preferredColorScheme(.light)
    }
}


