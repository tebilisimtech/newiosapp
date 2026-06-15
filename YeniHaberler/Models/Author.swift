import Foundation

// MARK: - Author Response (List)
struct AuthorResponse: Codable {
    let data: [AuthorDetail]
    let error: Bool
    let message: String?
}

// MARK: - Author Detail Response (Single)
struct AuthorDetailResponse: Codable {
    let data: AuthorDetail
    let error: Bool
    let message: String?
}

// MARK: - Author Detail Model
struct AuthorDetail: Codable, Identifiable {
    let id: Int
    let name: String
    let image: PostImage?
    let slug: String?
    let url: String?
    let description: String?
    let bio: String?
    let socials: AuthorSocials?
    let lastArticle: AuthorLastArticle?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, image, slug, url, description, bio, socials
        case lastArticle = "last_article"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        socials = try? container.decodeIfPresent(AuthorSocials.self, forKey: .socials)
        lastArticle = try? container.decodeIfPresent(AuthorLastArticle.self, forKey: .lastArticle)
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)

        // image hem string hem de PostImage objesi olabilir
        if let imageString = try? container.decode(String.self, forKey: .image) {
            image = PostImage(
                original: imageString,
                cropped: CroppedImages(
                    thumb: imageString, medium: imageString, large: imageString,
                    square: imageString, vertical: imageString, fives: imageString
                )
            )
        } else {
            image = try? container.decode(PostImage.self, forKey: .image)
        }
    }

    var imageURL: String {
        if let image = image, !image.cropped.large.isEmpty {
            return image.cropped.large
        }
        return ""
    }

    /// Dairesel avatar için en uygun görsel. Yatay `large` kırpımı daireye
    /// konunca yüz kesilir; önce kare varyant, yoksa orijinal kullanılır.
    var avatarURL: String {
        guard let image = image else { return "" }
        if !image.cropped.square.isEmpty { return image.cropped.square }
        if !image.original.isEmpty { return image.original }
        return image.cropped.large
    }
}

// MARK: - Author Socials
struct AuthorSocials: Codable {
    let facebook: String?
    let twitter: String?
    let instagram: String?
}

// MARK: - Author Last Article
struct AuthorLastArticle: Codable {
    let id: Int
    let name: String
    let url: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, url
        case createdAt = "created_at"
    }
}

// MARK: - Author Articles Response
struct AuthorArticlesResponse: Codable {
    let data: [AuthorArticle]
    let error: Bool
    let message: String?
}

// MARK: - Author Article (List item - id, name ve görsel)
struct AuthorArticle: Codable, Identifiable {
    let id: Int
    let name: String
    let image: PostImage?
    
    enum CodingKeys: String, CodingKey {
        case id, name, image
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // image hem string hem de PostImage objesi olabilir
        if let imageString = try? container.decode(String.self, forKey: .image) {
            // String ise, basit bir PostImage oluştur
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
    
    // Default görsel URL'i - boşsa nil döndür (placeholder kullanma)
    var imageURL: String? {
        if let image = image {
            return image.cropped.large
        }
        return nil
    }
}
