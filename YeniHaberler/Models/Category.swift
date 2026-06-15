import Foundation

// MARK: - Category Response
struct CategoryResponse: Decodable {
    let data: [Category]
    let error: Bool?
    let message: String?
}

struct CategoryDetailResponse: Decodable {
    let data: Category
    let error: Bool?
    let message: String?
}

// MARK: - Category Model
// Gerçek API: id, parent_id (null veya Int), name, slug, url, description, image (PostImage)
struct Category: Decodable, Identifiable {
    let id: Int
    let parentId: Int?
    let name: String
    let slug: String?
    let url: String?
    let description: String?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case name, slug, url, description, image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        parentId = try? container.decodeIfPresent(Int.self, forKey: .parentId)
        slug = try? container.decodeIfPresent(String.self, forKey: .slug)
        url = try? container.decodeIfPresent(String.self, forKey: .url)
        description = try? container.decodeIfPresent(String.self, forKey: .description)

        // image hem PostImage object hem de String olabilir
        if let imageString = try? container.decode(String.self, forKey: .image) {
            imageURL = imageString
        } else if let imageObject = try? container.decode(PostImage.self, forKey: .image) {
            imageURL = imageObject.cropped.medium.isEmpty
                ? imageObject.original
                : imageObject.cropped.medium
        } else if let imageDict = try? container.decode([String: String].self, forKey: .image) {
            imageURL = imageDict["medium"] ?? imageDict["original"] ?? imageDict.values.first
        } else {
            imageURL = nil
        }
    }

    // Test/preview için
    init(id: Int, name: String, parentId: Int? = nil, slug: String? = nil,
         url: String? = nil, description: String? = nil, imageURL: String? = nil) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.slug = slug
        self.url = url
        self.description = description
        self.imageURL = imageURL
    }
}
