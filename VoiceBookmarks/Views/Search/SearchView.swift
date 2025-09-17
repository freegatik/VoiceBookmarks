//
//  SearchView.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

struct SearchView: View {
    
    @StateObject var viewModel: SearchViewModel
    let bookmarkService: BookmarkService
    
    var body: some View {
        FolderListView(viewModel: viewModel, bookmarkService: bookmarkService)
    }
}

