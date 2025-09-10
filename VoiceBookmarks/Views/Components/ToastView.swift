//
//  ToastView.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import SwiftUI

struct ToastView: View {
    
    let message: String
    let type: ToastType
    
    enum ToastType {
        case success
        case error
        
        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.circle.fill"
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .success:
                return Color.green.opacity(0.95)
            case .error:
                return Color(red: 1.0, green: 0.231, blue: 0.188).opacity(0.95)
            }
        }
        
        var iconColor: Color {
            switch self {
            case .success:
                return .white
            case .error:
                return .white
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 20))
                .foregroundColor(type.iconColor)
            
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(type.backgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}

struct ToastModifier: ViewModifier {
    
    @Binding var toast: ToastItem?
    @State private var isPresented = false
    @State private var autoDismissWorkItem: DispatchWorkItem?
    
    struct ToastItem: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let type: ToastView.ToastType
        
        static func success(_ message: String) -> ToastItem {
            ToastItem(message: message, type: .success)
        }
        
        static func error(_ message: String) -> ToastItem {
            ToastItem(message: message, type: .error)
        }
        
        static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
            lhs.id == rhs.id
        }
    }
    private let autoDismissDuration: TimeInterval = 4.0 // Автоскрытие через 4 секунды
    
    func body(content: Content) -> some View {
        applyToastChange(to:
            ZStack {
            content
            
            if let toast = toast, isPresented {
                VStack {
                    ToastView(message: toast.message, type: toast.type)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if abs(value.translation.height) > 10 || abs(value.translation.width) > 10 {
                                        dismissToast(animated: true)
                                    }
                                }
                        )
                        .onTapGesture {
                            dismissToast(animated: true)
                        }
                    Spacer()
                }
                .zIndex(999)
            }
        }
        )
    }
    
    private func presentToast() {
        cancelAutoDismiss()
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = true
        }
        
        let workItem = DispatchWorkItem { dismissToast(animated: true) }
        autoDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDuration, execute: workItem)
    }
    
    private func dismissToast(animated: Bool, clearImmediately: Bool = false) {
        guard isPresented || toast != nil else { return }
        cancelAutoDismiss()
        let animation = {
            isPresented = false
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.3), animation)
        } else {
            animation()
        }
        
        let clearAction = {
            toast = nil
        }
        if clearImmediately {
            clearAction()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: clearAction)
        }
    }
    
    private func cancelAutoDismiss() {
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil
    }
    
    @ViewBuilder
    private func applyToastChange<V: View>(to view: V) -> some View {
#if os(macOS)
        if #available(macOS 14.0, *) {
            view.onChange(of: toast, initial: false) { _, newToast in
                handleToastChange(newToast)
            }
        } else {
            view.onChange(of: toast) { newToast in
                handleToastChange(newToast)
            }
        }
#else
        view.onChange(of: toast) { newToast in
            handleToastChange(newToast)
        }
#endif
    }
    
    private func handleToastChange(_ newToast: ToastItem?) {
        if newToast != nil {
            presentToast()
        } else {
            dismissToast(animated: true, clearImmediately: true)
        }
    }
}

extension View {
    func toast(_ toast: Binding<ToastModifier.ToastItem?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

