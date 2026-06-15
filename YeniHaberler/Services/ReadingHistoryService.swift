import Foundation
import Combine

// MARK: - History Item
struct HistoryItem: Codable, Identifiable, Equatable {
    let id: Int
    let type: ItemType
    let title: String
    let imageURL: String
    let categoryName: String?
    let authorName: String?
    let readAt: Date

    enum ItemType: String, Codable {
        case post, video, gallery, article, biography, interview
    }
}

// MARK: - Reading History Service
@MainActor
final class ReadingHistoryService: ObservableObject {
    static let shared = ReadingHistoryService()

    private let storageKey = "readingHistory.v1"
    private let maxItems = 200

    @Published private(set) var items: [HistoryItem] = []

    private init() {
        load()
    }

    // MARK: - Public API

    func record(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id && $0.type == item.type }
        items.insert(item, at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
        persist()

        // İçerik görüntüleme analytics — dedup AnalyticsService içinde 2sn pencere ile.
        AnalyticsService.shared.logContentView(
            type: item.type.rawValue,
            id: item.id,
            category: item.categoryName
        )
    }

    func recordPost(_ post: Post) {
        let item = HistoryItem(
            id: post.id, type: .post,
            title: post.name,
            imageURL: post.image.cropped.medium,
            categoryName: post.categories.values.first,
            authorName: post.author?.name,
            readAt: Date()
        )
        record(item)
    }

    func recordPostDetail(_ post: PostDetail) {
        let item = HistoryItem(
            id: post.id, type: .post,
            title: post.name,
            imageURL: post.image.cropped.medium,
            categoryName: post.categories.values.first,
            authorName: post.author?.name,
            readAt: Date()
        )
        record(item)
    }

    func recordVideo(id: Int, title: String, imageURL: String, category: String?) {
        let item = HistoryItem(
            id: id, type: .video,
            title: title, imageURL: imageURL,
            categoryName: category, authorName: nil,
            readAt: Date()
        )
        record(item)
    }

    func recordGallery(id: Int, title: String, imageURL: String, category: String?) {
        let item = HistoryItem(
            id: id, type: .gallery,
            title: title, imageURL: imageURL,
            categoryName: category, authorName: nil,
            readAt: Date()
        )
        record(item)
    }

    func clearAll() {
        items.removeAll()
        persist()
    }

    func remove(id: Int, type: HistoryItem.ItemType) {
        items.removeAll { $0.id == id && $0.type == type }
        persist()
    }

    // MARK: - Storage

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            items = try JSONDecoder().decode([HistoryItem].self, from: data)
        } catch {
            items = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // sessizce yut
        }
    }
}
