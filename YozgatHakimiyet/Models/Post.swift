import Foundation

// MARK: - Post Response (List)
struct PostResponse: Codable {
    let data: [Post]
    let error: Bool
    let message: String?
}

// MARK: - Post Detail Response (Single)
struct PostDetailResponse: Codable {
    let data: PostDetail
    let error: Bool
    let message: String?
}

// MARK: - Post Model
struct Post: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let url: String?
    let description: String?
    let categories: [String: String]
    let image: PostImage
    let headline: Headline?
    let directLink: String?
    let author: Author?
    let type: String? // Post, Video, Gallery, Article vb.
    let createdAt: String
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, slug, url, description, categories, image, headline, type
        case directLink = "direct_link"
        case author
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // slug - yoksa url'den çıkar veya name'den oluştur
        if let slugValue = try? container.decode(String.self, forKey: .slug), !slugValue.isEmpty {
            slug = slugValue
        } else if let urlValue = try? container.decodeIfPresent(String.self, forKey: .url), !urlValue.isEmpty {
            // URL'den slug çıkar (örn: /haber-slug -> haber-slug)
            slug = urlValue.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            // Name'den slug oluştur
            let nameValue = try container.decode(String.self, forKey: .name)
            slug = nameValue.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "ç", with: "c")
                .replacingOccurrences(of: "ğ", with: "g")
                .replacingOccurrences(of: "ı", with: "i")
                .replacingOccurrences(of: "ö", with: "o")
                .replacingOccurrences(of: "ş", with: "s")
                .replacingOccurrences(of: "ü", with: "u")
        }
        
        url = try container.decodeIfPresent(String.self, forKey: .url)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        directLink = try container.decodeIfPresent(String.self, forKey: .directLink)
        author = try container.decodeIfPresent(Author.self, forKey: .author)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        
        // categories - farklı formatlar olabilir
        if let categoriesDict = try? container.decodeIfPresent([String: String].self, forKey: .categories) {
            categories = categoriesDict
        } else {
            // categories yoksa boş dictionary
            categories = [:]
        }
        
        // createdAt - optional yapıldı, yoksa boş string
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        
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
        } else if let imageObject = try? container.decode(PostImage.self, forKey: .image) {
            image = imageObject
        } else {
            // Hiç image yoksa placeholder
            image = PostImage(
                original: "",
                cropped: CroppedImages(
                    thumb: "",
                    medium: "",
                    large: "",
                    square: "",
                    vertical: "",
                    fives: ""
                )
            )
        }
        
        // headline optional
        headline = try? container.decode(Headline.self, forKey: .headline)
    }
}

// MARK: - Post Image
struct PostImage: Codable {
    let original: String
    let cropped: CroppedImages
}

struct CroppedImages: Codable {
    let thumb: String
    let medium: String
    let large: String
    let square: String
    let vertical: String
    let fives: String
}

// MARK: - Headline
struct Headline: Codable {
    let name: String
    let image: HeadlineImage?
    
    enum CodingKeys: String, CodingKey {
        case name, image
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        
        // image hem PostImage hem de String olabilir
        if let imageString = try? container.decode(String.self, forKey: .image) {
            image = HeadlineImage.string(imageString)
        } else if let imageObject = try? container.decode(PostImage.self, forKey: .image) {
            image = HeadlineImage.object(imageObject)
        } else {
            image = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        // Encoding için gerekirse eklenebilir
    }
}

enum HeadlineImage: Codable {
    case string(String)
    case object(PostImage)
    
    var postImage: PostImage? {
        switch self {
        case .object(let img):
            return img
        case .string:
            return nil
        }
    }
}

// MARK: - Author
struct Author: Codable {
    let id: Int?
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // id null olabilir, o yüzle optional
        id = try? container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
}

// MARK: - Post Detail Model (with content)
struct PostDetail: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let url: String
    let description: String?
    let categories: [String: String]
    let content: String
    let image: PostImage
    let headline: Headline?
    let tags: [String]
    let position: [String]
    let hit: Int
    let additional: AdditionalInfo?
    let directLink: String?
    let agency: String?
    let author: Author?
    let embed: String?
    let video: String?
    let source: String?
    let reporter: String?
    let bikId: String?
    let nextId: Int?
    let previousId: Int?
    let createdAt: String
    let updatedAt: String
    let comments: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, name, slug, url, description, categories, content, image, headline, tags, position, hit, additional
        case directLink = "direct_link"
        case agency, author, embed, video, source, reporter
        case bikId = "bik_id"
        case nextId = "next_id"
        case previousId = "previous_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case comments
    }
}

// MARK: - Additional Info
struct AdditionalInfo: Codable {
    let commentsOff: Int?
    let hideHeadline: Int?
    let hideHeadlineCategory: Int?
    
    enum CodingKeys: String, CodingKey {
        case commentsOff = "comments_off"
        case hideHeadline = "hide_headline"
        case hideHeadlineCategory = "hide_headline_category"
    }
}

