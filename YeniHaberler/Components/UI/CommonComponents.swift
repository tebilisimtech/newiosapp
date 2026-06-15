import SwiftUI

// MARK: - Section Header
/// Anasayfa, kategoriler vb. ekranlarda kullanılan bölüm başlığı.
struct SectionHeader: View {
    let title: String
    let icon: String?
    let iconColor: Color
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        icon: String? = nil,
        iconColor: Color = Theme.Brand.primary,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let icon = icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconColor)
                }
            }

            Text(title)
                .scaledFont(size: 18, weight: .bold)
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .scaledFont(size: 13, weight: .semibold)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Theme.Brand.primary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

// MARK: - Tag / Chip
struct Tag: View {
    let text: String
    let color: Color
    let style: Style

    enum Style {
        case filled, outlined, soft
    }

    init(_ text: String, color: Color = Theme.Brand.primary, style: Style = .soft) {
        self.text = text
        self.color = color
        self.style = style
    }

    var body: some View {
        Text(text.uppercased())
            .scaledFont(size: 10, weight: .bold)
            .tracking(0.5)
            .foregroundColor(foreground)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 4)
            .background(background)
            .overlay(border)
            .clipShape(Capsule())
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .filled:   Capsule().fill(color)
        case .outlined: Capsule().fill(Color.clear)
        case .soft:     Capsule().fill(color.opacity(0.14))
        }
    }

    @ViewBuilder private var border: some View {
        switch style {
        case .outlined: Capsule().stroke(color, lineWidth: 1)
        default:        EmptyView()
        }
    }

    private var foreground: Color {
        switch style {
        case .filled:   return .white
        case .outlined, .soft: return color
        }
    }
}

// MARK: - Aspect Image
/// Frame overflow yapmadan, sabit aspect ratio'da resim göstermek için.
/// Color.clear + aspectRatio(.fit) ile container'ı sabitleriz, görseli overlay olarak yerleştiririz.
struct AspectImage: View {
    let url: String
    let aspectRatio: CGFloat   // width / height
    var contentMode: ContentMode = .fill
    var placeholderIcon: String = "photo"

    init(url: String, aspectRatio: CGFloat, contentMode: ContentMode = .fill, placeholderIcon: String = "photo") {
        self.url = url
        self.aspectRatio = aspectRatio
        self.contentMode = contentMode
        self.placeholderIcon = placeholderIcon
    }

    var body: some View {
        Theme.Colors.surfaceElevated
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(
                ThemedAsyncImage(url: url, aspect: contentMode, placeholderIcon: placeholderIcon)
            )
            .clipped()
    }
}

// MARK: - Async Image with Fallback
/// Backwards-compatible wrapper. Görseller artık 2-katmanlı `ImageCache`
/// üzerinden yüklenir — aynı URL 2. açılışta network'e gitmez.
struct ThemedAsyncImage: View {
    let url: String
    let aspect: ContentMode
    let placeholderIcon: String

    init(url: String, aspect: ContentMode = .fill, placeholderIcon: String = "photo") {
        self.url = url
        self.aspect = aspect
        self.placeholderIcon = placeholderIcon
    }

    var body: some View {
        CachedAsyncImage(url: url, aspect: aspect, placeholderIcon: placeholderIcon)
    }
}

// MARK: - Image Gradient Overlay
struct ImageGradientOverlay: View {
    let intensity: CGFloat

    init(intensity: CGFloat = 0.85) {
        self.intensity = intensity
    }

    var body: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.black.opacity(0.25 * intensity),
                Color.black.opacity(0.65 * intensity),
                Color.black.opacity(0.92 * intensity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .scaledFont(size: 15, weight: .semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md + 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(Theme.Brand.primary)
            )
            .themedShadow(Theme.Shadow.small)
        }
    }
}

// MARK: - Icon Button (toolbar)
struct IconButton: View {
    let icon: String
    let action: () -> Void
    var foreground: Color = Theme.Colors.textPrimary

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(foreground)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(Theme.Colors.surface)
                )
        }
    }
}
