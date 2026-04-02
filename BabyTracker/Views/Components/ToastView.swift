import SwiftUI

// MARK: - Toast Model

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: ToastStyle
    var duration: Double = 2.5

    enum ToastStyle {
        case success, warning, error, info

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error:   return "xmark.circle.fill"
            case .info:    return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error:   return .red
            case .info:    return .blue
            }
        }
    }
}

// MARK: - Toast Container

@Observable
final class ToastContainer {
    var current: Toast? = nil

    func show(_ toast: Toast) {
        current = toast
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            if current?.id == toast.id { current = nil }
        }
    }

    func success(_ message: String) { show(Toast(message: message, style: .success)) }
    func warning(_ message: String) { show(Toast(message: message, style: .warning)) }
    func error(_ message: String)   { show(Toast(message: message, style: .error)) }
    func info(_ message: String)    { show(Toast(message: message, style: .info)) }
}

// MARK: - Toast View

struct ToastOverlay: View {
    let toast: Toast?

    var body: some View {
        VStack {
            Spacer()
            if let toast {
                HStack(spacing: 10) {
                    Image(systemName: toast.style.icon)
                        .foregroundStyle(toast.style.color)
                        .font(.system(size: 16, weight: .semibold))
                    Text(toast.message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 100)   // above tab bar
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast?.id)
    }
}

// MARK: - View modifier

struct ToastModifier: ViewModifier {
    @Environment(ToastContainer.self) private var container

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            ToastOverlay(toast: container.current)
        }
    }
}

extension View {
    /// Apply once at the root level (inside AppRootView or MainTabView).
    func toastContainer() -> some View {
        modifier(ToastModifier())
    }
}
