import Foundation

// MARK: - Comment Response (List)
struct CommentResponse: Codable {
    let data: [Comment]
    let error: Bool
    let message: String?
}

// MARK: - Comment Model
struct Comment: Codable, Identifiable {
    let id: Int
    let body: String
    let name: String
    let email: String?
    let referenceId: Int
    let referenceType: String
    let parentId: Int?
    let like: Int
    let dislike: Int
    let createdAt: String
    let updatedAt: String?
    let replies: [Comment]?
    
    enum CodingKeys: String, CodingKey {
        case id, body, name, email, like, dislike, replies
        case referenceId = "reference_id"
        case referenceType = "reference_type"
        case contentType = "content_type"
        case parentId = "parent_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        body = try container.decode(String.self, forKey: .body)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        // KRİTİK: Yanıtlarda (replies) `reference_id` null gelir. Zorunlu decode
        // burada patlayıp TÜM yorum listesini boşaltıyordu. null/eksik → 0 tolere et.
        referenceId = (try? container.decodeIfPresent(Int.self, forKey: .referenceId)) ?? 0
        parentId = try? container.decodeIfPresent(Int.self, forKey: .parentId)
        // Yeni oluşturulan yorumlarda `like`/`dislike` API tarafından null gönderiliyor
        // (henüz kimse oy vermemiş). decodeIfPresent + ?? 0 ile null'u tolere ediyoruz.
        like = (try? container.decodeIfPresent(Int.self, forKey: .like)) ?? 0
        dislike = (try? container.decodeIfPresent(Int.self, forKey: .dislike)) ?? 0
        createdAt = (try? container.decodeIfPresent(String.self, forKey: .createdAt)) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        replies = try container.decodeIfPresent([Comment].self, forKey: .replies)
        
        // reference_type sunucudan FQCN olarak gelir (örn. "TE\Blog\Models\Post").
        // Geriye dönük olarak `content_type` field'ı (alias) varsa onu da tolere ediyoruz.
        if let refType = try? container.decode(String.self, forKey: .referenceType) {
            referenceType = refType
        } else if let contentType = try? container.decode(String.self, forKey: .contentType),
                  let resolved = ReferenceType.resolve(contentType) {
            // Eski content_type alias'ını FQCN'e çevir ki yorum reply'ı doğru POST'lanabilsin.
            referenceType = resolved.apiValue
        } else {
            referenceType = ReferenceType.post.apiValue // Default fallback
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(body, forKey: .body)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encode(referenceId, forKey: .referenceId)
        try container.encode(referenceType, forKey: .referenceType)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encode(like, forKey: .like)
        try container.encode(dislike, forKey: .dislike)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(replies, forKey: .replies)
    }
}

// MARK: - Add Comment Request
struct AddCommentRequest: Codable {
    let body: String
    let name: String
    let referenceId: Int
    let referenceType: String
    let parentId: Int?
    
    enum CodingKeys: String, CodingKey {
        case body, name
        case referenceId = "reference_id"
        case referenceType = "reference_type"
        case parentId = "parent_id"
    }
}

// MARK: - Add Comment Response
struct AddCommentResponse: Codable {
    let data: Comment?
    let error: Bool
    let message: String?
}

// MARK: - Like Comment Request
struct LikeCommentRequest: Codable {
    let field: String // "like" veya "dislike"
}

// MARK: - Like Comment Response
struct LikeCommentResponse: Codable {
    let data: Comment?
    let error: Bool
    let message: String?
}

// MARK: - Comment Count Response
struct CommentCountResponse: Codable {
    let data: CommentCount
    let error: Bool
    let message: String?
}

struct CommentCount: Codable {
    let count: Int

    enum CodingKeys: String, CodingKey { case count }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Backend `count`'u bazen Int (4), bazen String ("4") döndürür — ikisini de tolere et.
        if let i = try? c.decode(Int.self, forKey: .count) {
            count = i
        } else if let s = try? c.decode(String.self, forKey: .count) {
            count = Int(s) ?? 0
        } else {
            count = 0
        }
    }
}
