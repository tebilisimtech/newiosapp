import Foundation
import Combine

// MARK: - Favorite Item
struct FavoriteItem: Codable, Identifiable, Equatable {
    let id: Int
    let type: ItemType
    let title: String
    let imageURL: String
    let categoryName: String?
    let authorName: String?
    let createdAt: String
    let savedAt: Date

    enum ItemType: String, Codable {
        case post, video, gallery
    }

    static func == (lhs: FavoriteItem, rhs: FavoriteItem) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type
    }
}

// MARK: - Favorites Service
@MainActor
final class FavoritesService: ObservableObject {
    static let shared = FavoritesService()

    private let storageKey = "favorites.v1"
    private let maxItems = 500

    @Published private(set) var items: [FavoriteItem] = []

    private init() {
        load()
    }

    // MARK: - Public API

    func contains(id: Int, type: FavoriteItem.ItemType) -> Bool {
        items.contains { $0.id == id && $0.type == type }
    }

    func add(_ item: FavoriteItem) {
        guard !contains(id: item.id, type: item.type) else { return }
        items.insert(item, at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
        persist()
    }

    func remove(id: Int, type: FavoriteItem.ItemType) {
        items.removeAll { $0.id == id && $0.type == type }
        persist()
    }

    func toggle(_ item: FavoriteItem) {
        let willAdd = !contains(id: item.id, type: item.type)
        if willAdd {
            add(item)
        } else {
            remove(id: item.id, type: item.type)
        }
        AnalyticsService.shared.logFavoriteToggle(type: item.type.rawValue, id: item.id, added: willAdd)
    }

    func clearAll() {
        items.removeAll()
        persist()
    }

    // MARK: - Post / Video / Gallery convenience

    func isPostFavorited(_ id: Int) -> Bool {
        contains(id: id, type: .post)
    }

    func togglePost(_ post: Post) {
        let item = FavoriteItem(
            id: post.id,
            type: .post,
            title: post.name,
            imageURL: post.image.cropped.medium,
            categoryName: post.categories.values.first,
            authorName: post.author?.name,
            createdAt: post.createdAt,
            savedAt: Date()
        )
        toggle(item)
    }

    func isVideoFavorited(_ id: Int) -> Bool {
        contains(id: id, type: .video)
    }

    func toggleVideo(id: Int, title: String, imageURL: String, category: String?, createdAt: String) {
        let item = FavoriteItem(
            id: id, type: .video,
            title: title, imageURL: imageURL,
            categoryName: category, authorName: nil,
            createdAt: createdAt, savedAt: Date()
        )
        toggle(item)
    }

    func isGalleryFavorited(_ id: Int) -> Bool {
        contains(id: id, type: .gallery)
    }

    func toggleGallery(id: Int, title: String, imageURL: String, category: String?, createdAt: String) {
        let item = FavoriteItem(
            id: id, type: .gallery,
            title: title, imageURL: imageURL,
            categoryName: category, authorName: nil,
            createdAt: createdAt, savedAt: Date()
        )
        toggle(item)
    }

    // MARK: - Filtering

    func items(of type: FavoriteItem.ItemType) -> [FavoriteItem] {
        items.filter { $0.type == type }
    }

    // MARK: - Storage

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            items = try JSONDecoder().decode([FavoriteItem].self, from: data)
        } catch {
            items = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // sessizce yut — kritik değil
        }
    }
}
