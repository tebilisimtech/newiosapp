import Foundation
import os

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// Custom Firebase Analytics event'leri için ince wrapper.
///
/// **Performans tasarımı:**
/// - Tüm `log*` çağrıları main thread'de tetiklenir ama Firebase SDK kuyruğuna
///   gönderim background'da olur — main thread iş yapmaz (FB SDK kendi GCD
///   kuyruğunu kullanır, batch'ler 10s aralıkla gönderilir).
/// - Parametre sözlüğü inline kurulur, ek allocation/encoding yok.
/// - `dedup` filtresi: aynı `id+name` 2 saniye içinde tekrar log'lanmaz —
///   örn. SwiftUI body re-evaluation sonucu task tekrar çalışırsa duplicate event önlenir.
/// - Firebase SDK projede yoksa tüm metodlar derlenir ama no-op çalışır.
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private var lastLogged: [String: TimeInterval] = [:]
    private let dedupWindow: TimeInterval = 2.0

    private init() {}

    // MARK: - Lifecycle

    /// Kullanıcı tracking izni reddettiyse veya kullanıcı tarafından
    /// kapatıldıysa collection durdurulur.
    func setCollectionEnabled(_ enabled: Bool) {
        #if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(enabled)
        #endif
    }

    // MARK: - Content events

    /// Detay sayfası açıldı.
    func logContentView(type: String, id: Int, category: String? = nil) {
        let key = "view_\(type)_\(id)"
        guard shouldLog(key: key) else { return }
        log("content_view", parameters: [
            "content_type": type,
            "item_id": "\(id)",
            "category": category ?? ""
        ])
    }

    /// Haber paylaşıldı.
    func logShare(type: String, id: Int) {
        log("share", parameters: [
            "content_type": type,
            "item_id": "\(id)"
        ])
    }

    /// Favori eklendi/kaldırıldı.
    func logFavoriteToggle(type: String, id: Int, added: Bool) {
        log("favorite_toggle", parameters: [
            "content_type": type,
            "item_id": "\(id)",
            "added": added ? "true" : "false"
        ])
    }

    // MARK: - Search

    /// Arama gerçekleşti. **Gizlilik:** sorgu metni gönderilmez, sadece
    /// karakter uzunluğu + sonuç sayısı.
    func logSearch(queryLength: Int, resultCount: Int) {
        log("search", parameters: [
            "query_length": "\(queryLength)",
            "result_count": "\(resultCount)"
        ])
    }

    // MARK: - Story / engagement

    func logStoryGroupOpened(groupId: String) {
        let key = "story_\(groupId)"
        guard shouldLog(key: key) else { return }
        log("story_open", parameters: ["group_id": groupId])
    }

    // MARK: - Onboarding

    func logOnboardingStep(_ step: String) {
        log("onboarding_step", parameters: ["step": step])
    }

    func logOnboardingCompleted() {
        log("onboarding_completed", parameters: [:])
    }

    // MARK: - Notifications

    func logNotificationOpened(hasURL: Bool) {
        log("notification_opened", parameters: ["has_url": hasURL ? "true" : "false"])
    }

    // MARK: - Settings

    func logSettingChange(name: String, value: String) {
        log("setting_change", parameters: [
            "setting_name": name,
            "value": value
        ])
    }

    // MARK: - Private

    /// Tekrarlanan event'leri filtreler (örneğin SwiftUI .task'ın tekrar çalışması).
    private func shouldLog(key: String) -> Bool {
        let now = Date().timeIntervalSince1970
        if let last = lastLogged[key], now - last < dedupWindow {
            return false
        }
        lastLogged[key] = now
        // Hafıza koruması — 200 farklı key'den fazlasını tutma
        if lastLogged.count > 200 {
            lastLogged.removeAll(keepingCapacity: true)
        }
        return true
    }

    private func log(_ name: String, parameters: [String: String]) {
        #if canImport(FirebaseAnalytics)
        // FirebaseAnalytics SDK çağrıları kendi GCD kuyruğunu kullanır, main
        // thread'de bloklanma olmaz. Yine de explicit detached Task ile string
        // dictionary kopyalamasını caller'dan ayırıyoruz.
        let params: [String: Any] = parameters.filter { !$0.value.isEmpty }
        Task.detached(priority: .utility) {
            Analytics.logEvent(name, parameters: params)
        }
        #else
        #endif
    }
}
