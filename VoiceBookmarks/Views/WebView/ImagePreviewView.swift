//
//  ImagePreviewView.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit

struct ImagePreviewView: View {
    
    let imageURL: URL
    let onLoadFinish: () -> Void
    let onLoadFail: ((Error) -> Void)?
    let headers: [String: String]?
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var loadTask: Task<Void, Never>?
    
    private let logger = LoggerService.shared
    
    init(imageURL: URL, onLoadFinish: @escaping () -> Void = {}, onLoadFail: ((Error) -> Void)? = nil, headers: [String: String]? = nil) {
        self.imageURL = imageURL
        self.onLoadFinish = onLoadFinish
        self.onLoadFail = onLoadFail
        self.headers = headers
    }
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            if isLoading {
                LoadingView(message: "Loading image...")
            } else if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            } else {
                ErrorStateView(
                    message: loadError ?? "Не удалось загрузить изображение",
                    retryAction: {
                        Task {
                            await loadImage()
                        }
                    }
                )
            }
        }
        .task {
            loadTask = Task {
                await loadImage()
            }
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
            image = nil
            isLoading = false
        }
    }
    
    private func loadImage() async {
        isLoading = true
        loadError = nil
        
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)

            if !Task.isCancelled {
                await MainActor.run {
                    if isLoading {
                        isLoading = false
                        loadError = "Таймаут загрузки изображения. Проверьте подключение к интернету."
                        logger.error("Таймаут загрузки изображения: \(imageURL.absoluteString)", category: .webview)
                        onLoadFail?(NSError(domain: "ImagePreviewView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Таймаут загрузки"]))
                    }
                }
            }
        }
        
        defer { timeoutTask.cancel() }
        
        do {
            let data: Data
            if imageURL.isFileURL {
                data = try Data(contentsOf: imageURL)
            } else {
                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 10

                config.timeoutIntervalForResource = 15

                let session = URLSession(configuration: config)
                
                var request = URLRequest(url: imageURL)
                request.timeoutInterval = 10

                if let headers = headers { for (k,v) in headers { request.setValue(v, forHTTPHeaderField: k) } }
                let (remoteData, _) = try await session.data(for: request)
                data = remoteData
            }
            
            let decodedImage: UIImage? = await Task.detached(priority: .userInitiated) {
                guard let sourceImage = UIImage(data: data) else { return nil }
                
                let maxDimension: CGFloat = 2048
                let size = sourceImage.size
                
                guard size.width > 0 && size.height > 0 && size.width.isFinite && size.height.isFinite else {
                    return sourceImage
                }
                
                let maxSize = max(size.width, size.height)
                guard maxSize.isFinite && maxSize > 0 else {
                    return sourceImage
                }
                
                let scale: CGFloat = maxSize > maxDimension 
                    ? maxDimension / maxSize
                    : 1.0
                
                guard scale.isFinite && scale > 0 && scale <= 1.0 else {
                    return sourceImage
                }
                
                let newSize = CGSize(width: size.width * scale, height: size.height * scale)
                guard newSize.width.isFinite && newSize.height.isFinite && newSize.width > 0 && newSize.height > 0 else {
                    return sourceImage
                }
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                defer { UIGraphicsEndImageContext() }
                sourceImage.draw(in: CGRect(origin: .zero, size: newSize))
                return UIGraphicsGetImageFromCurrentImageContext()
            }.value
            
            await MainActor.run {
                image = decodedImage
                isLoading = false
                
                if image != nil {
                    logger.info("Изображение загружено успешно (оптимизировано)", category: .webview)
                    onLoadFinish()
                } else {
                    loadError = "Неверный формат изображения"
                    logger.error("Не удалось создать UIImage из данных", category: .webview)
                    onLoadFail?(NSError(domain: "ImagePreviewView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неверный формат изображения"]))
                }
            }
        } catch {
            await MainActor.run {
                loadError = "Error: \(error.localizedDescription)"
                isLoading = false
                logger.error("Error загрузки изображения: \(error)", category: .webview)
                onLoadFail?(error)
            }
        }
    }
}
#endif
