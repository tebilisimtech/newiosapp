import Foundation

// MARK: - Video Response (List)
struct VideoResponse: Codable {
    let data: [Video]
    let error: Bool
    let message: String?
}

// MARK: - Video Detail Response (Single)
struct VideoDetailResponse: Codable {
    let data: VideoDetail
    let error: Bool
    let message: String?
}

// MARK: - Video Model (List)
struct Video: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let description: String?
    let image: PostImage
    let headlineImage: HeadlineImage?
    let categories: [String: String]
    let createdAt: String
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, image, categories
        case headlineImage = "headline_image"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        description = try? container.decode(String.self, forKey: .description)
        image = try container.decode(PostImage.self, forKey: .image)
        categories = try container.decodeIfPresent([String: String].self, forKey: .categories) ?? [:]
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try? container.decode(String.self, forKey: .updatedAt)
        
        // headline_image optional ve her zaman parse edilemeyebilir
        headlineImage = try? container.decode(HeadlineImage.self, forKey: .headlineImage)
    }
}

// MARK: - Video Detail Model (with content and embed)
struct VideoDetail: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let url: String
    let description: String?
    let content: String?
    let image: PostImage
    let categories: [String: String]
    let embed: String?
    let mediaUrl: String?
    let hit: Int
    let author: Author?
    let source: String?
    let reporter: String?
    let tags: [String]
    let createdAt: String
    let updatedAt: String?
    // `comments` field API'de dict array olarak gelir (yorum varsa); UI'da kullanılmıyor,
    // bu yüzden decode'a dahil etmiyoruz. Bkz: PostDetail.swift aynı yorum.

    enum CodingKeys: String, CodingKey {
        case id, name, slug, url, description, content, image, categories, embed, hit, author, source, reporter, tags
        case mediaUrl = "media_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // YouTube video ID çıkarma
    var youtubeVideoId: String? {
        guard let embed = embed else { return nil }
        
        // iframe'den YouTube ID çıkar
        if let range = embed.range(of: #"youtube\.com/embed/([a-zA-Z0-9_-]+)"#, options: .regularExpression) {
            let matched = String(embed[range])
            let components = matched.components(separatedBy: "/")
            return components.last?.components(separatedBy: "?").first
        }
        
        return nil
    }
}
