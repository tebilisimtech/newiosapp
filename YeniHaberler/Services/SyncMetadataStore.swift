import CoreData
import os

/// Per-query sync durumunu (son başarılı/denenmiş sync, etag, hata) izler.
/// Stale tespiti ve If-None-Match gönderimi için repository'ler tarafından kullanılır.
final class SyncMetadataStore {
    static let shared = SyncMetadataStore()

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    /// `queryKey` için son sync bilgilerini döner. Hiç sync olmadıysa nil.
    func metadata(for queryKey: String) -> SyncMetadata? {
        let ctx = persistence.container.viewContext
        let req: NSFetchRequest<CDSyncMetadata> = CDSyncMetadata.fetchRequest()
        req.predicate = NSPredicate(format: "queryKey == %@", queryKey)
        req.fetchLimit = 1
        guard let entity = try? ctx.fetch(req).first else { return nil }
        return SyncMetadata(
            queryKey: queryKey,
            lastSuccessfulSync: entity.lastSuccessfulSync,
            lastAttemptedSync: entity.lastAttemptedSync,
            lastError: entity.lastError,
            etag: entity.etag,
            itemCount: Int(entity.itemCount)
        )
    }

    /// Başarılı sync — etag ve item sayısı opsiyonel olarak güncellenir.
    func recordSuccess(for queryKey: String, itemCount: Int = 0, etag: String? = nil) {
        let ctx = persistence.newBackgroundContext()
        ctx.perform {
            let entity = self.fetchOrCreate(queryKey: queryKey, in: ctx)
            entity.lastSuccessfulSync = Date()
            entity.lastAttemptedSync = Date()
            entity.itemCount = Int32(itemCount)
            if let etag = etag { entity.etag = etag }
            entity.lastError = nil
            try? ctx.save()
        }
    }

    /// Başarısız sync — error mesajı saklanır, lastSuccessfulSync korunur.
    func recordFailure(for queryKey: String, error: Error) {
        let ctx = persistence.newBackgroundContext()
        ctx.perform {
            let entity = self.fetchOrCreate(queryKey: queryKey, in: ctx)
            entity.lastAttemptedSync = Date()
            entity.lastError = error.localizedDescription
            try? ctx.save()
        }
    }

    /// Belirli bir query'nin metadata'sını sil (örn. cache invalidation).
    func clear(_ queryKey: String) {
        let ctx = persistence.newBackgroundContext()
        ctx.perform {
            let req: NSFetchRequest<CDSyncMetadata> = CDSyncMetadata.fetchRequest()
            req.predicate = NSPredicate(format: "queryKey == %@", queryKey)
            if let entity = try? ctx.fetch(req).first {
                ctx.delete(entity)
                try? ctx.save()
            }
        }
    }

    // MARK: - Internal

    private func fetchOrCreate(queryKey: String, in ctx: NSManagedObjectContext) -> CDSyncMetadata {
        let req: NSFetchRequest<CDSyncMetadata> = CDSyncMetadata.fetchRequest()
        req.predicate = NSPredicate(format: "queryKey == %@", queryKey)
        req.fetchLimit = 1
        if let existing = try? ctx.fetch(req).first {
            return existing
        }
        let entity = CDSyncMetadata(context: ctx)
        entity.queryKey = queryKey
        return entity
    }
}

// MARK: - Read-only DTO
struct SyncMetadata {
    let queryKey: String
    let lastSuccessfulSync: Date?
    let lastAttemptedSync: Date?
    let lastError: String?
    let etag: String?
    let itemCount: Int

    /// `maxAge` saniyeden eski mi?
    func isStale(maxAge: TimeInterval) -> Bool {
        guard let last = lastSuccessfulSync else { return true }
        return Date().timeIntervalSince(last) > maxAge
    }
}
