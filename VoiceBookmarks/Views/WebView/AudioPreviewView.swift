//
//  AudioPreviewView.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
import AVFoundation

struct AudioPreviewView: View {
    
    let audioURL: URL
    let onLoadFinish: () -> Void
    let onLoadFail: ((Error) -> Void)?
    
    @StateObject private var playerManager = AudioPlayerManager()
    @State private var currentURL: URL
    private let logger = LoggerService.shared
    
    init(audioURL: URL, onLoadFinish: @escaping () -> Void = {}, onLoadFail: ((Error) -> Void)? = nil) {
        self.audioURL = audioURL
        self._currentURL = State(initialValue: audioURL)
        self.onLoadFinish = onLoadFinish
        self.onLoadFail = onLoadFail
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if playerManager.isLoading && !playerManager.isLoaded {
                LoadingView(message: "Загрузка аудио...")
                    .frame(height: 120)
            } else if let error = playerManager.loadError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.error)
                    Text("Ошибка загрузки аудио")
                        .font(.body)
                        .foregroundColor(.appText)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 120)
                .padding()
            } else if playerManager.isLoaded {
                Button(action: {
                    playerManager.togglePlayPause()
                }) {
                    Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gold)
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { playerManager.currentTime },
                            set: { newValue in
                                playerManager.seek(to: newValue)
                            }
                        ),
                        in: 0...max(playerManager.duration, 1),
                        onEditingChanged: { editing in
                            if !editing {
                                playerManager.seek(to: playerManager.currentTime)
                            }
                        }
                    )
                    .tint(.gold)
                    
                    HStack {
                        Text(formatTime(playerManager.currentTime))
                            .font(.caption)
                            .foregroundColor(.appText)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Text(formatTime(playerManager.duration))
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .onAppear {
            logger.info("AudioPreviewView появился, настраиваем плеер для URL: \(currentURL.absoluteString)", category: .webview)
            if currentURL.isFileURL {
                let fileExists = FileManager.default.fileExists(atPath: currentURL.path)
                logger.info("Локальный аудио файл существует: \(fileExists), путь: \(currentURL.path)", category: .webview)
                if !fileExists {
                    logger.error("Локальный аудио файл не найден: \(currentURL.path)", category: .webview)
                    let error = NSError(domain: "AudioPreviewView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Аудио файл не найден"])
                    onLoadFail?(error)
                    return
                }
                
                if let attributes = try? FileManager.default.attributesOfItem(atPath: currentURL.path),
                   let fileSize = attributes[.size] as? Int {
                    let minAudioSize: Int = 1024 // 1 КБ
                    if fileSize < minAudioSize {
                        logger.error("Аудио файл слишком маленький (\(fileSize) байт), возможно поврежден: \(currentURL.path)", category: .webview)
                        let error = NSError(domain: "AudioPreviewView", code: -11829, userInfo: [NSLocalizedDescriptionKey: "Аудио файл поврежден или слишком маленький"])
                        onLoadFail?(error)
                        return
                    }
                }
            }
            playerManager.setupPlayer(url: currentURL, onLoadFinish: onLoadFinish, onLoadFail: onLoadFail)
        }
        .onDisappear {
            logger.info("AudioPreviewView исчез, очищаем плеер", category: .webview)
            playerManager.cleanup()
        }
        .onChange(of: audioURL) { newURL in
            if newURL != currentURL {
                logger.info("AudioPreviewView: URL изменился с \(currentURL.absoluteString) на \(newURL.absoluteString), перезагружаем плеер", category: .webview)
                currentURL = newURL
                playerManager.cleanup()
                
                if newURL.isFileURL {
                    let fileExists = FileManager.default.fileExists(atPath: newURL.path)
                    logger.info("Локальный аудио файл существует: \(fileExists), путь: \(newURL.path)", category: .webview)
                    if !fileExists {
                        logger.error("Локальный аудио файл не найден: \(newURL.path)", category: .webview)
                        let error = NSError(domain: "AudioPreviewView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Аудио файл не найден"])
                        onLoadFail?(error)
                        return
                    }
                    
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: newURL.path),
                       let fileSize = attributes[.size] as? Int {
                        let minAudioSize: Int = 1024 // 1 КБ
                        if fileSize < minAudioSize {
                            logger.error("Аудио файл слишком маленький (\(fileSize) байт), возможно поврежден: \(newURL.path)", category: .webview)
                            let error = NSError(domain: "AudioPreviewView", code: -11829, userInfo: [NSLocalizedDescriptionKey: "Аудио файл поврежден или слишком маленький"])
                            onLoadFail?(error)
                            return
                        }
                    }
                }
                
                playerManager.setupPlayer(url: newURL, onLoadFinish: onLoadFinish, onLoadFail: onLoadFail)
            }
        }
    }
    
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}


class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLoaded = false
    @Published var isLoading = true
    @Published var loadError: Error?
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var updateTimer: Timer?
    private let logger = LoggerService.shared
    
    func setupPlayer(url: URL, onLoadFinish: @escaping () -> Void, onLoadFail: ((Error) -> Void)?) {
        logger.info("Создание AVPlayer для аудио: \(url.absoluteString)", category: .webview)
        
        isLoading = true
        isLoaded = false
        
        let item = AVPlayerItem(url: url)
        playerItem = item
        
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        
        item.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        item.addObserver(self, forKeyPath: "duration", options: [.new], context: nil)
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let currentSeconds = time.seconds
            if currentSeconds.isFinite {
                self.currentTime = currentSeconds
            }
        }
        
        newPlayer.addObserver(self, forKeyPath: "timeControlStatus", options: [.new], context: nil)
        
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true, options: [])
            logger.info("Аудио сессия успешно настроена для воспроизведения", category: .webview)
        } catch {
            logger.error("Ошибка настройки аудио сессии: \(error)", category: .webview)
        }
        #endif
        
        self.onLoadFinish = onLoadFinish
        self.onLoadFail = onLoadFail
    }
    
    private var onLoadFinish: (() -> Void)?
    private var onLoadFail: ((Error) -> Void)?
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }
        
        if keyPath == "status" {
            handlePlayerItemStatus()
        } else if keyPath == "duration" {
            handleDurationUpdate()
        } else if keyPath == "timeControlStatus" {
            handleTimeControlStatus()
        }
    }
    
    private func handlePlayerItemStatus() {
        guard let item = playerItem else { 
            logger.warning("handlePlayerItemStatus вызван, но playerItem отсутствует", category: .webview)
            return 
        }
        
        logger.debug("AVPlayerItem статус изменился: \(item.status.rawValue)", category: .webview)
        
        switch item.status {
        case .readyToPlay:
            logger.info("AVPlayerItem готов к воспроизведению", category: .webview)
            
            if item.duration.isValid && !item.duration.isIndefinite {
                let durationSeconds = item.duration.seconds
                logger.info("Длительность аудио: \(durationSeconds) секунд", category: .webview)
            } else {
                logger.warning("Длительность аудио не определена или бесконечна", category: .webview)
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isLoading = false
                self.isLoaded = true
                
                if item.duration.isValid && !item.duration.isIndefinite {
                    self.duration = item.duration.seconds
                }
                
                self.onLoadFinish?()
                logger.info("AudioPlayerManager: загрузка завершена успешно, isLoaded=true", category: .webview)
            }
            
        case .failed:
            let error = item.error ?? NSError(domain: "AudioPreviewView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неизвестная ошибка загрузки"])
            logger.error("Ошибка загрузки AVPlayerItem: \(error)", category: .webview)
            
            if let nsError = error as NSError? {
                logger.error("Детали ошибки: domain=\(nsError.domain), code=\(nsError.code), description=\(nsError.localizedDescription)", category: .webview)
                
                if nsError.domain == "AVFoundationErrorDomain" && nsError.code == -11829 {
                    if let url = item.asset as? AVURLAsset, url.url.isFileURL {
                        let fileExists = FileManager.default.fileExists(atPath: url.url.path)
                        logger.error("Файл существует: \(fileExists), путь: \(url.url.path)", category: .webview)
                        if !fileExists {
                            logger.error("Аудио файл не найден по указанному пути", category: .webview)
                        } else {
                            logger.error("Файл существует, но не может быть открыт AVPlayer. Возможно, файл поврежден или имеет неподдерживаемый формат", category: .webview)
    }
}
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isLoading = false
                self.isLoaded = false
                self.loadError = error
                self.onLoadFail?(error)
                logger.error("AudioPlayerManager: загрузка завершена с ошибкой", category: .webview)
            }
            
        case .unknown:
            logger.debug("AVPlayerItem статус: unknown, ожидаем изменения", category: .webview)
            break
            
        @unknown default:
            logger.warning("AVPlayerItem неизвестный статус: \(item.status.rawValue)", category: .webview)
            break
        }
    }
    
    private func handleDurationUpdate() {
        guard let item = playerItem, item.duration.isValid && !item.duration.isIndefinite else { return }
        DispatchQueue.main.async { [weak self] in
            self?.duration = item.duration.seconds
        }
    }
    
    private func handleTimeControlStatus() {
        guard let player = player else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch player.timeControlStatus {
            case .playing:
                self.isPlaying = true
            case .paused:
                self.isPlaying = false
            case .waitingToPlayAtSpecifiedRate:
                break
            @unknown default:
                break
            }
        }
    }
    
    func togglePlayPause() {
        guard let player = player else {
            logger.warning("togglePlayPause вызван, но player отсутствует", category: .webview)
            return
        }
        
        guard isLoaded else {
            logger.warning("togglePlayPause вызван, но аудио еще не загружено (isLoaded=false)", category: .webview)
            return
        }
        
        if isPlaying {
            logger.info("Пауза воспроизведения", category: .webview)
            player.pause()
        } else {
            logger.info("Начало воспроизведения", category: .webview)
            player.play()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, let player = self.player else { return }
                if player.timeControlStatus != .playing && !self.isPlaying {
                    self.logger.warning("Воспроизведение не началось через 0.5 секунды после вызова play()", category: .webview)
                }
            }
        }
    }
    
    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
        currentTime = time
    }
    
    func cleanup() {
        logger.info("Освобождение AVPlayer для аудио", category: .webview)
        
        if let item = playerItem {
            item.removeObserver(self, forKeyPath: "status")
            item.removeObserver(self, forKeyPath: "duration")
        }
        
        if let player = player {
            player.removeObserver(self, forKeyPath: "timeControlStatus")
            
            if let observer = timeObserver {
                player.removeTimeObserver(observer)
                timeObserver = nil
            }
        }

        updateTimer?.invalidate()
        updateTimer = nil
        
        player?.pause()
        player = nil
        playerItem = nil
        
        onLoadFinish = nil
        onLoadFail = nil
    }
}
