import SwiftUI
import UIKit
import Combine

// MARK: - RemoteTheme
//
// Sunucudan (settings) gelen tema değerlerini saklayan runtime store.
// White-label panelindeki `primary_color`, `primary_font`, `secondary_font`,
// `font_color`, `title_font_color` alanları buradan okunur ve `Theme` token'larını
// besler. Değerler UserDefaults'a cache'lenir; böylece açılışta settings yüklenmeden
// de son bilinen renk/font kullanılır (ilk frame'de yanıp sönme olmaz).
//
// `version` değiştiğinde (yeni ayar geldiğinde) `MainView` köküne `.id(version)`
// verildiği için tüm arayüz yeni temayla yeniden çizilir.
final class RemoteTheme: ObservableObject {
    static let shared = RemoteTheme()

    private enum Keys {
        static let primaryColor   = "remoteTheme.primaryColor"
        static let titleFontColor = "remoteTheme.titleFontColor"
        static let fontColor      = "remoteTheme.fontColor"
        static let primaryFont    = "remoteTheme.primaryFont"
        static let secondaryFont  = "remoteTheme.secondaryFont"
    }

    /// Tema her güncellendiğinde artar; kök view bunu izleyerek yeniden çizilir.
    @Published private(set) var version: Int = 0

    // Ham (doğrulanmış) değerler
    private(set) var primaryColorHex: String?
    private(set) var titleColorHex: String?
    private(set) var bodyColorHex: String?
    private(set) var primaryFontFamily: String?   // ör. "Open Sans"
    private(set) var secondaryFontFamily: String?

    private init() {
        let d = UserDefaults.standard
        primaryColorHex     = d.string(forKey: Keys.primaryColor)
        titleColorHex       = d.string(forKey: Keys.titleFontColor)
        bodyColorHex        = d.string(forKey: Keys.fontColor)
        primaryFontFamily   = d.string(forKey: Keys.primaryFont)
        secondaryFontFamily = d.string(forKey: Keys.secondaryFont)
    }

    /// settings yüklendiğinde çağrılır. Değişiklik varsa cache'i günceller ve sürümü artırır.
    @MainActor
    func update(from s: SettingsData) {
        let newPrimary   = Self.normalizeHex(s.primaryColor)
        let newTitle     = Self.normalizeHex(s.titleFontColor)
        let newBody      = Self.normalizeHex(s.fontColor)
        let newPrimaryF  = Self.fontFamily(from: s.primaryFont)
        let newSecondF   = Self.fontFamily(from: s.secondaryFont)

        let changed =
            newPrimary  != primaryColorHex ||
            newTitle    != titleColorHex   ||
            newBody     != bodyColorHex    ||
            newPrimaryF != primaryFontFamily ||
            newSecondF  != secondaryFontFamily

        primaryColorHex     = newPrimary
        titleColorHex       = newTitle
        bodyColorHex        = newBody
        primaryFontFamily   = newPrimaryF
        secondaryFontFamily = newSecondF

        let d = UserDefaults.standard
        d.set(newPrimary,  forKey: Keys.primaryColor)
        d.set(newTitle,    forKey: Keys.titleFontColor)
        d.set(newBody,     forKey: Keys.fontColor)
        d.set(newPrimaryF, forKey: Keys.primaryFont)
        d.set(newSecondF,  forKey: Keys.secondaryFont)

        if changed { version += 1 }
    }

    // MARK: - Çözümlenmiş Renkler

    /// Marka/vurgu rengi. Panel boşsa varsayılan editorial kırmızı.
    var primaryColor: Color {
        if let hex = primaryColorHex { return Color(hex: hex) }
        return Color(hex: "#C8102E")
    }

    /// Marka renginin koyu varyantı (gradient'ler için). Sunucu rengi varsa onu kullanır.
    var primaryColorDark: Color {
        if let hex = primaryColorHex { return Color(hex: hex).darkened(by: 0.18) }
        return Color(hex: "#8C0A20")
    }

    /// Açık temada gövde metni rengi override'ı (panelde tanımlıysa). Koyu tema dokunulmaz.
    var lightBodyColorHex: String? { bodyColorHex }
    /// Açık temada başlık metni rengi override'ı.
    var lightTitleColorHex: String? { titleColorHex ?? bodyColorHex }

    // MARK: - Çözümlenmiş Fontlar

    var hasCustomFont: Bool { primaryFontFamily != nil }

    /// Sunucu fontunu (varsa) çözer. Font bundle'da kayıtlı değilse aileden çıkarımla
    /// sistem fontuna (sans/serif) düşer; böylece kod hep "panel-driven" kalır ve
    /// ileride TTF eklenirse otomatik devreye girer.
    func font(size: CGFloat, weight: Font.Weight, design: Font.Design) -> Font {
        // Başlık design'ı (.serif) ikincil fontu, diğerleri birincil fontu kullanır.
        let family = (design == .serif ? secondaryFontFamily : primaryFontFamily) ?? primaryFontFamily

        guard let family else {
            // Panelde font yok → mevcut sistem davranışı aynen korunur.
            return .system(size: size, weight: weight, design: design)
        }

        // İstenen ağırlıktan başlayıp aileyi koruyarak geriye düşen adaylar.
        for psName in Self.psCandidates(family: family, weight: weight) {
            if UIFont(name: psName, size: size) != nil {
                return .custom(psName, size: size)
            }
        }
        // Aile hiç gömülü değilse aileden çıkarımla sistem fontuna düş.
        return .system(size: size, weight: weight, design: Self.inferDesign(family: family, fallback: design))
    }

    // MARK: - Yardımcılar

    /// "#RRGGBB" benzeri geçerli bir hex'e normalize eder; geçersizse nil.
    private static func normalizeHex(_ raw: String?) -> String? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if !s.hasPrefix("#") { s = "#" + s }
        let cleaned = s.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted)
        guard [3, 6, 8].contains(cleaned.count) else { return nil }
        return "#" + cleaned
    }

    /// "Open Sans-Regular" / "Open Sans-Bold" → "Open Sans"
    private static func fontFamily(from raw: String?) -> String? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        for suffix in ["-Regular", "-Bold", "-Medium", "-SemiBold", "-Semibold",
                       "-Light", "-Italic", "-Black", "-Thin"] {
            if s.hasSuffix(suffix) { s = String(s.dropLast(suffix.count)); break }
        }
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Panel aile adını gömülü fontun PostScript ön ekine eşler.
    /// Çoğu Google fontunda "Aile" → boşluksuz hâli; birkaç istisna alias'lanır.
    private static func psBase(for family: String) -> String {
        let nospace = family.replacingOccurrences(of: " ", with: "")
        // Panelde eski ad geçen ama dosyası halefiyle gelen fontlar:
        let aliases: [String: String] = [
            "sourcesanspro": "SourceSans3"   // "Source Sans Pro" → Source Sans 3 (görsel olarak aynı)
        ]
        return aliases[nospace.lowercased()] ?? nospace
    }

    /// İstenen ağırlık için denenecek PostScript adları (önce en yakın, sonra fallback).
    /// "Open Sans" → "OpenSans-Bold", "OpenSans-SemiBold", "OpenSans-Regular" ...
    /// Not: "SemiBold" hem büyük-B hem küçük-b ("Semibold", ör. Source Sans) denenir.
    private static func psCandidates(family: String, weight: Font.Weight) -> [String] {
        let base = psBase(for: family)
        func n(_ s: String) -> String { "\(base)-\(s)" }
        let semibold = [n("SemiBold"), n("Semibold")]
        switch weight {
        case .black, .heavy:
            return [n("ExtraBold")] + [n("Bold")] + semibold + [n("Regular")]
        case .bold:
            return [n("Bold")] + semibold + [n("Regular")]
        case .semibold:
            return semibold + [n("Medium"), n("Bold"), n("Regular")]
        case .medium:
            return [n("Medium")] + semibold + [n("Regular")]
        case .light, .thin, .ultraLight:
            return [n("Light"), n("Regular")]
        default:
            return [n("Regular")]
        }
    }

    /// Aile adından sistem font design'ı tahmin eder (TTF yoksa fallback).
    private static func inferDesign(family: String, fallback: Font.Design) -> Font.Design {
        let f = family.lowercased()
        let serifFamilies = ["serif", "georgia", "times", "merriweather",
                             "playfair", "slab", "noto serif", "pt serif", "lora"]
        if serifFamilies.contains(where: { f.contains($0) }) { return .serif }
        // Open Sans, Roboto, Lato, Inter, Nunito vb. → sans
        return .default
    }
}

// MARK: - Color Darkening
extension Color {
    /// Rengi belirtilen oranda koyulaştırır (0...1).
    func darkened(by amount: CGFloat) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return Color(hue: Double(h), saturation: Double(s),
                     brightness: Double(max(0, b - amount)), opacity: Double(a))
    }
}
