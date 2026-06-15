import Foundation

// MARK: - Legacy (_api v1) Models
//
// Bazı modüller (ör. "Günün Manşeti" = daily_headline) yalnızca eski `/_api/?param`
// (v1, token'sız) ucunda var; v2'de karşılığı yok. Bu uçlar düz dizi döner ve farklı
// alan adları kullanır (title, resim). Burada hafif modellerle map'leriz.

struct DailyHeadlineItem: Decodable, Identifiable {
    let id: Int
    let title: String
    let resim: String?
    let originalImage: String?

    enum CodingKeys: String, CodingKey {
        case id, title, resim
        case originalImage = "original_image"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        resim = try? c.decodeIfPresent(String.self, forKey: .resim)
        originalImage = try? c.decodeIfPresent(String.self, forKey: .originalImage)
    }

    /// Kart için en iyi görsel.
    var imageURL: String { (resim?.isEmpty == false ? resim : originalImage) ?? "" }
}
