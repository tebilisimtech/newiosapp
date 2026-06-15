import Foundation

@MainActor
enum AppBranding {

    static var siteName: String {
        let fromConfig = Config.shared.siteName
        if !fromConfig.isEmpty { return fromConfig }
        return "Haber"
    }

    /// Şehir/bölge adı — örn. "Yozgat". Yoksa boş (metinler şehirsiz kurulur).
    static var cityName: String {
        Config.shared.cityName
    }

    /// Ana sayfa üst şeridi — "YOZGAT GÜNDEMİ" / şehir yoksa "GÜNDEM".
    static var homeBarLabel: String {
        cityName.isEmpty ? "GÜNDEM" : "\(cityName.uppercased()) GÜNDEMİ"
    }

    /// Kısa slogan — API footer açıklaması varsa o, yoksa şehir bazlı türetilir.
    static var tagline: String {
        if let desc = AppSettings.shared.appFooterDescription,
           !desc.trimmingCharacters(in: .whitespaces).isEmpty {
            return desc
        }
        return cityName.isEmpty
            ? "Güvenilir haber kaynağınız"
            : "\(TurkishSuffix.possessive(cityName)) güvenilir haber kaynağı"
    }

    /// "Haber portalı" alt başlığı.
    static var portalLine: String {
        cityName.isEmpty ? "Haber portalı" : "\(TurkishSuffix.possessive(cityName)) haber portalı"
    }

    /// Servisler bölümü eyebrow — "Yozgat'ı yaşa".
    static var servicesEyebrow: String {
        cityName.isEmpty ? "Şehri yaşa" : "\(TurkishSuffix.accusative(cityName)) yaşa"
    }

    /// Köşe yazarları bölümü eyebrow — "Yeni Haberler Kalemleri" (siteName bazlı).
    static var authorsEyebrow: String {
        "\(siteName) Kalemleri"
    }

    /// Günün özeti slogan'ı — "Yozgat'ın nabzı".
    static var briefingTagline: String {
        cityName.isEmpty
            ? "Güne başlamadan önce gündemin nabzı"
            : "Güne başlamadan önce \(TurkishSuffix.possessive(cityName)) nabzı"
    }

    /// Onboarding karşılama başlığı — "Yozgat Hakimiyet'e\nHoşgeldiniz".
    static var welcomeTitle: String {
        "\(TurkishSuffix.dative(siteName))\nHoşgeldiniz"
    }

    /// Telif satırı — "© 2026 Yozgat Hakimiyet · Tüm hakları saklıdır."
    static var copyright: String {
        let year = Calendar.current.component(.year, from: Date())
        return "© \(year) \(siteName) · Tüm hakları saklıdır."
    }

    /// Kısa telif (2 satır) — Settings/SideMenu footer.
    static var copyrightShort: String {
        let year = Calendar.current.component(.year, from: Date())
        return "© \(year) \(siteName)\nTüm hakları saklıdır."
    }

    /// Network User-Agent — site adından türetilmiş slug.
    static var userAgent: String {
        let slug = siteName
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: " ", with: "")
        return "\(slug.isEmpty ? "NewsApp" : slug)-iOS/1.0"
    }
}
