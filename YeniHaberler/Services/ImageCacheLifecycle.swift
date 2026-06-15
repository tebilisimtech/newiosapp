import Foundation
import UIKit
import Combine
import os

/// Image cache yaşam döngüsü hook'ları:
/// - Memory warning → memory katmanını boşalt (disk korunur)
/// - Günde 1 kez eviction (30 günden eski + 200MB üzeri LRU)
/// BackgroundScheduler eklendiğinde günlük eviction oraya taşınır.
final class ImageCacheLifecycle {
    static let shared = ImageCacheLifecycle()

    private let lastEvictionKey = "imageCache.lastEvictionAt"
    private let evictionInterval: TimeInterval = 24 * 3600  // 24 saat

    private var observer: NSObjectProtocol?

    private init() {}

    /// App.init'ten bir kez çağrılır.
    func bootstrap() {
        registerMemoryWarning()
        scheduleEvictionIfDue()
    }

    // MARK: - Memory warning

    private func registerMemoryWarning() {
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            AppLogger.app.warning("Memory warning — purging image memory cache")
            ImageCache.shared.purgeMemory()
        }
    }

    // MARK: - Daily eviction

    private func scheduleEvictionIfDue() {
        let now = Date()
        let lastEviction = UserDefaults.standard.object(forKey: lastEvictionKey) as? Date

        if let last = lastEviction, now.timeIntervalSince(last) < evictionInterval {
            return  // 24 saat geçmedi
        }

        Task.detached(priority: .background) {
            await ImageCache.shared.evictExpired()
            UserDefaults.standard.set(Date(), forKey: self.lastEvictionKey)
        }
    }
}
