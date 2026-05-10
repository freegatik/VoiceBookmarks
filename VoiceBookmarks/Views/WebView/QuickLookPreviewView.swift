//
//  QuickLookPreviewView.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
import QuickLook
#if canImport(UIKit)
import UIKit

struct QuickLookPreviewView: UIViewControllerRepresentable {
    
    let sourceURL: URL
    let onLoadFinish: () -> Void
    let onLoadFail: ((Error) -> Void)?
    let headers: [String: String]?
    
    private let logger = LoggerService.shared
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadFinish: onLoadFinish, onLoadFail: onLoadFail)
    }
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        context.coordinator.logger = logger
        
        if sourceURL.isFileURL {
            context.coordinator.fileURL = sourceURL
            onLoadFinish()
        } else {
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        let error = NSError(domain: "QuickLookPreviewView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Таймаут загрузки"])
                        onLoadFail?(error)
                    }
                }
            }
            
            Task {
                defer { timeoutTask.cancel() }
                do {
                    let config = URLSessionConfiguration.default
                    config.timeoutIntervalForRequest = 15
                    config.timeoutIntervalForResource = 30
                    let session = URLSession(configuration: config)
                    
                    var request = URLRequest(url: sourceURL)
                    request.timeoutInterval = 15
                    if let headers = headers { for (k,v) in headers { request.setValue(v, forHTTPHeaderField: k) } }
                    let (data, _) = try await session.data(for: request)
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ql_\(UUID().uuidString)." + (sourceURL.pathExtension.isEmpty ? "dat" : sourceURL.pathExtension))
                    try data.write(to: tempURL)
                    await MainActor.run {
                        context.coordinator.fileURL = tempURL
                        context.coordinator.isTemporaryFile = true

                        controller.reloadData()
                        onLoadFinish()
                    }
                } catch {
                    await MainActor.run {
                        onLoadFail?(error)
                    }
                }
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        var fileURL: URL?
        let onLoadFinish: () -> Void
        let onLoadFail: ((Error) -> Void)?
        var logger: LoggerService?
        var isTemporaryFile: Bool = false
        
        init(onLoadFinish: @escaping () -> Void, onLoadFail: ((Error) -> Void)?) {
            self.onLoadFinish = onLoadFinish
            self.onLoadFail = onLoadFail
        }
        
        deinit {
            cleanupTemporaryFile()
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return fileURL == nil ? 0 : 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return fileURL! as NSURL
        }
        
        private func cleanupTemporaryFile() {
            guard let fileURL = fileURL, isTemporaryFile, fileURL.isFileURL else { return }
            do {
                try FileManager.default.removeItem(at: fileURL)
                logger?.info("Временный файл QuickLook удален: \(fileURL.lastPathComponent)", category: .fileOperation)
            } catch {
                logger?.error("Error удаления временного файла QuickLook: \(error.localizedDescription)", category: .fileOperation)
            }
        }
    }
}
#endif
