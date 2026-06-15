import Foundation
import CoreData
import os

/// Eski UserDefaults tabanlı `FavoritesService` + `ReadingHistoryService`
/// verilerini CoreData entity'lerine taşır. Bir kerelik çalışır; tamamlanan
/// migration'lar `UserDefaults` flag'leriyle işaretlenir.
@MainActor
final class LegacyDataMigrator {
    static let shared = LegacyDataMigrator()

    private let persistence: PersistenceController
    private let defaults: UserDefaults

    private let favoritesMigratedKey = "migration.favorites.v1.completed"
    private let historyMigratedKey   = "migration.history.v1.completed"

    private let favoritesStorageKey  = "favorites.v1"
    private let historyStorageKey    = "readingHistory.v1"

    init(persistence: PersistenceController = .shared,
         defaults: UserDefaults = .standard) {
        self.persistence = persistence
        self.defaults = defaults
    }

    /// Uygulama açılışında çağrılır. Idempotent.
    func runIfNeeded() async {
        await migrateFavoritesIfNeeded()
        await migrateHistoryIfNeeded()
    }

    // MARK: - Favorites

    private func migrateFavoritesIfNeeded() async {
        guard !defaults.bool(forKey: favoritesMigratedKey) else { return }
        guard let data = defaults.data(forKey: favoritesStorageKey),
              let items = try? JSONDecoder().decode([FavoriteItem].self, from: data),
              !items.isEmpty else {
            defaults.set(true, forKey: favoritesMigratedKey)
            return
        }

        let ctx = persistence.newBackgroundContext()
        await ctx.perform {
            for item in items {
                let compositeId = "\(item.type.rawValue)_\(item.id)"

                // Aynı kayıt CoreData'da varsa atla
                let req: NSFetchRequest<CDFavorite> = CDFavorite.fetchRequest()
                req.predicate = NSPredicate(format: "compositeId == %@", compositeId)
                req.fetchLimit = 1
                if (try? ctx.fetch(req).first) != nil { continue }

                let entity = CDFavorite(context: ctx)
                entity.compositeId = compositeId
                entity.refId = Int64(item.id)
                entity.refType = item.type.rawValue
                entity.title = item.title
                entity.imageURL = item.imageURL
                entity.categoryName = item.categoryName
                entity.authorName = item.authorName
                entity.createdAtSnapshot = item.createdAt
                entity.savedAt = item.savedAt
            }
            do {
                try ctx.save()
            } catch {
                AppLogger.app.error("Favorites migration save — \(error.localizedDescription, privacy: .public)")
            }
        }

        defaults.set(true, forKey: favoritesMigratedKey)
    }

    // MARK: - Reading history

    private func migrateHistoryIfNeeded() async {
        guard !defaults.bool(forKey: historyMigratedKey) else { return }
        guard let data = defaults.data(forKey: historyStorageKey),
              let items = try? JSONDecoder().decode([HistoryItem].self, from: data),
              !items.isEmpty else {
            defaults.set(true, forKey: historyMigratedKey)
            return
        }

        let ctx = persistence.newBackgroundContext()
        await ctx.perform {
            for item in items {
                let compositeId = "\(item.type.rawValue)_\(item.id)"

                let req: NSFetchRequest<CDHistoryItem> = CDHistoryItem.fetchRequest()
                req.predicate = NSPredicate(format: "compositeId == %@", compositeId)
                req.fetchLimit = 1
                if (try? ctx.fetch(req).first) != nil { continue }

                let entity = CDHistoryItem(context: ctx)
                entity.compositeId = compositeId
                entity.refId = Int64(item.id)
                entity.refType = item.type.rawValue
                entity.title = item.title
                entity.imageURL = item.imageURL
                entity.categoryName = item.categoryName
                entity.authorName = item.authorName
                entity.readAt = item.readAt
                entity.readDurationSeconds = 0
            }
            do {
                try ctx.save()
            } catch {
                AppLogger.app.error("History migration save — \(error.localizedDescription, privacy: .public)")
            }
        }

        defaults.set(true, forKey: historyMigratedKey)
    }
}
