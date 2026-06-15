import Foundation
import CoreData
import os

// MARK: - CDPost ⇄ Domain mapping
//
// Post ve PostDetail kendi `init(from decoder:)`'larını barındırdığından
// memberwise init mevcut değil. Mapper, CoreData satırından bir JSON sözlüğü
// üretip Post/PostDetail'in JSONDecoder yolu üzerinden yeniden inşa eder.
// Ek yük: row başına bir JSONEncode/Decode; pratik fetch boyutlarında ihmal
// edilebilir, karşılığında modelleri değiştirmeden offline persistence sağlar.

extension CDPost {

    // MARK: Domain → Entity (apply)

    /// List response'tan gelen Post entity'ye yazılır.
    /// Detay alanlarına (contentHTML, hit, tags…) dokunmaz; `isFullyLoaded`
    /// önceden true ise korunur. `isFavorite`/`isRead` her zaman korunur.
    func applyList(post: Post, fetchedAt: Date) {
        self.id = Int64(post.id)
        self.name = post.name
        self.slug = post.slug
        self.urlString = post.url
        self.descriptionText = post.description
        self.type = post.type
        self.createdAt = post.createdAt
        self.updatedAt = post.updatedAt

        self.imageOriginal = post.image.original
        self.imageThumb = post.image.cropped.thumb
        self.imageMedium = post.image.cropped.medium
        self.imageLarge = post.image.cropped.large
        self.imageSquare = post.image.cropped.square

        self.headlineName = post.headline?.name
        self.headlineImage = Self.extractHeadlineImage(post.headline?.image)

        self.categoriesJSON = Self.encodeStringDict(post.categories)

        self.lastFetchedAt = fetchedAt
        // detailFetchedAt, isFullyLoaded, isFavorite, isRead: korunur
    }

    /// PostDetail response'tan gelen alanlar entity'ye yazılır.
    /// `isFullyLoaded = true` yapar. Favori/okundu bayrakları korunur.
    func applyDetail(detail: PostDetail, fetchedAt: Date) {
        self.id = Int64(detail.id)
        self.name = detail.name
        self.slug = detail.slug
        self.urlString = detail.url
        self.descriptionText = detail.description
        self.contentHTML = detail.content
        self.type = "post"
        self.hit = Int32(detail.hit)
        self.createdAt = detail.createdAt
        self.updatedAt = detail.updatedAt

        self.imageOriginal = detail.image.original
        self.imageThumb = detail.image.cropped.thumb
        self.imageMedium = detail.image.cropped.medium
        self.imageLarge = detail.image.cropped.large
        self.imageSquare = detail.image.cropped.square

        self.headlineName = detail.headline?.name
        self.headlineImage = Self.extractHeadlineImage(detail.headline?.image)

        self.categoriesJSON = Self.encodeStringDict(detail.categories)
        self.tagsJSON = Self.encodeStringArray(detail.tags)
        self.positionsJSON = Self.encodeStringArray(detail.position)

        self.source = detail.source
        self.reporter = detail.reporter
        self.agency = detail.agency
        self.embed = detail.embed
        self.videoURL = detail.video
        self.bikId = detail.bikId
        self.nextId = Int64(detail.nextId ?? 0)
        self.previousId = Int64(detail.previousId ?? 0)

        self.lastFetchedAt = fetchedAt
        self.detailFetchedAt = fetchedAt
        self.isFullyLoaded = true
    }

    // MARK: Entity → Domain

    /// CoreData satırını Post domain modeline çevirir. JSON yapısı tekrar
    /// inşa edilip Post'un standart decoder'ından geçirilir.
    func toDomain() -> Post? {
        let dict = listJSONDict()
        return Self.decode(Post.self, from: dict)
    }

    /// Sadece `isFullyLoaded == true` ise PostDetail döndürür; aksi halde nil.
    func toDetailDomain() -> PostDetail? {
        guard isFullyLoaded else { return nil }
        let dict = detailJSONDict()
        return Self.decode(PostDetail.self, from: dict)
    }

    // MARK: - JSON sözlük üretimi

    private func listJSONDict() -> [String: Any] {
        var dict: [String: Any] = [
            "id": Int(id),
            "name": name ?? "",
            "image": imageDict()
        ]
        if let slug = slug { dict["slug"] = slug }
        if let url = urlString { dict["url"] = url }
        if let desc = descriptionText { dict["description"] = desc }
        if let type = type { dict["type"] = type }
        if let created = createdAt { dict["created_at"] = created }
        if let updated = updatedAt { dict["updated_at"] = updated }

        if let cats = Self.decodeStringDict(categoriesJSON) {
            dict["categories"] = cats
        }
        if let headline = headlineDict() {
            dict["headline"] = headline
        }
        return dict
    }

    private func detailJSONDict() -> [String: Any] {
        var dict = listJSONDict()
        dict["content"] = contentHTML ?? ""
        dict["hit"] = Int(hit)
        dict["tags"] = Self.decodeStringArray(tagsJSON) ?? []
        dict["position"] = Self.decodeStringArray(positionsJSON) ?? []
        dict["comments"] = [String]()
        // URL zorunlu PostDetail'da; eksikse boş string
        if dict["url"] == nil { dict["url"] = "" }
        if let source = source { dict["source"] = source }
        if let reporter = reporter { dict["reporter"] = reporter }
        if let agency = agency { dict["agency"] = agency }
        if let embed = embed { dict["embed"] = embed }
        if let video = videoURL { dict["video"] = video }
        if let bik = bikId { dict["bik_id"] = bik }
        if nextId > 0 { dict["next_id"] = Int(nextId) }
        if previousId > 0 { dict["previous_id"] = Int(previousId) }
        return dict
    }

    private func imageDict() -> [String: Any] {
        let med = imageMedium ?? ""
        let lrg = imageLarge ?? med
        return [
            "original": imageOriginal ?? med,
            "cropped": [
                "thumb": imageThumb ?? med,
                "medium": med,
                "big": lrg,
                "square": imageSquare ?? med,
                "vertical": med,
                "fives": lrg
            ]
        ]
    }

    private func headlineDict() -> [String: Any]? {
        guard let name = headlineName else { return nil }
        var dict: [String: Any] = ["name": name]
        if let img = headlineImage {
            dict["image"] = img   // string varyantı; Headline decoder string'i kabul eder
        }
        return dict
    }

    // MARK: - JSON encode/decode yardımcıları

    private static func encodeStringDict(_ dict: [String: String]) -> String? {
        guard !dict.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private static func decodeStringDict(_ json: String?) -> [String: String]? {
        guard let json = json, let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return nil }
        return dict
    }

    private static func encodeStringArray(_ array: [String]) -> String? {
        guard !array.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: array),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private static func decodeStringArray(_ json: String?) -> [String]? {
        guard let json = json, let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String]
        else { return nil }
        return arr
    }

    /// HeadlineImage (string veya PostImage) → kayda yazılacak string url.
    private static func extractHeadlineImage(_ image: HeadlineImage?) -> String? {
        switch image {
        case .some(.string(let url)): return url
        case .some(.object(let img)): return img.cropped.medium
        case .none: return nil
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any]) -> T? {
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            AppLogger.app.error("CDPost decode \(String(describing: type), privacy: .public) — \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
