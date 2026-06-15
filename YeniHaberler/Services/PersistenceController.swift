import CoreData
import os

/// CoreData stack — offline-first mimarinin temeli.
/// Tek model: `YeniHaberler.xcdatamodeld`.
final class PersistenceController {
    nonisolated static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "YeniHaberler")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else if let desc = container.persistentStoreDescriptions.first {
            desc.shouldMigrateStoreAutomatically = true
            desc.shouldInferMappingModelAutomatically = true
            desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            desc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        container.loadPersistentStores { [container] description, error in
            if let error = error {
                AppLogger.app.error("CoreData store load failed — \(error.localizedDescription, privacy: .public)")
                #if DEBUG
                assertionFailure("CoreData store load failed: \(error)")
                #endif
            } else {
                _ = container
            }
        }

        // Main context: read-only UI bağlamı (writes background context'ten merge edilir)
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Yazma işlemleri için background context.
    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = false
        return ctx
    }

    /// 90 gün+ eski post'ları (favori değilse) temizler. SyncCoordinator tarafından çağrılır.
    func performHousekeeping() async {
        let ctx = newBackgroundContext()
        await ctx.perform {
            let cutoff = Date().addingTimeInterval(-90 * 24 * 3600)

            let req: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDPost")
            req.predicate = NSPredicate(format: "lastFetchedAt < %@ AND isFavorite == NO", cutoff as NSDate)
            let delete = NSBatchDeleteRequest(fetchRequest: req)
            delete.resultType = .resultTypeCount
            if let result = try? ctx.execute(delete) as? NSBatchDeleteResult,
               let count = result.result as? Int, count > 0 {
            }
            try? ctx.save()
        }
    }
}
