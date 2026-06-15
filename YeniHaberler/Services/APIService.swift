import Foundation
import os

class APIService {
    static let shared = APIService()
    private let config = Config.shared
    
    // URLSession configuration with timeout settings
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0 // 30 saniye request timeout
        configuration.timeoutIntervalForResource = 60.0 // 60 saniye resource timeout
        configuration.waitsForConnectivity = true // Bağlantı beklesin
        return URLSession(configuration: configuration)
    }()
    
    private init() {}

    /// API v2 (Sanctum) — `apiKey` query parametresi kaldırıldı, auth `Authorization: Bearer` header'ında.
    private func buildURL(endpoint: String) -> URL? {
        let urlString = "\(config.baseURL)/api/v2/\(endpoint)"
        return URL(string: urlString)
    }

    /// Mevcut URL'ye query parametreleri eklemek için yardımcı.
    /// Eski kodda manuel `URLComponents.queryItems` ile `apiKey` ekleniyordu — artık gereksiz.
    private func appendQueryItems(_ items: [URLQueryItem], to url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var existing = components?.queryItems ?? []
        existing.append(contentsOf: items)
        components?.queryItems = existing
        return components?.url
    }

    /// Pagination parametreleri (page + per_page) için URL query item üreticisi.
    /// Her ikisi de nil ise boş dizi döner; endpoint orijinal davranışını korur.
    static func pageQueryItems(page: Int?, perPage: Int?) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let page = page {
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        if let perPage = perPage {
            items.append(URLQueryItem(name: "per_page", value: String(perPage)))
        }
        return items
    }

    private func performRequest<T: Decodable>(url: URL, responseType: T.Type, retryCount: Int = 3, quickFail: Bool = false) async throws -> T {
        var lastError: Error?

        // Retry mekanizması - 500 hataları için
        for attempt in 0..<retryCount {
            // URLRequest oluştur ve header'ları ekle
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("YeniHaberler-iOS/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "X-Requested-With")

            // Sanctum Bearer token (yeni API v2)
            if !config.apiKey.isEmpty {
                request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
            }

            // Timeout ayarları
            request.timeoutInterval = 30.0
            
            do {
                let (data, response) = try await urlSession.data(for: request)
        
        // HTTP status kontrolü
        if let httpResponse = response as? HTTPURLResponse {
                    // 429 Too Many Requests — Retry-After header'ına saygı göster
                    // Yeni API throttle: 100 req/min (genel), 50 req/min (contact)
                    if httpResponse.statusCode == 429 && attempt < retryCount - 1 && !quickFail {
                        let retryAfterHeader = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        // Retry-After: saniye cinsinden integer veya HTTP-date olabilir.
                        let retryAfterSeconds = Double(retryAfterHeader ?? "") ?? Double(2 << attempt)  // 2s, 4s, 8s
                        AppLogger.api.warning("Throttled (429) — waiting \(retryAfterSeconds, privacy: .public)s")
                        try await Task.sleep(nanoseconds: UInt64(retryAfterSeconds * 1_000_000_000))
                        continue
                    }

                    // 401 Unauthorized — token geçersiz/eksik, retry anlamsız
                    if httpResponse.statusCode == 401 {
                        AppLogger.api.error("Unauthorized (401) — token geçersiz veya eksik")
                        throw NSError(domain: "APIService", code: 401, userInfo: [
                            NSLocalizedDescriptionKey: "Yetkilendirme başarısız. API token'ı kontrol edin."
                        ])
                    }

                    // 5xx hataları için retry (500, 502 Bad Gateway, 503, 504 Gateway Timeout, 522 Cloudflare timeout)
                    let retryableStatuses: Set<Int> = [500, 502, 503, 504, 520, 521, 522, 523, 524]
                    if retryableStatuses.contains(httpResponse.statusCode) && attempt < retryCount - 1 && !quickFail {
                        let delay = Double(attempt + 1) * 1.5 // 1.5s, 3s, 4.5s
                        if attempt == 0 {
                            AppLogger.api.warning("Server \(httpResponse.statusCode, privacy: .public) — retrying up to \(retryCount, privacy: .public) times")
                        }
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    
            // Content-Type kontrolü
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            let isHTML = contentType.contains("text/html") || contentType.contains("text/plain")
            
            // HTML yanıt kontrolü (hem status hem de content-type)
            if httpResponse.statusCode >= 400 || isHTML {
                let responseString = String(data: data, encoding: .utf8) ?? ""
                
                // 500 hatası için daha detaylı log (URL path public, query string private)
                if httpResponse.statusCode == 500 {
                    AppLogger.api.error("Server 500 — path: \(url.path, privacy: .public)")
                }
                
                if responseString.trimmingCharacters(in: .whitespaces).hasPrefix("<") || isHTML {
                    AppLogger.api.error("HTML response — status: \(httpResponse.statusCode, privacy: .public), path: \(url.path, privacy: .public)")
                    // 500 hatası için daha açıklayıcı mesaj
                    if httpResponse.statusCode == 500 {
                        let error = NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Sunucu hatası (500). Lütfen daha sonra tekrar deneyin."])
                        lastError = error
                        if attempt < retryCount - 1 && !quickFail {
                            continue
                        }
                        throw error
                    }
                    throw NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned HTML instead of JSON"])
                }
                
                // JSON error response kontrolü
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJson["message"] as? String {
                    AppLogger.api.error("API error — status: \(httpResponse.statusCode, privacy: .public), message: \(message, privacy: .private)")
                } else if !responseString.isEmpty {
                    AppLogger.api.error("API error — status: \(httpResponse.statusCode, privacy: .public)")
                }
                
                // 500 hatası için özel mesaj
                if httpResponse.statusCode == 500 {
                    let error = NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Sunucu hatası (500). Lütfen daha sonra tekrar deneyin."])
                    lastError = error
                    if attempt < retryCount - 1 && !quickFail {
                        continue
                    }
                    throw error
                }
                
                throw NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
            }
        }
        
        // JSON decode
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            AppLogger.api.error("Decode failed — type: \(String(describing: T.self), privacy: .public)")
            CrashReporter.shared.logError(error, context: [
                "endpoint": url.path,
                "responseType": String(describing: T.self),
                "stage": "decode"
            ])
            throw error
        }
            } catch {
                lastError = error

                // CancellationError için retry yapma
                if error is CancellationError {
                    throw error
                }

                // Network hatası için retry (quickFail modunda retry yapma)
                if let urlError = error as? URLError {
                    // Sadece belirli network hataları için retry
                    let retryableErrors: [URLError.Code] = [
                        .timedOut,
                        .cannotConnectToHost,
                        .networkConnectionLost,
                        .notConnectedToInternet,
                        .dnsLookupFailed
                    ]

                    if retryableErrors.contains(urlError.code) && attempt < retryCount - 1 && !quickFail {
                        let delay = Double(attempt + 1) * 1.0
                        AppLogger.api.warning("Network retry \(attempt + 1, privacy: .public)/\(retryCount, privacy: .public) — code: \(urlError.code.rawValue, privacy: .public)")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                }

                // Son denemede başarısızsa Crashlytics'e bildir (geçici network'ler değil, kalıcı hata)
                if attempt == retryCount - 1 {
                    CrashReporter.shared.logError(error, context: [
                        "endpoint": url.path,
                        "attempts": retryCount,
                        "stage": "network"
                    ])
                }

                throw error
            }
        }

        // Tüm denemeler başarısız oldu
        let finalError = lastError ?? NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request failed after \(retryCount) attempts"])
        CrashReporter.shared.logError(finalError, context: [
            "endpoint": url.path,
            "attempts": retryCount,
            "stage": "exhausted"
        ])
        throw finalError
    }
    
    // MARK: - Posts
    
    func fetchPosts() async throws -> PostResponse {
        guard let url = buildURL(endpoint: "posts") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    func fetchHeadlines(page: Int? = nil, perPage: Int? = nil) async throws -> PostResponse {
        // headlines endpoint'i `limit` parametresi kullanır (`per_page` değil).
        // Ayrıca bazı Nova CMS kurulumlarında, sitenin mevcut manşet sayısından fazla
        // limit istendiğinde sunucu 500 atıyor (ör. wanhaber.com → 5 manşet var,
        // limit≥6 → 500). Bu yüzden istenen limit'i fail-fast olarak deneriz; 500 gelirse
        // limit=5 ile fallback yaparız.
        let requested = perPage ?? 10
        do {
            return try await fetchHeadlinesAttempt(page: page, limit: requested, quickFail: requested > 5)
        } catch {
            guard requested > 5 else { throw error }
            return try await fetchHeadlinesAttempt(page: page, limit: 5, quickFail: false)
        }
    }

    private func fetchHeadlinesAttempt(page: Int?, limit: Int, quickFail: Bool) async throws -> PostResponse {
        guard let base = buildURL(endpoint: "posts/headlines") else {
            throw URLError(.badURL)
        }
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let page = page {
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        let url = appendQueryItems(items, to: base) ?? base
        return try await performRequest(url: url, responseType: PostResponse.self, quickFail: quickFail)
    }
    
    func fetchTopHeadlines() async throws -> PostResponse {
        guard let url = buildURL(endpoint: "posts/topheadlines") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    func fetchBreakingNews(page: Int? = nil, perPage: Int? = nil) async throws -> PostResponse {
        guard let base = buildURL(endpoint: "posts/breaking") else {
            throw URLError(.badURL)
        }
        let url = appendQueryItems(Self.pageQueryItems(page: page, perPage: perPage), to: base) ?? base
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    func fetchLatestPosts(limit: Int? = nil) async throws -> PostResponse {
        let endpoint = limit.map { "posts/latest/\($0)" } ?? "posts/latest"
        guard let url = buildURL(endpoint: endpoint) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }

    /// `/posts/latest` query formu: page + limit + excepts[] desteği.
    /// Sonsuz kaydırmalı haber zincirinde "bir sonraki haberi" çekmek için kullanılır.
    func fetchLatestPosts(page: Int, limit: Int, excepts: [Int]) async throws -> PostResponse {
        guard let base = buildURL(endpoint: "posts/latest") else {
            throw URLError(.badURL)
        }
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        for id in excepts {
            items.append(URLQueryItem(name: "excepts[]", value: String(id)))
        }
        let url = appendQueryItems(items, to: base) ?? base
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    func fetchFeaturedPosts() async throws -> PostResponse {
        guard let url = buildURL(endpoint: "posts/featured") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    func fetchPopularPosts() async throws -> PostResponse {
        guard let url = buildURL(endpoint: "posts/popular") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    func fetchPostDetail(id: Int) async throws -> PostDetailResponse {
        guard let url = buildURL(endpoint: "posts/\(id)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostDetailResponse.self)
    }
    
    func fetchRelatedPosts(postId: Int, categoryId: String) async throws -> PostResponse {
        var components = URLComponents(string: "\(config.baseURL)/api/v2/posts/\(postId)/related")
        components?.queryItems = [
            URLQueryItem(name: "category_id", value: categoryId)
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    func searchPosts(query: String, page: Int? = nil, perPage: Int? = nil) async throws -> PostResponse {
        // API v2: /posts?search={query} — eski /posts/search/{q} path'i artık 404.
        guard let base = buildURL(endpoint: "posts") else {
            throw URLError(.badURL)
        }
        var items = [URLQueryItem(name: "search", value: query)]
        items.append(contentsOf: Self.pageQueryItems(page: page, perPage: perPage))
        let url = appendQueryItems(items, to: base) ?? base
        return try await performRequest(url: url, responseType: PostResponse.self)
    }

    /// Slug → post çözümü (universal link / deep link). Backend `/posts?slug={slug}`
    /// eşleşen postu ilk sırada döndürür; çağıran taraf tam slug eşleşmesini doğrular.
    func fetchPost(slug: String) async throws -> PostResponse {
        guard let base = buildURL(endpoint: "posts") else {
            throw URLError(.badURL)
        }
        let url = appendQueryItems([URLQueryItem(name: "slug", value: slug)], to: base) ?? base
        return try await performRequest(url: url, responseType: PostResponse.self)
    }

    func fetchPostsByCategory(categoryId: Int, page: Int = 1, limit: Int = 12) async throws -> PostResponse {
        var components = URLComponents(string: "\(config.baseURL)/api/v2/posts/category/\(categoryId)")
        components?.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = components?.url else { throw URLError(.badURL) }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }

    // MARK: - Categories

    func fetchCategories(page: Int = 1, perPage: Int = 50) async throws -> CategoryResponse {
        var components = URLComponents(string: "\(config.baseURL)/api/v2/categories")
        components?.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        guard let url = components?.url else { throw URLError(.badURL) }
        return try await performRequest(url: url, responseType: CategoryResponse.self)
    }

    func fetchCategoryDetail(id: Int) async throws -> CategoryDetailResponse {
        guard let url = buildURL(endpoint: "categories/\(id)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: CategoryDetailResponse.self)
    }

    // MARK: - Galleries
    
    func fetchGalleries(page: Int? = nil, perPage: Int? = nil) async throws -> GalleryResponse {
        guard let base = buildURL(endpoint: "galleries") else {
            throw URLError(.badURL)
        }
        let url = appendQueryItems(Self.pageQueryItems(page: page, perPage: perPage), to: base) ?? base
        return try await performRequest(url: url, responseType: GalleryResponse.self)
    }
    
    func fetchLatestGalleries(limit: Int? = nil) async throws -> GalleryResponse {
        let endpoint = limit.map { "galleries/latest/\($0)" } ?? "galleries/latest"
        guard let url = buildURL(endpoint: endpoint) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: GalleryResponse.self)
    }
    
    func fetchFeaturedGalleries() async throws -> GalleryResponse {
        guard let url = buildURL(endpoint: "galleries/featured") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: GalleryResponse.self)
    }
    
    func fetchGalleryDetail(id: Int) async throws -> GalleryDetailResponse {
        guard let url = buildURL(endpoint: "galleries/\(id)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: GalleryDetailResponse.self)
    }
    
    // MARK: - Videos
    
    func fetchVideos(page: Int? = nil, perPage: Int? = nil) async throws -> VideoResponse {
        guard let base = buildURL(endpoint: "videos") else {
            throw URLError(.badURL)
        }
        let url = appendQueryItems(Self.pageQueryItems(page: page, perPage: perPage), to: base) ?? base
        return try await performRequest(url: url, responseType: VideoResponse.self)
    }
    
    func fetchLatestVideos(limit: Int? = nil) async throws -> VideoResponse {
        let endpoint = limit.map { "videos/latest/\($0)" } ?? "videos/latest"
        guard let url = buildURL(endpoint: endpoint) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: VideoResponse.self)
    }
    
    func fetchFeaturedVideos() async throws -> VideoResponse {
        guard let url = buildURL(endpoint: "videos/featured") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: VideoResponse.self)
    }
    
    func fetchTrendVideos() async throws -> VideoResponse {
        guard let url = buildURL(endpoint: "videos/trend") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: VideoResponse.self)
    }
    
    func fetchVideoDetail(id: Int) async throws -> VideoDetailResponse {
        guard let url = buildURL(endpoint: "videos/\(id)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: VideoDetailResponse.self)
    }
    
    func searchVideos(query: String) async throws -> VideoResponse {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = buildURL(endpoint: "videos?search=\(encodedQuery)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: VideoResponse.self)
    }
    
    // MARK: - Services (Special URL format)
    
    private func buildServiceURL(path: String, parameters: [String: String]) -> URL? {
        var components = URLComponents(string: "\(Config.shared.baseURL)/api/v2/services/\(path)")
        var queryItems: [URLQueryItem] = []
        
        for (key, value) in parameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        components?.queryItems = queryItems
        return components?.url
    }
    
    func fetchWeather(city: String = "istanbul", district: String? = nil) async throws -> WeatherResponse {
        var params = ["city": city]
        if let district = district, !district.isEmpty {
            params["district"] = district
        }
        guard let url = buildServiceURL(path: "weather", parameters: params) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: WeatherResponse.self)
    }
    
    func fetchPrayerTimes(city: String = "istanbul", district: String? = nil) async throws -> PrayerTimesResponse {
        var params = ["city": city]
        if let district = district {
            params["district"] = district
        }
        guard let url = buildServiceURL(path: "prayer-times", parameters: params) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PrayerTimesResponse.self)
    }
    
    func fetchCurrency(type: String? = nil) async throws -> CurrencyResponse {
        var params: [String: String] = [:]
        if let type = type {
            params["type"] = type
        }
        guard let url = buildServiceURL(path: "currency", parameters: params) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: CurrencyResponse.self)
    }
    
    func fetchPharmacy(city: String = "istanbul", district: String? = nil) async throws -> PharmacyResponse {
        var params = ["city": city]
        if let district = district {
            params["district"] = district
        }
        guard let url = buildServiceURL(path: "pharmacy", parameters: params) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PharmacyResponse.self)
    }
    
    // MARK: - Standings (API v2)
    // Path değişikliği: /services/standings → /services/standing (tekil)
    // Leagues ayrı endpoint'e taşındı: /services/standing/leagues

    func fetchStandings(league: String = "super-lig", season: String? = nil) async throws -> StandingsResponse {
        // API'de season parametresi zorunlu — verilmediyse mevcut futbol sezonu (Türkiye).
        let resolvedSeason = season ?? Self.currentFootballSeason()
        let params = ["league": league, "season": resolvedSeason]
        guard let url = buildServiceURL(path: "standing", parameters: params) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: StandingsResponse.self)
    }

    func fetchAvailableLeagues() async throws -> LeaguesListResponse {
        guard let url = buildServiceURL(path: "standing/leagues", parameters: [:]) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: LeaguesListResponse.self)
    }

    // MARK: - Fixtures (API v2)

    func fetchFixture(league: String, season: String? = nil, week: Int? = nil, team: String? = nil) async throws -> FixtureResponse {
        // Türkiye futbol sezonu Ağustos'ta başlar; API "season" = sezonun BAŞLANGIÇ yılı.
        // Örn. 2026 Mayıs → 2025/26 sezonu → season=2025.
        let resolvedSeason = season ?? Self.currentFootballSeason()
        var params = ["league": league, "season": resolvedSeason]
        if let week = week { params["week"] = "\(week)" }
        if let team = team { params["team"] = team }
        guard let url = buildServiceURL(path: "fixture", parameters: params) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: FixtureResponse.self)
    }

    private static func currentFootballSeason() -> String {
        let now = Date()
        let cal = Calendar.current
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)
        // Ağustos'tan önceyse (1-7) önceki yıl sezonu hâlâ aktif
        return month < 8 ? String(year - 1) : String(year)
    }

    func fetchFixtureLeagues() async throws -> LeaguesListResponse {
        guard let url = buildServiceURL(path: "fixture/leagues", parameters: [:]) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: LeaguesListResponse.self)
    }

    // MARK: - Earthquake (yeni)

    func fetchLastEarthquakes() async throws -> EarthquakeResponse {
        guard let url = buildServiceURL(path: "earthquake/last", parameters: [:]) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: EarthquakeResponse.self)
    }
    
    // MARK: - Settings / Mobileapp

    func fetchSettings() async throws -> SettingsResponse {
        guard let url = buildURL(endpoint: "settings") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: SettingsResponse.self)
    }

    /// GET /api/v2/about — Künye / hakkımızda
    func fetchAbout() async throws -> AboutResponse {
        guard let url = buildURL(endpoint: "about") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: AboutResponse.self)
    }

    /// GET /api/v2/banners/{key} — Server-driven banner görseli
    func fetchBanner(key: String) async throws -> BannerResponse {
        guard let url = buildURL(endpoint: "banners/\(key)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: BannerResponse.self)
    }

    // MARK: - Pages (KVKK, Hakkımızda, Gizlilik vs.)

    func fetchPages() async throws -> PageListResponse {
        guard let url = buildURL(endpoint: "pages") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PageListResponse.self)
    }

    func fetchPage(id: Int) async throws -> PageDetailResponse {
        guard let url = buildURL(endpoint: "pages/\(id)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PageDetailResponse.self)
    }

    // MARK: - Contact (POST iletişim formu)

    /// POST /api/v2/contact — throttle:50/dakika
    func sendContactMessage(request: ContactRequest) async throws -> ContactResponse {
        return try await performPOST(
            endpoint: "contact",
            body: request,
            responseType: ContactResponse.self
        )
    }

    // MARK: - Adverts (server-driven custom reklamlar — AdMob'a ek)

    func fetchAdverts(page: Int = 1, perPage: Int = 20) async throws -> AdvertListResponse {
        guard let base = buildURL(endpoint: "adverts"),
              let url = appendQueryItems([
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "per_page", value: "\(perPage)")
              ], to: base) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: AdvertListResponse.self)
    }

    func fetchAdvert(id: Int) async throws -> AdvertDetailResponse {
        guard let url = buildURL(endpoint: "adverts/\(id)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: AdvertDetailResponse.self)
    }

    // MARK: - Posts (yeni endpoint'ler)

    /// GET /api/v2/posts/story — Instagram-vari hikaye içerikleri
    func fetchStoryPosts() async throws -> StoryResponse {
        guard let url = buildURL(endpoint: "posts/story") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: StoryResponse.self)
    }

    /// "Günün Manşeti" — yalnızca eski `/_api/?daily_headline` (v1, token'sız) ucunda var;
    /// v2 karşılığı yok. Düz dizi (`[{id,title,resim,...}]`) döner.
    func fetchDailyHeadline() async throws -> [DailyHeadlineItem] {
        guard let url = URL(string: "\(config.baseURL)/_api/?daily_headline") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("YeniHaberler-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await urlSession.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([DailyHeadlineItem].self, from: data)
    }

    /// GET /api/v2/posts/fives — karışık post + article listesi
    func fetchPostsFives(limit: Int = 10) async throws -> FivesResponse {
        guard let base = buildURL(endpoint: "posts/fives"),
              let url = appendQueryItems([
                URLQueryItem(name: "limit", value: "\(limit)")
              ], to: base) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: FivesResponse.self)
    }

    // MARK: - Articles (yeni endpoint'ler)

    /// GET /api/v2/articles/fives
    func fetchArticlesFives(limit: Int = 10) async throws -> ArticleResponse {
        guard let base = buildURL(endpoint: "articles/fives"),
              let url = appendQueryItems([
                URLQueryItem(name: "limit", value: "\(limit)")
              ], to: base) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: ArticleResponse.self)
    }

    /// GET /api/v2/articles/citations — alıntı yazarların makaleleri
    func fetchArticlesCitations(limit: Int = 10) async throws -> ArticleResponse {
        guard let base = buildURL(endpoint: "articles/citations"),
              let url = appendQueryItems([
                URLQueryItem(name: "limit", value: "\(limit)")
              ], to: base) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: ArticleResponse.self)
    }

    // MARK: - Biography / Interview Related (yeni)

    /// GET /api/v2/biographies/{id}/related
    func fetchBiographyRelated(id: Int, limit: Int = 4) async throws -> BiographyResponse {
        guard let base = buildURL(endpoint: "biographies/\(id)/related"),
              let url = appendQueryItems([
                URLQueryItem(name: "limit", value: "\(limit)")
              ], to: base) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: BiographyResponse.self)
    }

    /// GET /api/v2/interviews/{id}/related
    func fetchInterviewRelated(id: Int, limit: Int = 4) async throws -> InterviewResponse {
        guard let base = buildURL(endpoint: "interviews/\(id)/related"),
              let url = appendQueryItems([
                URLQueryItem(name: "limit", value: "\(limit)")
              ], to: base) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: InterviewResponse.self)
    }
    
    // MARK: - Authors
    
    func fetchAuthors(page: Int = 1, perPage: Int = 12, search: String? = nil) async throws -> AuthorResponse {
        var components = URLComponents(string: "\(config.baseURL)/api/v2/authors")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]
        
        if let search = search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: AuthorResponse.self)
    }
    
    func fetchAuthorDetail(id: Int) async throws -> AuthorDetailResponse {
        guard let url = buildURL(endpoint: "authors/\(id)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: AuthorDetailResponse.self)
    }
    
    func fetchAuthorArticles(authorId: Int, page: Int = 1, limit: Int = 10) async throws -> AuthorArticlesResponse {
        var components = URLComponents(string: "\(config.baseURL)/api/v2/authors/\(authorId)/articles")
        components?.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: AuthorArticlesResponse.self)
    }
    
    // MARK: - Articles
    
    func fetchArticleDetail(id: Int) async throws -> ArticleDetailResponse {
        guard let url = buildURL(endpoint: "articles/\(id)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: ArticleDetailResponse.self)
    }
    
    // MARK: - Biographies
    
    func fetchBiographies(page: Int = 1, perPage: Int = 12, search: String? = nil) async throws -> BiographyResponse {
        var components = URLComponents(string: "\(config.baseURL)/api/v2/biographies")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]
        
        if let search = search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: BiographyResponse.self)
    }
    
    func fetchBiographyDetail(id: Int) async throws -> BiographyDetailResponse {
        guard let url = buildURL(endpoint: "biographies/\(id)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: BiographyDetailResponse.self)
    }
    
    func fetchLatestBiographies(limit: Int? = nil) async throws -> BiographyResponse {
        let endpoint = "biographies?per_page=\(limit ?? 12)"
        var components = URLComponents(string: "\(config.baseURL)/api/v2/\(endpoint)")
        components?.queryItems = [
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: BiographyResponse.self)
    }
    
    // MARK: - Interviews
    
    func fetchInterviews(page: Int = 1, perPage: Int = 12, search: String? = nil) async throws -> InterviewResponse {
        var components = URLComponents(string: "\(config.baseURL)/api/v2/interviews")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]
        
        if let search = search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: InterviewResponse.self)
    }
    
    func fetchInterviewDetail(id: Int) async throws -> InterviewDetailResponse {
        guard let url = buildURL(endpoint: "interviews/\(id)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: InterviewDetailResponse.self)
    }
    
    func fetchLatestInterviews(limit: Int? = nil) async throws -> InterviewResponse {
        let endpoint = "interviews?per_page=\(limit ?? 12)"
        var components = URLComponents(string: "\(config.baseURL)/api/v2/\(endpoint)")
        components?.queryItems = [
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: InterviewResponse.self)
    }
    
    // MARK: - POST Helper (Bearer auth aware)

    /// Generic POST request — Authorization header + JSON body + decode.
    private func performPOST<Body: Encodable, T: Decodable>(
        endpoint: String,
        body: Body,
        responseType: T.Type
    ) async throws -> T {
        guard let url = buildURL(endpoint: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("YeniHaberler-iOS/1.0", forHTTPHeaderField: "User-Agent")

        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        request.timeoutInterval = 30.0

        let (data, response) = try await urlSession.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            AppLogger.api.error("POST \(endpoint, privacy: .public) failed — status: \(httpResponse.statusCode, privacy: .public)")
            // Sunucu hata mesajı varsa onu kullan
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["message"] as? String {
                throw NSError(domain: "APIService", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw NSError(domain: "APIService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Comments (API v2)

    /// GET /api/v2/comments?reference_id={id}&reference_type={type}&per_page={n}&page={n}
    /// reference_type: "post", "gallery", "video", "article", "biography", "interview"
    func fetchComments(referenceId: Int, referenceType: String, page: Int = 1, perPage: Int = 10) async throws -> CommentResponse {
        guard let base = buildURL(endpoint: "comments"),
              let url = appendQueryItems([
                URLQueryItem(name: "reference_id", value: "\(referenceId)"),
                URLQueryItem(name: "reference_type", value: referenceType),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "per_page", value: "\(perPage)")
              ], to: base) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: CommentResponse.self)
    }

    /// GET /api/v2/comments/count?reference_id={id}&reference_type={type}
    func getCommentCount(referenceId: Int, referenceType: String) async throws -> CommentCountResponse {
        guard let base = buildURL(endpoint: "comments/count"),
              let url = appendQueryItems([
                URLQueryItem(name: "reference_id", value: "\(referenceId)"),
                URLQueryItem(name: "reference_type", value: referenceType)
              ], to: base) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: CommentCountResponse.self)
    }

    /// POST /api/v2/comments
    /// Body: { name, body, reference_id, reference_type, parent_id? }
    /// parent_id ile reply oluşturulabilir.
    func addComment(request: AddCommentRequest) async throws -> AddCommentResponse {
        return try await performPOST(
            endpoint: "comments",
            body: request,
            responseType: AddCommentResponse.self
        )
    }

    /// POST /api/v2/comments/{id}/like
    /// Body: { "field": "like" | "dislike" }
    /// Server IP başına günde tek oy kabul eder, çift istek 422 hata.
    func likeComment(commentId: Int, field: String) async throws -> LikeCommentResponse {
        return try await performPOST(
            endpoint: "comments/\(commentId)/like",
            body: LikeCommentRequest(field: field),
            responseType: LikeCommentResponse.self
        )
    }
}

