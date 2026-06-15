import Foundation

// MARK: - Page (statik sayfalar — KVKK, Hakkımızda, Gizlilik)

struct PageListResponse: Codable {
    let data: [PageItem]
    let error: Bool
    let message: String?
}

struct PageDetailResponse: Codable {
    let data: PageItem
    let error: Bool
    let message: String?
}

struct PageItem: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String?
    let content: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try? container.decodeIfPresent(String.self, forKey: .slug)
        content = try? container.decodeIfPresent(String.self, forKey: .content)
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try? container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

// MARK: - About (Künye)

struct AboutResponse: Codable {
    let data: AboutData
    let error: Bool
    let message: String?
}

struct AboutData: Codable {
    let title: String?
    let content: String?
    let address: String?
    let phone: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case title, content, address, phone, email
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        content = try? container.decodeIfPresent(String.self, forKey: .content)
        address = try? container.decodeIfPresent(String.self, forKey: .address)
        phone = try? container.decodeIfPresent(String.self, forKey: .phone)
        email = try? container.decodeIfPresent(String.self, forKey: .email)
    }
}

// MARK: - Banner (server-driven)

struct BannerResponse: Codable {
    let data: BannerData
    let error: Bool
    let message: String?
}

struct BannerData: Codable {
    let image: String?
    let url: String?
    let title: String?
}

// MARK: - Contact (POST)

struct ContactRequest: Codable {
    let name: String
    let email: String
    let content: String
    let subject: String?
    let phone: String?
    let address: String?

    enum CodingKeys: String, CodingKey {
        case name, email, content, subject, phone, address
    }
}

struct ContactResponse: Codable {
    let error: Bool
    let message: String?
    let data: ContactResponseData?
}

struct ContactResponseData: Codable {
    let id: Int?
}

// MARK: - Adverts (custom server-driven reklamlar)

struct AdvertListResponse: Codable {
    let data: [AdvertItem]
    let error: Bool
    let message: String?
}

struct AdvertDetailResponse: Codable {
    let data: AdvertItem
    let error: Bool
    let message: String?
}

/// Reklamın atandığı kanal (placement). `id` uygulama yerleşim numarasıdır (2000–2025).
struct AdvertChannel: Codable {
    let id: Int
}

struct AdvertItem: Codable, Identifiable {
    let id: Int
    let name: String?
    let code: String?          // desktop HTML/JS kodu
    let mobileCode: String?    // mobil HTML/JS kodu (AdMob web snippet, özel HTML vb.)
    let image: String?         // desktop görseli
    let mobileImage: String?   // varsa mobil görsel
    let url: String?
    let beginAt: String?       // ISO tarih
    let endAt: String?         // ISO tarih (nil → sınırsız)
    let banner: Bool?
    let native: Bool?
    let channels: [AdvertChannel]?

    /// Mobil görsel öncelikli, yoksa desktop.
    var bestImage: String? {
        if let m = mobileImage, !m.isEmpty { return m }
        if let i = image, !i.isEmpty { return i }
        return nil
    }

    /// Render edilecek kod — mobil öncelikli, yoksa desktop. Boşsa nil.
    var snippet: String? {
        if let m = mobileCode?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty { return m }
        if let c = code?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty { return c }
        return nil
    }

    /// Kod alanına AdMob banner Unit ID'si (ca-app-pub-XXXX/YYYY) yazıldıysa onu
    /// döndürür → uygulama native AdMob banner gösterir. Aksi halde nil.
    var admobUnitId: String? {
        guard let s = snippet else { return nil }
        if let range = s.range(of: #"ca-app-pub-\d+/\d+"#, options: .regularExpression) {
            return String(s[range])
        }
        return nil
    }

    /// Bu reklamın atandığı kanal (placement) id'leri.
    var channelIds: [Int] { channels?.map { $0.id } ?? [] }

    /// Gösterilebilir içeriği var mı? (önce kod, yoksa görsel)
    var hasRenderableContent: Bool { snippet != nil || bestImage != nil }

    /// Geçerli tarih aralığında mı?
    var isActive: Bool {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let beginAt = beginAt, let begin = formatter.date(from: beginAt), begin > now {
            return false
        }
        if let endAt = endAt, let end = formatter.date(from: endAt), end < now {
            return false
        }
        return true
    }

    enum CodingKeys: String, CodingKey {
        case id, name, code, image, url, banner, native, channels
        case mobileCode = "mobile_code"
        case mobileImage = "mobile_image"
        case beginAt = "begin_at"
        case endAt = "end_at"
    }
}

// MARK: - Story Post (Instagram-vari)
// API yanıtı: { data: [{ id: String, photo: String, name: String, items: [{ id, type, src, preview, link, linkText, time }] }] }

struct StoryResponse: Codable {
    let data: [StoryGroup]
    let error: Bool
    let message: String?

    enum CodingKeys: String, CodingKey { case data, error, message }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = (try? container.decode(Bool.self, forKey: .error)) ?? false
        message = try? container.decodeIfPresent(String.self, forKey: .message)

        // API zaman zaman aynı slug ile birden fazla grup dönderiyor
        // (örn. "yozgat" 2 kez). ForEach unique ID gerektirdiğinden burada
        // tekrarlananları items'larını birleştirerek tek gruba indiriyoruz.
        let raw = (try? container.decode([StoryGroup].self, forKey: .data)) ?? []
        var ordered: [StoryGroup] = []
        for group in raw {
            if let idx = ordered.firstIndex(where: { $0.id == group.id }) {
                ordered[idx] = StoryGroup(
                    id: ordered[idx].id,
                    photo: ordered[idx].photo ?? group.photo,
                    name: ordered[idx].name,
                    items: ordered[idx].items + group.items
                )
            } else {
                ordered.append(group)
            }
        }
        data = ordered
    }
}

struct StoryGroup: Codable, Identifiable {
    let id: String
    let photo: String?
    let name: String
    let items: [StoryItem]

    enum CodingKeys: String, CodingKey {
        case id, photo, name, items
    }

    init(id: String, photo: String?, name: String, items: [StoryItem]) {
        self.id = id
        self.photo = photo
        self.name = name
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        photo = try container.decodeIfPresent(String.self, forKey: .photo)
        name = try container.decode(String.self, forKey: .name)

        // API tutarsız: items bazen [StoryItem], bazen {"1": StoryItem, "2": ...} dict
        if let array = try? container.decode([StoryItem].self, forKey: .items) {
            items = array
        } else if let dict = try? container.decode([String: StoryItem].self, forKey: .items) {
            // String key'leri Int olarak sırala — "1", "2", "10" doğru sırada olsun
            items = dict
                .sorted { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) }
                .map { $0.value }
        } else {
            items = []
        }
    }
}

struct StoryItem: Codable, Identifiable {
    let id: Int
    let type: String?
    let length: Int?
    let src: String
    let preview: String?
    let link: String?
    let linkText: String?
    let time: Int?
}

// MARK: - Fives (karışık post+article)

struct FivesResponse: Codable {
    let data: [Post]
    let error: Bool
    let message: String?
}
