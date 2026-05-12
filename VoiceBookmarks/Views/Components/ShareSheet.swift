//
//  ShareSheet.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let items: [Any]

    func makeCoordinator() -> Coordinator {
        Coordinator(binding: $isPresented)
    }

    func makeUIViewController(context: Context) -> ShareSheetPresenterViewController {
        let vc = ShareSheetPresenterViewController()
        let coordinator = context.coordinator
        vc.onDismiss = { coordinator.dismiss() }
        vc.activityItems = items
        return vc
    }

    func updateUIViewController(_ uiViewController: ShareSheetPresenterViewController, context: Context) {
        uiViewController.onDismiss = { context.coordinator.dismiss() }
        uiViewController.activityItems = items
    }

    final class Coordinator {
        var binding: Binding<Bool>
        init(binding: Binding<Bool>) {
            self.binding = binding
        }

        func dismiss() {
            binding.wrappedValue = false
        }
    }
}

final class ShareSheetPresenterViewController: UIViewController {
    var onDismiss: (() -> Void)?
    var activityItems: [Any] = [] {
        didSet {
            guard isViewLoaded else { return }
            attemptPresentActivityIfNeeded()
        }
    }

    private var didPresentActivity = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.accessibilityIdentifier = "VoiceBookmarksSharePresenterHost"
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attemptPresentActivityIfNeeded()
    }

    private func attemptPresentActivityIfNeeded() {
        guard !didPresentActivity, presentedViewController == nil else { return }
        if activityItems.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.onDismiss?()
            }
            return
        }
        didPresentActivity = true
        let av = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        av.completionWithItemsHandler = { [weak self] _, _, _, _ in
            DispatchQueue.main.async {
                self?.onDismiss?()
            }
        }
        if let pop = av.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        present(av, animated: true)
    }
}
#endif
