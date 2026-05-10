//
//  WKWebViewRepresentable.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit

struct WKWebViewRepresentable: UIViewRepresentable {
    
    let url: URL
    let htmlString: String?

    let configuration: WKWebViewConfiguration
    let headers: [String: String]?
    let onLoadFinish: () -> Void
    let onLoadFail: (Error) -> Void
    let onLongPressEmptyArea: (() -> Void)?
    
    private let logger = LoggerService.shared
    
    init(
        url: URL,
        htmlString: String? = nil,
        configuration: WKWebViewConfiguration,
        headers: [String: String]? = nil,
        onLoadFinish: @escaping () -> Void,
        onLoadFail: @escaping (Error) -> Void,
        onLongPressEmptyArea: (() -> Void)? = nil
    ) {
        self.url = url
        self.htmlString = htmlString
        self.configuration = configuration
        self.headers = headers
        self.onLoadFinish = onLoadFinish
        self.onLoadFail = onLoadFail
        self.onLongPressEmptyArea = onLongPressEmptyArea
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true
        webView.scrollView.backgroundColor = UIColor.clear
        context.coordinator.attach(to: webView, longPressHandler: onLongPressEmptyArea)
        
        if #available(iOS 16.4, *) {
            webView.isInspectable = false
        }
        
        loadContent(into: webView, coordinator: context.coordinator, isInitialLoad: true)
        
        return webView
    }
    
    private func loadContent(into webView: WKWebView, coordinator: Coordinator, isInitialLoad: Bool = false) {
        if !isInitialLoad {
            if let loadedURL = coordinator.getLoadedURL(), loadedURL.path == url.path {
                return
            }
        }
        
        if url.isFileURL && url.pathExtension.lowercased() == "html" {
            if let fileData = try? Data(contentsOf: url),
               let fileString = String(data: fileData, encoding: .utf8) {
                coordinator.setLocalFile(true)
                let baseURL = url.deletingLastPathComponent()
                coordinator.startLoadTimer()
                webView.loadHTMLString(fileString, baseURL: baseURL)
                coordinator.markContentLoaded(for: url, usingHTMLString: true)
            } else if let htmlString = htmlString {
                coordinator.setLocalFile(true)
                let baseURL = url.deletingLastPathComponent()
                coordinator.startLoadTimer()
                webView.loadHTMLString(htmlString, baseURL: baseURL)
                coordinator.markContentLoaded(for: url, usingHTMLString: true)
            } else {
                coordinator.setLocalFile(true)
                let directoryURL = FileManager.default.temporaryDirectory
                coordinator.startLoadTimer()
                webView.loadFileURL(url, allowingReadAccessTo: directoryURL)
                coordinator.markContentLoaded(for: url, usingHTMLString: false)
            }
        } else if url.isFileURL {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: url.path) {
                logger.error("Файл не существует: \(url.path)", category: .webview)
                let error = NSError(domain: "WKWebView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Файл не найден: \(url.lastPathComponent)"])
                coordinator.onLoadFail(error)
                return
            }
            
            let directoryURL: URL
            if url.path.contains("/tmp/") || url.path.contains("temporaryDirectory") {
                directoryURL = FileManager.default.temporaryDirectory
            } else {
                directoryURL = url.deletingLastPathComponent()
            }
            
            coordinator.setLocalFile(true)
            coordinator.startLoadTimer()
            webView.loadFileURL(url, allowingReadAccessTo: directoryURL)
            coordinator.markContentLoaded(for: url, usingHTMLString: false)
        } else {
            coordinator.setLocalFile(false)
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            if let headers = headers {
                for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
            }
            coordinator.startLoadTimer()
            webView.load(request)
            coordinator.markContentLoaded(for: url, usingHTMLString: false)
        }
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let currentURL = webView.url
        let loadedURL = context.coordinator.getLoadedURL()
        let urlChanged: Bool
        
        if url.pathExtension.lowercased() == "html", htmlString != nil {
            if let loaded = loadedURL {
                urlChanged = loaded.path != url.path
            } else if let current = currentURL {
                urlChanged = current.path != url.path
            } else {
                urlChanged = true
            }
        } else {
            urlChanged = currentURL?.path != url.path && currentURL?.absoluteString != url.absoluteString
        }
        
        if urlChanged || !context.coordinator.isContentLoaded(for: url) {
            context.coordinator.resetContentLoaded()
            if url.pathExtension.lowercased() == "html" {
                webView.stopLoading()
            }
            loadContent(into: webView, coordinator: context.coordinator, isInitialLoad: false)
        }
    }
    
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.cancelLoadTimer()
        webView.stopLoading()
        webView.navigationDelegate = nil
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onLoadFinish: onLoadFinish,
            onLoadFail: onLoadFail
        )
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIGestureRecognizerDelegate {
        
        let onLoadFinish: () -> Void
        let onLoadFail: (Error) -> Void
        private let logger = LoggerService.shared
        private var loadTimer: Timer?
        private let loadTimeout: TimeInterval = 15

        
        private var isLocalFile = false
        private var hasLoadedContent = false
        private var loadedURL: URL?
        private var isUsingHTMLString = false
        private weak var webView: WKWebView?
        
        init(
            onLoadFinish: @escaping () -> Void,
            onLoadFail: @escaping (Error) -> Void
        ) {
            self.onLoadFinish = onLoadFinish
            self.onLoadFail = onLoadFail
        }
        
        func attach(to webView: WKWebView, longPressHandler: (() -> Void)?) {
            self.webView = webView
            
            guard let handler = longPressHandler else { return }
            
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            recognizer.minimumPressDuration = Constants.Speech.longPressDuration
            recognizer.delaysTouchesBegan = false
            recognizer.requiresExclusiveTouchType = false
            recognizer.allowableMovement = 12
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
            webView.addGestureRecognizer(recognizer)
            
            longPressAction = handler
        }
        
        private var longPressAction: (() -> Void)?
        
        @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began,
                  let webView,
                  let action = longPressAction else {
                return
            }
            
            let location = recognizer.location(in: webView)
            let adjustedPoint = CGPoint(x: max(location.x, 0), y: max(location.y, 0))
            
            let script = """
            (function() {
                var el = document.elementFromPoint(\(adjustedPoint.x), \(adjustedPoint.y));
                if (!el) { return { empty: true }; }
                var tag = (el.tagName || '').toLowerCase();
                var isInteractive = /(a|button|input|textarea|select|label)/i.test(tag);
                var text = (el.innerText || '').trim();
                var isImage = tag === 'img' || tag === 'video' || tag === 'canvas';
                return { empty: (!isInteractive && !isImage && text.length === 0), textLength: text.length, tag: tag };
            })();
            """
            
            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                
                if let error {
                    self.logger.warning("WKWebView: не удалось определить область long press: \(error.localizedDescription)", category: .webview)
                    return
                }
                
                if let dict = result as? [String: Any],
                   let isEmpty = dict["empty"] as? Bool,
                   isEmpty {
                    DispatchQueue.main.async {
                        action()
                    }
                }
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func setLocalFile(_ isLocal: Bool) {
            isLocalFile = isLocal
        }
        
        func markContentLoaded(for url: URL, usingHTMLString: Bool = false) {
            hasLoadedContent = true
            loadedURL = url
            isUsingHTMLString = usingHTMLString
        }
        
        func resetContentLoaded() {
            hasLoadedContent = false
            loadedURL = nil
            isUsingHTMLString = false
        }
        
        func isContentLoaded(for url: URL) -> Bool {
            guard hasLoadedContent, let loaded = loadedURL else { return false }
            
            if isUsingHTMLString {
                return loaded.path == url.path
            } else {
                return loaded.path == url.path || loaded.absoluteString == url.absoluteString
            }
        }
        
        func getLoadedURL() -> URL? {
            return loadedURL
        }
        
        func startLoadTimer() {
            cancelLoadTimer()
            loadTimer = Timer.scheduledTimer(withTimeInterval: loadTimeout, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                logger.error("WKWebView таймаут загрузки (\(loadTimeout) сек)", category: .webview)
                let error = NSError(domain: "WKWebView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Таймаут загрузки"])
                onLoadFail(error)
            }
        }
        
        
        func cancelLoadTimer() {
            loadTimer?.invalidate()
            loadTimer = nil
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            cancelLoadTimer()
            onLoadFinish()
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            logger.error("WKWebView ошибка загрузки: \(error.localizedDescription)", category: .webview)
            cancelLoadTimer()
            onLoadFail(error)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            logger.error("WKWebView provisional ошибка: \(error.localizedDescription), domain: \(nsError.domain), code: \(nsError.code)", category: .webview)
            
            if isLocalFile && nsError.domain == "WKErrorDomain" && (nsError.code == -2 || nsError.code == -1009 || nsError.localizedDescription.contains("DownloadFailed")) {
                if let currentURL = webView.url, currentURL.isFileURL {
                    logger.warning("WKWebView: ошибка загрузки ресурса для локального файла (игнорируем, файл загружен): \(error.localizedDescription)", category: .webview)
                    onLoadFinish()
                    return
                } else {
                    logger.error("WKWebView: ошибка DownloadFailed, файл не загружен", category: .webview)
                }
            }
            
            cancelLoadTimer()
            onLoadFail(error)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
        
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            logger.error("WKWebView процесс завершился, перезагружаем", category: .webview)
            if webView.url != nil {
                webView.reload()
            } else {
                let error = NSError(domain: "WKWebView", code: -2, userInfo: [NSLocalizedDescriptionKey: "WebKit процесс завершился"])
                onLoadFail(error)
            }
        }
        
        deinit {
            cancelLoadTimer()
        }
    }
}
#endif
