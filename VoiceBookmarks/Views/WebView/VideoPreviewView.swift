//
//  VideoPreviewView.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
import AVKit

struct VideoPreviewView: View {
    
    let videoURL: URL
    let onLoadFinish: () -> Void
    let onLoadFail: ((Error) -> Void)?
    
    @State private var player: AVPlayer?
    
    private let logger = LoggerService.shared
    
    init(videoURL: URL, onLoadFinish: @escaping () -> Void = {}, onLoadFail: ((Error) -> Void)? = nil) {
        self.videoURL = videoURL
        self.onLoadFinish = onLoadFinish
        self.onLoadFail = onLoadFail
    }
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                LoadingView(message: "Loading video...")
            }
        }
        .onAppear {
            logger.info("Создание AVPlayer для видео: \(videoURL.absoluteString)", category: .webview)
            player = AVPlayer(url: videoURL)
            onLoadFinish()
        }
        .onDisappear {
            logger.info("Остановка воспроизведения видео", category: .webview)
            player?.pause()
            player = nil
        }
    }
}
