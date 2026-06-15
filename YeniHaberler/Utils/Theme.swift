import SwiftUI

// MARK: - Theme (Editorial v2)
// Modern gazete editöryal stili: serif başlıklar, kağıt hissi, refined renk paleti.
enum Theme {

    // MARK: - Brand Colors
    enum Brand {
        /// Marka/vurgu rengi — panel `primary_color`'dan gelir, yoksa editorial kırmızı.
        static var primary: Color { RemoteTheme.shared.primaryColor }
        static var primaryDark: Color { RemoteTheme.shared.primaryColorDark }
        /// Anthracite — koyu lacivert-siyah arası, dijital gazete tonu.
        static let ink = Color(hex: "#0F1419")
        /// Warm gold — dekoratif çizgiler, premium işaretler için.
        static let gold = Color(hex: "#B89968")
    }

    // MARK: - Semantic Colors (dark mode uyumlu)
    enum Colors {
        // Backgrounds — kağıt hissi
        static let background = Color("AppBackground", bundle: nil, default: Color(hex: "#FBF8F4"), dark: Color(hex: "#0A0D11"))
        static let surface = Color("AppSurface", bundle: nil, default: Color(hex: "#FFFFFF"), dark: Color(hex: "#13171D"))
        static let surfaceElevated = Color("AppSurfaceElevated", bundle: nil, default: Color(hex: "#FFFFFF"), dark: Color(hex: "#1A1F26"))
        static let groupedBackground = Color("AppGrouped", bundle: nil, default: Color(hex: "#F5F1EB"), dark: Color(hex: "#08090C"))

        // Text — açık temada panel `font_color` override edilebilir; koyu tema korunur.
        static var textPrimary: Color {
            let light = RemoteTheme.shared.lightBodyColorHex.map { Color(hex: $0) } ?? Color(hex: "#0F1419")
            return Color("AppText", bundle: nil, default: light, dark: Color(hex: "#F5F2EC"))
        }
        static let textSecondary = Color("AppTextSecondary", bundle: nil, default: Color(hex: "#56616D"), dark: Color(hex: "#A8B0BB"))
        static let textTertiary = Color("AppTextTertiary", bundle: nil, default: Color(hex: "#8A95A1"), dark: Color(hex: "#6F7681"))
        static let textOnDark = Color.white
        static let textOnBrand = Color.white

        // Borders
        static let border = Color("AppBorder", bundle: nil, default: Color(hex: "#D9D2C8"), dark: Color(hex: "#2A2F37"))
        static let borderSubtle = Color("AppBorderSubtle", bundle: nil, default: Color(hex: "#E8E2D8"), dark: Color(hex: "#1F242B"))

        // States
        static let success = Color(hex: "#0F7A4A")
        static let warning = Color(hex: "#B8731C")
        static let danger = Color(hex: "#B8232E")
        static let info = Color(hex: "#1E5BAA")

        // Category palette — editorial, muted tones
        static let categoryRed = Color(hex: "#B8232E")
        static let categoryBlue = Color(hex: "#1E5BAA")
        static let categoryPurple = Color(hex: "#6B3FA0")
        static let categoryGreen = Color(hex: "#0F7A4A")
        static let categoryOrange = Color(hex: "#B8731C")
        static let categoryPink = Color(hex: "#A8336E")
    }

    // MARK: - Typography Scale
    // Editorial style: serif başlıklar (gazete hissi), sans-serif gövde.
    enum Typography {

        /// Tüm tipografi buradan geçer; panelde font tanımlıysa (primary/secondary_font)
        /// onu, yoksa sistem fontunu (verilen design ile) kullanır.
        private static func font(_ size: CGFloat, _ weight: Font.Weight, _ design: Font.Design) -> Font {
            RemoteTheme.shared.font(size: size, weight: weight, design: design)
        }

        // MARK: Display / Headlines — SERIF (panel ikincil fontu)
        static func display(_ weight: Font.Weight = .heavy) -> Font { font(40, weight, .serif) }
        static func h1(_ weight: Font.Weight = .bold) -> Font { font(30, weight, .serif) }
        static func h2(_ weight: Font.Weight = .bold) -> Font { font(24, weight, .serif) }
        static func h3(_ weight: Font.Weight = .semibold) -> Font { font(20, weight, .serif) }
        static func h4(_ weight: Font.Weight = .semibold) -> Font { font(17, weight, .serif) }

        // MARK: Lead / Subhead — SERIF italik
        static func lead(_ weight: Font.Weight = .regular) -> Font { font(18, weight, .serif) }

        // MARK: Body — SANS (panel birincil fontu)
        static func body(_ weight: Font.Weight = .regular) -> Font { font(15, weight, .default) }
        static func bodyLarge(_ weight: Font.Weight = .regular) -> Font { font(16, weight, .default) }
        static func bodySmall(_ weight: Font.Weight = .regular) -> Font { font(13, weight, .default) }

        // MARK: Meta / Labels
        static func caption(_ weight: Font.Weight = .medium) -> Font { font(12, weight, .default) }
        static func micro(_ weight: Font.Weight = .semibold) -> Font { font(10, weight, .default) }
        /// Eyebrow: küçük üst-etiket (KATEGORI gibi)
        static func eyebrow(_ weight: Font.Weight = .bold) -> Font { font(11, weight, .default) }
        /// Byline: yazar adı küçük caps
        static func byline(_ weight: Font.Weight = .bold) -> Font { font(11, weight, .default) }
    }

    // MARK: - Spacing (4-based)
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let huge: CGFloat = 48
    }

    // MARK: - Corner Radius
    // Editorial stil: keskin köşeler tercih edilir. Sadece kart/etiketlerde hafif radius.
    enum Radius {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
        static let pill: CGFloat = 999
    }

    // MARK: - Shadow
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum Shadow {
        static let small = ShadowStyle(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        static let medium = ShadowStyle(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        static let large = ShadowStyle(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 12)
        static let card = ShadowStyle(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        static let floatingBar = ShadowStyle(color: Color.black.opacity(0.16), radius: 24, x: 0, y: 10)
    }

    // MARK: - Animations
    enum Animations {
        static let snappy: Animation = .spring(response: 0.32, dampingFraction: 0.78)
        static let smooth: Animation = .spring(response: 0.5, dampingFraction: 0.86)
        static let bounce: Animation = .spring(response: 0.4, dampingFraction: 0.66)
        static let easeQuick: Animation = .easeOut(duration: 0.18)
    }
}

// MARK: - Dynamic Color helper
extension Color {
    init(_ name: String, bundle: Bundle?, default light: Color, dark: Color) {
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - View Modifiers
extension View {
    func themedShadow(_ style: Theme.ShadowStyle = Theme.Shadow.card) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    /// Editorial kart: yumuşak yüzey + ince border + small shadow.
    func editorialCard(radius: CGFloat = Theme.Radius.lg) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .themedShadow(Theme.Shadow.small)
    }

    func cardStyle(
        radius: CGFloat = Theme.Radius.lg,
        shadow: Theme.ShadowStyle = Theme.Shadow.card,
        background: Color = Theme.Colors.surface
    ) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: radius).fill(background))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .themedShadow(shadow)
    }

    func sectionPadding() -> some View {
        self.padding(.horizontal, Theme.Spacing.xl)
    }

    func subtleBorder(radius: CGFloat = Theme.Radius.lg) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - Category Color Helper
extension Theme {
    static func categoryColor(for id: String) -> Color {
        let palette: [Color] = [
            Colors.categoryRed,
            Colors.categoryBlue,
            Colors.categoryPurple,
            Colors.categoryGreen,
            Colors.categoryOrange,
            Colors.categoryPink
        ]
        let hash = abs(id.hashValue)
        return palette[hash % palette.count]
    }
}
