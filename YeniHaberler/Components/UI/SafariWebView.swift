import SwiftUI
import SafariServices

// MARK: - Safari Web View
//
// SFSafariViewController köprüsü. Gerçek Safari motoru çalıştığı için:
//  • site analytics / cookie / session korunur (BİK trafiği sayılır)
//  • site reklamları aynen çalışır
//  • kullanıcı uygulamadan çıkmış hissetmez (in-app)
//
// Native detay ekranları (Post/Article/Video/Gallery) `articleOpenMode == .web`
// iken içerik yerine bunu gösterir.
struct SafariWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true

        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(Theme.Brand.primary)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

// MARK: - Content URL Builder
//
// Detay URL'sini üretir ve uygulama kaynaklı trafiği ölçmek için UTM
// parametreleri ekler. Site Analytics'i bu sayede "app referral" olarak
// raporlar — BİK denetiminde gerçek/bot ayrımı için kritik.
enum ContentURLBuilder {

    /// - Parameters:
    ///   - rawURL: API'den gelen tam URL (varsa).
    ///   - slug: URL yoksa baseURL + slug ile kurmak için.
    ///   - medium: UTM medium — örn. "app", "push", "share".
    ///   - campaign: UTM campaign — içerik tipi (post/video/gallery/article).
    static func url(rawURL: String?, slug: String?, medium: String, campaign: String) -> URL? {
        let base = Config.shared.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let urlString: String
        if let raw = rawURL, !raw.isEmpty {
            urlString = raw.hasPrefix("http") ? raw : "\(base)/\(raw.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
        } else if let slug = slug, !slug.isEmpty {
            urlString = "\(base)/\(slug.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
        } else {
            return nil
        }

        guard var components = URLComponents(string: urlString) else {
            return URL(string: urlString)
        }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "utm_source", value: "ios_app"))
        items.append(URLQueryItem(name: "utm_medium", value: medium))
        items.append(URLQueryItem(name: "utm_campaign", value: campaign))
        components.queryItems = items
        return components.url
    }
}
