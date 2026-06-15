import Foundation
import os
import SwiftUI
import Combine

// MARK: - Navigation Destination
enum NavigationDestination: Identifiable {
    case post(postId: Int)
    case video(videoId: Int)
    case gallery(galleryId: Int)
    case author(authorId: Int)

    var id: String {
        switch self {
        case .post(let postId):
            return "post-\(postId)"
        case .video(let videoId):
            return "video-\(videoId)"
        case .gallery(let galleryId):
            return "gallery-\(galleryId)"
        case .author(let authorId):
            return "author-\(authorId)"
        }
    }
}

// MARK: - Navigation Manager
@MainActor
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var destination: NavigationDestination?
    @Published var shouldNavigate = false
    
    private let apiService = APIService.shared
    private let baseURL = Config.shared.baseURL
    
    private init() {}

    /// Universal Link (Safari/Mail/Notes vb. dış kaynaklardan) için entry-point.
    /// `.onOpenURL` modifier'ından çağrılır. URL'yi parse edip uygun
    /// destination'ı `destination` published property'sine yazar; MainView
    /// bu değişimi sheet ile yakalar.
    @discardableResult
    func handleUniversalLink(_ url: URL) -> Bool {
        // Sadece yayıncı sitesinin alan adından gelen linklere yanıt ver.
        // Host listesi Config.baseURL'den türetilir; white-label deployment'lar için
        // hem `www.example.com` hem çıplak `example.com` versiyonu kabul edilir.
        let host = url.host?.lowercased() ?? ""
        guard Self.allowedUniversalLinkHosts.contains(host) else {
            AppLogger.ui.notice("Universal link host not recognized — \(host, privacy: .public)")
            return false
        }
        Task { await handleURL(url.absoluteString) }
        return true
    }

    /// Config.baseURL → ["www.x.com", "x.com"] (lowercase).
    private static let allowedUniversalLinkHosts: Set<String> = {
        guard let host = URL(string: Config.shared.baseURL)?.host?.lowercased() else { return [] }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return [host, bare, "www.\(bare)"]
    }()

    /// URL string'ini parse edip navigation destination oluşturur.
    /// Hem push bildirimi (string URL) hem universal link (URL) yolundan çağrılır.
    func handleURL(_ urlString: String) async {

        guard let url = URL(string: urlString) else {
            AppLogger.ui.error("Invalid deep link URL")
            return
        }

        let pathComponents = url.path.components(separatedBy: "/").filter { !$0.isEmpty }

        guard !pathComponents.isEmpty else {
            AppLogger.ui.warning("Deep link: empty path")
            return
        }

        let firstComponent = pathComponents[0].lowercased()
        let slug = pathComponents.last ?? ""

        switch firstComponent {
        // /video/{slug} veya /videos/{slug}
        case "video", "videos":
            if let videoId = await findVideoIdBySlug(slug) {
                destination = .video(videoId: videoId)
                shouldNavigate = true
            } else {
                AppLogger.ui.warning("Video slug not resolved")
            }

        // /foto-galeri/{slug}, /galeri/{slug}, /galleries/{slug}, /gallery/{slug}
        case "foto-galeri", "galeri", "galleries", "gallery":
            if let galleryId = await findGalleryIdBySlug(slug) {
                destination = .gallery(galleryId: galleryId)
                shouldNavigate = true
            } else {
                AppLogger.ui.warning("Gallery slug not resolved")
            }

        // /yazar/{slug} veya /author/{slug} veya /authors/{slug}
        case "yazar", "yazarlar", "author", "authors":
            if let authorId = await findAuthorIdBySlug(slug) {
                destination = .author(authorId: authorId)
                shouldNavigate = true
            } else {
                AppLogger.ui.warning("Author slug not resolved")
            }

        // /{slug} formatı — haber/post varsayılan
        default:
            if let postId = await findPostIdBySlug(slug) {
                destination = .post(postId: postId)
                shouldNavigate = true
            } else {
                AppLogger.ui.warning("Post slug not resolved")
            }
        }
    }
    
    /// Slug'dan post ID'sini bul.
    /// API'de doğrudan slug→post endpoint'i yok; `latest` sadece ~12 kayıt
    /// döndürdüğü için arama (`/posts?search=`) üzerinden çözüyoruz.
    private func findPostIdBySlug(_ slug: String) async -> Int? {
        // /posts/123 gibi numerik kestirme
        if let id = Int(slug) { return id }

        // 1) KESİN: /posts?slug={slug} — backend eşleşen postu ilk sırada döndürür.
        if let response = try? await apiService.fetchPost(slug: slug) {
            if let exact = response.data.first(where: { $0.slug == slug }) {
                return exact.id
            }
            if response.data.count == 1, let only = response.data.first {
                return only.id
            }
        }

        // 2) Fallback: arama. Backend kelime bazlı eşleştirir; tam slug eşleşmesi şart.
        let words = slug.split(separator: "-").prefix(5).joined(separator: " ")

        do {
            let response = try await apiService.searchPosts(query: words, perPage: 20)

            // 1) Tam slug eşleşmesi → kesin sonuç
            if let exact = response.data.first(where: { $0.slug == slug }) {
                return exact.id
            }
            // 2) Slug, dönen bir post'un slug'ının başını/sonunu kapsıyorsa
            if let partial = response.data.first(where: {
                slug.hasPrefix($0.slug) || $0.slug.hasPrefix(slug)
            }) {
                return partial.id
            }
            // 3) Son çare: en alakalı ilk sonuç
            return response.data.first?.id
        } catch {
            AppLogger.api.error("Slug lookup failed (post) — \(error.localizedDescription, privacy: .public)")
        }

        return nil
    }
    
    /// Slug'dan video ID'sini bul
    private func findVideoIdBySlug(_ slug: String) async -> Int? {
        do {
            let response = try await apiService.fetchLatestVideos(limit: 100)
            
            // Slug'a göre video bul
            if let video = response.data.first(where: { $0.slug == slug }) {
                return video.id
            }
            
            // Eğer bulunamazsa, URL'den ID çıkarmayı dene
            if let id = Int(slug) {
                return id
            }
            
        } catch {
            AppLogger.api.error("Slug lookup failed (video) — \(error.localizedDescription, privacy: .public)")
        }
        
        return nil
    }
    
    /// Slug'dan gallery ID'sini bul
    private func findGalleryIdBySlug(_ slug: String) async -> Int? {
        do {
            let response = try await apiService.fetchLatestGalleries(limit: 100)
            
            // Slug'a göre gallery bul
            if let gallery = response.data.first(where: { $0.slug == slug }) {
                return gallery.id
            }
            
            // Eğer bulunamazsa, URL'den ID çıkarmayı dene
            if let id = Int(slug) {
                return id
            }
            
        } catch {
            AppLogger.api.error("Slug lookup failed (gallery) — \(error.localizedDescription, privacy: .public)")
        }
        
        return nil
    }
    
    /// Slug'dan author ID'sini bul.
    /// API'de doğrudan slug → id endpoint yok, `fetchAuthors(search:)` ile arar.
    private func findAuthorIdBySlug(_ slug: String) async -> Int? {
        // Önce numerik mi? /yazar/123 gibi link gelirse hızlı yol.
        if let id = Int(slug) { return id }

        do {
            // Search ile filtre — slug genelde isim-soyisim kebab-case olur.
            // Backend `?search=` parametresini name üzerinde matchler.
            let searchTerm = slug.replacingOccurrences(of: "-", with: " ")
            let response = try await apiService.fetchAuthors(page: 1, perPage: 30, search: searchTerm)

            // Tam slug eşleşmesi → kesin sonuç
            if let exact = response.data.first(where: { $0.slug == slug }) {
                return exact.id
            }
            // En azından ilk sonucu kullan (search uyumlu olduğu varsayımıyla)
            return response.data.first?.id
        } catch {
            AppLogger.api.error("Slug lookup failed (author) — \(error.localizedDescription, privacy: .public)")
        }
        return nil
    }

    /// Navigation'ı temizle
    func clearNavigation() {
        destination = nil
        shouldNavigate = false
    }
}
