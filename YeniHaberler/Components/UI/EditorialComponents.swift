import SwiftUI

// MARK: - Editorial Eyebrow (kategori üst-etiketi)
/// Gazetelerdeki kırmızı küçük caps kategori etiketi.
struct EditorialEyebrow: View {
    let text: String
    var color: Color = Theme.Brand.primary
    var showDot: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            if showDot {
                Rectangle()
                    .fill(color)
                    .frame(width: 14, height: 2)
                    .accessibilityHidden(true)
            }
            Text(text.uppercased())
                .scaledFont(size: 11, weight: .heavy)
                .tracking(1.4)
                .foregroundColor(color)
                .lineLimit(1)
        }
    }
}

// MARK: - Byline
/// "MUHABİR · SAAT" tarzı yazar bilgisi.
struct Byline: View {
    let author: String?
    let date: String
    var color: Color = Theme.Colors.textSecondary

    var body: some View {
        HStack(spacing: 6) {
            if let author = author, !author.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(author.uppercased())
                    .scaledFont(size: 11, weight: .bold)
                    .tracking(0.6)
                Text("·")
                    .scaledFont(size: 11)
            }
            Text(date)
                .scaledFont(size: 11, weight: .medium)
        }
        .foregroundColor(color)
        .lineLimit(1)
    }
}

// MARK: - Editorial Divider
/// Bölüm arası ince çizgi + opsiyonel ortada işaret.
struct EditorialDivider: View {
    var withGlyph: Bool = false
    var color: Color = Theme.Colors.border

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Rectangle().fill(color).frame(height: 0.5)
            if withGlyph {
                Image(systemName: "circle.fill")
                    .font(.system(size: 4))
                    .foregroundColor(Theme.Brand.gold)
                Rectangle().fill(color).frame(height: 0.5)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Date Bar (üst gazete künyesi)
/// "PAZARTESİ, 12 MAYIS 2026 · YIL 47, SAYI 18,234" tarzı bir başlık.
struct DateBar: View {
    let date: Date
    var label: String? = nil

    private var formatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: date).uppercased()
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Rectangle().fill(Theme.Brand.gold).frame(width: 16, height: 1)
                Text(formatted)
                    .scaledFont(size: 10, weight: .semibold)
                    .tracking(1.2)
                    .foregroundColor(Theme.Colors.textSecondary)
                if let label = label {
                    Text("·")
                        .scaledFont(size: 10)
                        .foregroundColor(Theme.Colors.textTertiary)
                    Text(label.uppercased())
                        .scaledFont(size: 10, weight: .semibold)
                        .tracking(1.0)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Rectangle().fill(Theme.Brand.gold).frame(width: 16, height: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

// MARK: - Editorial Section Header
/// Bölüm başlığı: ince üst çizgi + kalın başlık + opsiyonel "TÜMÜ" linki.
struct EditorialSectionHeader: View {
    let title: String
    var eyebrow: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Üst çizgi
            HStack(spacing: Theme.Spacing.sm) {
                Rectangle()
                    .fill(Theme.Brand.primary)
                    .frame(width: 32, height: 3)
                Rectangle()
                    .fill(Theme.Colors.border)
                    .frame(height: 0.5)
            }
            .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    if let eyebrow = eyebrow {
                        Text(eyebrow.uppercased())
                            .scaledFont(size: 10, weight: .heavy)
                            .tracking(1.4)
                            .foregroundColor(Theme.Brand.primary)
                    }
                    Text(title)
                        .scaledFont(size: 22, weight: .bold, design: .serif)
                        .foregroundColor(Theme.Colors.textPrimary)
                }

                Spacer()

                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        HStack(spacing: 4) {
                            Text(actionTitle)
                                .scaledFont(size: 12, weight: .semibold)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .heavy))
                        }
                        .foregroundColor(Theme.Brand.primary)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

// MARK: - Pill Tag
struct PillTag: View {
    let text: String
    var icon: String? = nil
    var color: Color = Theme.Brand.primary
    var style: Style = .filled

    enum Style { case filled, ghost, outline }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .heavy))
                    .accessibilityHidden(true)
            }
            Text(text.uppercased())
                .scaledFont(size: 10, weight: .heavy)
                .tracking(0.8)
        }
        .foregroundColor(foreground)
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, 4)
        .background(bg)
        .overlay(border)
    }

    @ViewBuilder private var bg: some View {
        switch style {
        case .filled:  color
        case .ghost:   color.opacity(0.12)
        case .outline: Color.clear
        }
    }

    @ViewBuilder private var border: some View {
        switch style {
        case .outline:
            Rectangle().stroke(color, lineWidth: 1)
        default:
            EmptyView()
        }
    }

    private var foreground: Color {
        switch style {
        case .filled:           return .white
        case .ghost, .outline:  return color
        }
    }
}

// MARK: - Reading Progress Bar
/// Detay sayfasında üst kenarda gösterilen okuma ilerleme çubuğu.
struct ReadingProgressBar: View {
    /// 0...1 arası
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.Colors.borderSubtle)
                    .frame(height: 2)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Brand.primary, Theme.Brand.primaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * max(0, min(1, progress)), height: 2)
            }
        }
        .frame(height: 2)
    }
}

// MARK: - Brand Hairline
/// Editorial üst kenar — Hakimiyet kırmızısından altın ince çizgi.
struct BrandHairline: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Theme.Brand.primary).frame(maxWidth: .infinity).frame(height: 3)
            Rectangle().fill(Theme.Brand.gold).frame(maxWidth: .infinity).frame(height: 3)
            Rectangle().fill(Theme.Brand.ink).frame(maxWidth: .infinity).frame(height: 3)
        }
        .frame(height: 3)
    }
}
