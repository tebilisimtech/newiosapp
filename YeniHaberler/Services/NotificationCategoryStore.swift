import Foundation
import Combine

// MARK: - Notification Category Store
//
// Bildirim tercihlerindeki kategoriler artık sabit enum değil, CMS `/categories`
// API'sinden gelir. Kullanıcı bir kategoriyi kapatınca id'si `disabledIds`'e
// eklenir (opt-out: yeni kategoriler varsayılan AÇIK) ve OneSignal'a
// `category_<id> = 0` etiketi yazılır. Panel, ilgili kategoriden bildirim
// gönderirken bu etiketi (örn. `category_5 != 0`) filtre olarak kullanmalıdır.
@MainActor
final class NotificationCategoryStore: ObservableObject {
    static let shared = NotificationCategoryStore()

    @Published private(set) var categories: [Category] = []
    @Published private(set) var disabledIds: Set<Int> = []
    @Published private(set) var isLoading = false

    private let storageKey = "notif.disabledCategoryIds"
    private let api = APIService.shared

    private init() {
        if let arr = UserDefaults.standard.array(forKey: storageKey) as? [Int] {
            disabledIds = Set(arr)
        }
    }

    /// CMS kategorilerini çeker (bir kez). Gelince OneSignal etiketlerini yazar.
    func loadCategories() async {
        guard categories.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        if let response = try? await api.fetchCategories(perPage: 100) {
            categories = response.data
            OneSignalService.shared.syncPreferencesWithOneSignal()
        }
    }

    func reload() async {
        categories = []
        await loadCategories()
    }

    func isEnabled(_ id: Int) -> Bool { !disabledIds.contains(id) }

    func setEnabled(_ id: Int, _ enabled: Bool) {
        if enabled { disabledIds.remove(id) } else { disabledIds.insert(id) }
        UserDefaults.standard.set(Array(disabledIds), forKey: storageKey)
        OneSignalService.shared.syncPreferencesWithOneSignal()
    }
}
