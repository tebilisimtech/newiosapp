import SwiftUI

// MARK: - Toast
//
// Yeniden kullanılabilir floating banner. Üst kenardan kayarak girer, belirli
// süre sonra otomatik kaybolur. Kullanıcı dokununca da kapanır.
//
// Kullanım:
//   @State private var toast: Toast?
//   ...
//   .toast($toast)
//   ...
//   toast = Toast(message: "Kayıt tamam", kind: .success)
struct Toast: Equatable, Identifiable {
    let id = UUID()
    let message: String
    let kind: Kind

    enum Kind {
        case success, error, info

        var color: Color {
            switch self {
            case .success: return Color(red: 0.16, green: 0.65, blue: 0.27)
            case .error:   return Color(red: 0.85, green: 0.20, blue: 0.20)
            case .info:    return Color(red: 0.12, green: 0.45, blue: 0.85)
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error:   return "exclamationmark.triangle.fill"
            case .info:    return "info.circle.fill"
            }
        }
    }
}

// MARK: - Toast Banner
private struct ToastBanner: View {
    let toast: Toast
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: toast.kind.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text(toast.message)
                .scaledFont(size: 13, weight: .semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(toast.kind.color)
        )
        .themedShadow(Theme.Shadow.medium)
        .padding(.horizontal, Theme.Spacing.xl)
        .onTapGesture { onDismiss() }
    }
}

// MARK: - View Modifier
private struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?
    let duration: Double

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toast {
                    ToastBanner(toast: toast, onDismiss: { dismiss() })
                        .padding(.top, Theme.Spacing.lg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        // Task id'si toast.id'ye bağlı — yeni toast gelirse veya
                        // view kaybolursa task otomatik iptal olur.
                        .task(id: toast.id) {
                            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                            await MainActor.run { dismiss() }
                        }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast?.id)
    }

    private func dismiss() {
        toast = nil
    }
}

extension View {
    /// Üst kenardan kayan otomatik kapanır banner gösterir.
    /// - Parameters:
    ///   - toast: Binding — `nil` set edince banner kaybolur.
    ///   - duration: Otomatik kapanma süresi (saniye). Varsayılan 3.5.
    func toast(_ toast: Binding<Toast?>, duration: Double = 3.5) -> some View {
        modifier(ToastModifier(toast: toast, duration: duration))
    }
}
