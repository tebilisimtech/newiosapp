import Foundation

struct GalleryResponse: Codable {
    let data: [Gallery]
    let error: Bool
    let message: String?
}

struct GalleryDetailResponse: Codable {
    let data: GalleryDetail
    let error: Bool
    let message: String?
}

struct Gallery: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let url: String?
    let description: String?
    let categories: [String: String]
    let image: PostImage
    let author: Author?
    let createdAt: String
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, slug, url, description, categories, image, author
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        categories = try container.decodeIfPresent([String: String].self, forKey: .categories) ?? [:]
        author = try container.decodeIfPresent(Author.self, forKey: .author)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        
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
            image = try container.decode(PostImage.self, forKey: .image)
        }
    }
}

struct GalleryDetail: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let url: String
    let description: String?
    let content: String?
    let hit: Int
    let author: Author?
    let source: String?
    let reporter: String?
    let tags: [String]
    let image: PostImage
    let categories: [String: String]
    let photos: [GalleryPhoto]
    let createdAt: String
    let updatedAt: String
    // `comments` field API'de dict array olarak gelir (yorum varsa); UI'da kullanılmıyor.
    // Bkz: PostDetail.swift aynı yorum.

    enum CodingKeys: String, CodingKey {
        case id, name, slug, url, description, content, hit, author, source, reporter, tags, image, categories, photos
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GalleryPhoto: Codable, Identifiable {
    var id: String { img }
    let img: String
    let description: String?
}

