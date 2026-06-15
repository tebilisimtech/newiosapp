import Foundation

// MARK: - Article Response (List)
struct ArticleResponse: Codable {
    let data: [Article]
    let error: Bool
    let message: String?
}

// MARK: - Article Detail Response (Single)
struct ArticleDetailResponse: Codable {
    let data: ArticleDetail
    let error: Bool
    let message: String?
}

// MARK: - Article Model (List item)
struct Article: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String?
    let description: String?
    let image: PostImage?
    let author: Author?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, image, author
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        author = try container.decodeIfPresent(Author.self, forKey: .author)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        
        // image hem string hem de PostImage objesi olabilir
        if let imageString = try? container.decode(String.self, forKey: .image) {
            image = PostImage(
                original: imageString,
                cropped: CroppedImages(
                    thumb: imageString,
                    medium: imageString,
                    large: imageString,
                    square: imageString,
                    vertical: imageString,
                    fives: imageString
                )
            )
        } else {
            image = try? container.decode(PostImage.self, forKey: .image)
        }
    }
}

// MARK: - Article Detail Model (Full content)
struct ArticleDetail: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String?
    let url: String?
    let description: String?
    let content: String
    let image: PostImage?
    let categories: [String: String]?
    let tags: [String]?
    let author: Author?
    let hit: Int?
    let createdAt: String
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, slug, url, description, content, image, categories, tags, author, hit
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        content = try container.decode(String.self, forKey: .content)
        categories = try container.decodeIfPresent([String: String].self, forKey: .categories)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        author = try container.decodeIfPresent(Author.self, forKey: .author)
        hit = try container.decodeIfPresent(Int.self, forKey: .hit)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        
        // image hem string hem de PostImage objesi olabilir
        if let imageString = try? container.decode(String.self, forKey: .image) {
            image = PostImage(
                original: imageString,
                cropped: CroppedImages(
                    thumb: imageString,
                    medium: imageString,
                    large: imageString,
                    square: imageString,
                    vertical: imageString,
                    fives: imageString
                )
            )
        } else {
            image = try? container.decode(PostImage.self, forKey: .image)
        }
    }
    
    // Default görsel URL'i
    var imageURL: String? {
        if let image = image, !image.cropped.large.isEmpty {
            return image.cropped.large
        }
        return nil // Placeholder URL yerine nil döndür
    }
}
