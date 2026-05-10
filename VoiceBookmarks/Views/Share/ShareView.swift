//
//  ShareView.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

struct ShareView: View {
    
    @StateObject var viewModel: ShareViewModel
    @State private var tapStartTime: Date?
    @State private var isLongPressing: Bool = false
    @State private var hasCalledSwipeDown: Bool = false

    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appWhite
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    TranscriptionView(
                        text: viewModel.isRecording ? (viewModel.transcription.isEmpty ? "Speak..." : viewModel.transcription) : viewModel.transcription,
                        onTap: {
                            if !viewModel.isRecording && viewModel.contentPreview == nil {
                                let screenWidth = UIScreen.main.bounds.width
                                let x = screenWidth.isFinite && screenWidth > 0 ? screenWidth / 2 : 0
                                let y: CGFloat = 100
                                viewModel.handleTapOnTranscriptionField(at: CGPoint(x: x, y: y))
                            }
                        }
                    )
                    .transition(.move(edge: .top))
                    
                    Spacer()
                    
                    Spacer()
                    
                    if let content = viewModel.contentPreview {
                        ContentPreviewView(content: content)
                            .offset(y: viewModel.contentPreviewOffset.isFinite ? viewModel.contentPreviewOffset : 0)
                            .padding(.bottom, 20)
                    }
                }
                
                if viewModel.isUploading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
                
                if viewModel.showPasteButton {
                    PasteButtonView {
                        viewModel.handlePasteButtonTap()
                    }
                    .position(
                        x: viewModel.pasteButtonPosition.x.isFinite ? viewModel.pasteButtonPosition.x : 0,
                        y: viewModel.pasteButtonPosition.y.isFinite ? viewModel.pasteButtonPosition.y : 0
                    )
                    .transition(.scale)
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if value.translation.height > 100 && viewModel.isRecording && !hasCalledSwipeDown {
                        hasCalledSwipeDown = true
                        viewModel.handleSwipeDown()
                        return
                    }
                    
                    if viewModel.isRecording && value.translation.height < -30 && value.translation.height > -50 {
                        return
                    }
                    
                    if tapStartTime == nil {
                        tapStartTime = Date()
                    }
                    
                    if let startTime = tapStartTime, !viewModel.isRecording && !isLongPressing {
                        let duration = Date().timeIntervalSince(startTime)
                        if duration >= Constants.Speech.longPressDuration {
                            isLongPressing = true
                            viewModel.handleLongPressStarted()
                        }
                    }
                    
                    if viewModel.isRecording && !isLongPressing {
                        isLongPressing = true
                    }
                }
                .onEnded { value in
                    let startTime = tapStartTime
                    tapStartTime = nil
                    hasCalledSwipeDown = false

                    let translation = value.translation
                    
                    if viewModel.isRecording {
                        if translation.height > 100 {
                            viewModel.handleSwipeDown()
                            isLongPressing = false
                            return
                        }
                        
                        if translation.height < -50 {
                            viewModel.handleLongPressEnded()
                            viewModel.handleSwipeUpAfterRecording()
                            isLongPressing = false
                            return
                        }
                        
                        viewModel.handleLongPressEnded()
                        isLongPressing = false
                        return
                    }
                    
                    if translation.height > 100 {
                        viewModel.handleSwipeDown()
                        isLongPressing = false
                        return
                    }
                    
                    if translation.height < -50 {
                        viewModel.handleSwipeUp()
                        isLongPressing = false
                        return
                    }
                    
                    if let startTime = startTime {
                        let duration = Date().timeIntervalSince(startTime)
                        if duration < Constants.Speech.longPressDuration && abs(translation.height) < 10 {
                            if viewModel.contentPreview == nil {
                                if viewModel.showPasteButton {
                                    viewModel.showPasteButton = false
                                } else {
                                    viewModel.handleTapOnEmptyArea(at: value.location)
                                }
                            }
                        }
                    }
                    
                    isLongPressing = false
                }
        )
        .onAppear {
            viewModel.onAppear()
            
            if viewModel.isRecording {
                viewModel.cleanup()
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .animation(.easeInOut(duration: Constants.UI.animationDuration), value: viewModel.isRecording)
        .animation(.easeInOut(duration: Constants.UI.animationDuration), value: viewModel.showPasteButton)
    }
}
