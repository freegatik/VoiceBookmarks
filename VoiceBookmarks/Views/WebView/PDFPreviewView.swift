//
//  PDFPreviewView.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
import PDFKit
#if canImport(UIKit)
import UIKit

struct PDFPreviewView: UIViewRepresentable {
    
    let pdfURL: URL
    let onLoadFinish: () -> Void
    let onLoadFail: ((Error) -> Void)?
    
    private let logger = LoggerService.shared
    
    init(pdfURL: URL, onLoadFinish: @escaping () -> Void = {}, onLoadFail: ((Error) -> Void)? = nil) {
        self.pdfURL = pdfURL
        self.onLoadFinish = onLoadFinish
        self.onLoadFail = onLoadFail
    }
    
    func makeUIView(context: Context) -> PDFView {
        logger.info("Создание PDFView для: \(pdfURL.absoluteString)", category: .webview)
        
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        loadPDF(into: pdfView, url: pdfURL)
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        let currentURL = pdfView.document?.documentURL
        if currentURL != pdfURL {
            logger.info("PDF URL изменился, перезагружаем документ: \(currentURL?.absoluteString ?? "nil") → \(pdfURL.absoluteString)", category: .webview)
            loadPDF(into: pdfView, url: pdfURL)
        }
    }
    
    private func loadPDF(into pdfView: PDFView, url: URL) {
        if url.isFileURL {
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            logger.info("Локальный PDF файл существует: \(fileExists), путь: \(url.path)", category: .webview)
            if !fileExists {
                logger.error("Локальный PDF файл не найден: \(url.path)", category: .webview)
                onLoadFail?(NSError(domain: "PDFPreviewView", code: -1, userInfo: [NSLocalizedDescriptionKey: "PDF файл не найден: \(url.lastPathComponent)"]))
                return
            }
        }
        
        guard let document = PDFDocument(url: url) else {
            logger.error("Не удалось создать PDFDocument из URL: \(url.absoluteString)", category: .webview)
            onLoadFail?(NSError(domain: "PDFPreviewView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось загрузить PDF документ"]))
            return
        }
        
        if document.pageCount == 0 {
            logger.warning("PDF документ создан, но не содержит страниц", category: .webview)
            onLoadFail?(NSError(domain: "PDFPreviewView", code: -1, userInfo: [NSLocalizedDescriptionKey: "PDF документ пуст или поврежден"]))
            return
        }
        
        pdfView.document = document
        logger.info("PDF документ загружен успешно: \(document.pageCount) страниц", category: .webview)
        onLoadFinish()
    }
    
    static func dismantleUIView(_ pdfView: PDFView, coordinator: ()) {
        pdfView.document = nil
    }
}
#endif

