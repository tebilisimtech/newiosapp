import Foundation

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
    
    private func buildURL(endpoint: String) -> URL? {
        let urlString = "\(config.baseURL)/api/v2/\(endpoint)?apiKey=\(config.apiKey)"
        return URL(string: urlString)
    }
    
    private func performRequest<T: Decodable>(url: URL, responseType: T.Type, retryCount: Int = 3, quickFail: Bool = false) async throws -> T {
        var lastError: Error?
        
        // Retry mekanizması - 500 hataları için
        for attempt in 0..<retryCount {
            // URLRequest oluştur ve header'ları ekle
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("YozgatHakimiyet-iOS/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "X-Requested-With")
            
            // Timeout ayarları
            request.timeoutInterval = 30.0
            
            do {
                let (data, response) = try await urlSession.data(for: request)
                
                // HTTP status kontrolü
                if let httpResponse = response as? HTTPURLResponse {
                    // 500 hatası için retry (quickFail modunda retry yapma)
                    if httpResponse.statusCode == 500 && attempt < retryCount - 1 && !quickFail {
                        let delay = Double(attempt + 1) * 1.0 // 1s, 2s, 3s delay
                        if attempt == 0 {
                            print("⚠️ API Server Error (500) - Retrying (\(retryCount) attempts)...")
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
                        
                        // 500 hatası için daha detaylı log
                        if httpResponse.statusCode == 500 {
                            print("⚠️ API Server Error (500) - URL: \(url.absoluteString)")
                            if !responseString.isEmpty {
                                print("⚠️ Response: \(responseString.prefix(500))")
                            }
                        }
                        
                        if responseString.trimmingCharacters(in: .whitespaces).hasPrefix("<") || isHTML {
                            print("⚠️ API Error - HTML response received. Status: \(httpResponse.statusCode), URL: \(url.absoluteString)")
                            // 500 hatası için daha açıklayıcı mesaj
                            if httpResponse.statusCode == 500 {
                                lastError = NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Sunucu hatası (500). Lütfen daha sonra tekrar deneyin."])
                                if attempt < retryCount - 1 && !quickFail {
                                    continue
                                }
                                throw lastError!
                            }
                            throw NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned HTML instead of JSON"])
                        }
                        
                        // JSON error response kontrolü
                        if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let message = errorJson["message"] as? String {
                                print("⚠️ API Error - Status: \(httpResponse.statusCode), Message: \(message)")
                            }
                        } else if !responseString.isEmpty {
                            print("⚠️ API Error - Status: \(httpResponse.statusCode), Response: \(responseString.prefix(300))")
                        }
                        
                        // 500 hatası için özel mesaj
                        if httpResponse.statusCode == 500 {
                            lastError = NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Sunucu hatası (500). Lütfen daha sonra tekrar deneyin."])
                            if attempt < retryCount - 1 && !quickFail {
                                continue
                            }
                            throw lastError!
                        }
                        
                        throw NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                    }
                }
                
                // JSON decode
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Decoding Error - Response: \(jsonString.prefix(500))")
                    }
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
                        #if DEBUG
                        print("⚠️ Network Error (\(urlError.code.rawValue)) - Attempt \(attempt + 1)/\(retryCount) - Retrying in \(delay)s...")
                        #endif
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                }
                
                throw error
            }
        }
        
        // Tüm denemeler başarısız oldu
        throw lastError ?? NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request failed after \(retryCount) attempts"])
    }
    
    // MARK: - Posts
    
    func fetchPosts() async throws -> PostResponse {
        guard let url = buildURL(endpoint: "posts") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    func fetchHeadlines() async throws -> PostResponse {
        guard let url = buildURL(endpoint: "posts/headlines") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    func fetchTopHeadlines() async throws -> PostResponse {
        guard let url = buildURL(endpoint: "posts/topheadlines") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    func fetchBreakingNews() async throws -> PostResponse {
        guard let url = buildURL(endpoint: "posts/breaking") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    func fetchLatestPosts(limit: Int? = nil) async throws -> PostResponse {
        let endpoint = limit != nil ? "posts/latest/\(limit!)" : "posts/latest"
        guard let url = buildURL(endpoint: endpoint) else {
            throw URLError(.badURL)
        }
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
            URLQueryItem(name: "apiKey", value: config.apiKey),
            URLQueryItem(name: "category_id", value: categoryId)
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    func searchPosts(query: String) async throws -> PostResponse {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = buildURL(endpoint: "posts/search/\(encodedQuery)") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: PostResponse.self)
    }
    
    // MARK: - Galleries
    
    func fetchGalleries() async throws -> GalleryResponse {
        guard let url = buildURL(endpoint: "galleries") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: GalleryResponse.self)
    }
    
    func fetchLatestGalleries(limit: Int? = nil) async throws -> GalleryResponse {
        let endpoint = limit != nil ? "galleries/latest/\(limit!)" : "galleries/latest"
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
    
    func fetchVideos() async throws -> VideoResponse {
        guard let url = buildURL(endpoint: "videos") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: VideoResponse.self)
    }
    
    func fetchLatestVideos(limit: Int? = nil) async throws -> VideoResponse {
        let endpoint = limit != nil ? "videos/latest/\(limit!)" : "videos/latest"
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
        queryItems.append(URLQueryItem(name: "apiKey", value: Config.shared.apiKey))
        
        components?.queryItems = queryItems
        return components?.url
    }
    
    func fetchWeather(city: String = "istanbul") async throws -> WeatherResponse {
        guard let url = buildServiceURL(path: "weather", parameters: ["city": city]) else {
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
    
    func fetchStandings(league: String = "super-lig") async throws -> StandingsResponse {
        let params = ["league": league]
        guard let url = buildServiceURL(path: "standings", parameters: params) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: StandingsResponse.self)
    }
    
    func fetchAvailableLeagues() async throws -> LeaguesListResponse {
        guard let url = buildServiceURL(path: "standings", parameters: [:]) else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: LeaguesListResponse.self)
    }
    
    // MARK: - Settings
    
    func fetchSettings() async throws -> SettingsResponse {
        guard let url = buildURL(endpoint: "settings") else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: SettingsResponse.self)
    }
    
    // MARK: - Authors
    
    func fetchAuthors(page: Int = 1, perPage: Int = 12, search: String? = nil) async throws -> AuthorResponse {
        var components = URLComponents(string: "\(config.baseURL)/api/v2/authors")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "apiKey", value: config.apiKey),
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
            URLQueryItem(name: "apiKey", value: config.apiKey),
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
    
    // MARK: - Comments
    
    /// Yorumları listele
    func fetchComments(referenceId: Int, referenceType: String, page: Int = 1, perPage: Int = 10) async throws -> CommentResponse {
        var components = URLComponents(string: "\(config.baseURL)/api/v2/comments")
        
        // reference_type'ı content_type formatına çevir (article -> Article, post -> Post, etc.)
        let contentType = referenceType.prefix(1).uppercased() + referenceType.dropFirst()
        
        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: config.apiKey),
            URLQueryItem(name: "reference_id", value: "\(referenceId)"),
            URLQueryItem(name: "reference_type", value: referenceType),
            URLQueryItem(name: "content_type", value: contentType), // API hem reference_type hem content_type bekliyor olabilir
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: CommentResponse.self)
    }
    
    /// Yorum sayısını al
    func getCommentCount(referenceId: Int, referenceType: String) async throws -> CommentCountResponse {
        var components = URLComponents(string: "\(config.baseURL)/api/v2/comments/count")
        
        // reference_type'ı content_type formatına çevir
        let contentType = referenceType.prefix(1).uppercased() + referenceType.dropFirst()
        
        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: config.apiKey),
            URLQueryItem(name: "reference_id", value: "\(referenceId)"),
            URLQueryItem(name: "reference_type", value: referenceType),
            URLQueryItem(name: "content_type", value: contentType) // API hem reference_type hem content_type bekliyor olabilir
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return try await performRequest(url: url, responseType: CommentCountResponse.self)
    }
    
    /// Yeni yorum ekle
    func addComment(request: AddCommentRequest) async throws -> AddCommentResponse {
        var components = URLComponents(string: "\(config.baseURL)/api/v2/comments")
        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: config.apiKey)
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("API Error - Add Comment - Status: \(httpResponse.statusCode), Response: \(responseString.prefix(300))")
            throw NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }
        
        return try JSONDecoder().decode(AddCommentResponse.self, from: data)
    }
    
    /// Yorum beğen/beğenme
    func likeComment(commentId: Int, field: String) async throws -> LikeCommentResponse {
        var components = URLComponents(string: "\(config.baseURL)/api/v2/comments/\(commentId)/like")
        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: config.apiKey)
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = LikeCommentRequest(field: field)
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("API Error - Like Comment - Status: \(httpResponse.statusCode), Response: \(responseString.prefix(300))")
            throw NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }
        
        return try JSONDecoder().decode(LikeCommentResponse.self, from: data)
    }
}

