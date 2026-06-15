import Foundation
import Combine

/// İlgi alanı kategorisi (onboarding seçimi + kişiselleştirme temeli).
/// Android `InterestCategory` karşılığı.
struct InterestCategory: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    var slug: String = ""
}

/// Kullanıcının seçtiği ilgi alanları (kategoriler). Açılışta bir kez sorulur,
/// sonra Ayarlar/SideMenu'den düzenlenebilir. Kalıcı (UserDefaults + JSON).
/// Android `core/Interests` karşılığı.
@MainActor
final class UserInterests: ObservableObject {
    static let shared = UserInterests()

    @Published private(set) var categories: [InterestCategory] = []
    /// Açılışta ilgi alanı ekranı bir kez gösterildi mi (Devam ya da Atla).
    @Published private(set) var hasPrompted: Bool = false

    private let catsKey = "userInterests.categories.v1"
    private let promptedKey = "userInterests.prompted.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: catsKey),
           let decoded = try? JSONDecoder().decode([InterestCategory].self, from: data) {
            categories = decoded
        }
        hasPrompted = UserDefaults.standard.bool(forKey: promptedKey)
    }

    var hasSelected: Bool { !categories.isEmpty }

    func isSelected(_ id: Int) -> Bool { categories.contains { $0.id == id } }

    func set(_ list: [InterestCategory]) {
        categories = list
        persist()
    }

    func toggle(_ cat: InterestCategory) {
        if isSelected(cat.id) {
            categories.removeAll { $0.id == cat.id }
        } else {
            categories.append(cat)
        }
        persist()
    }

    /// İlgi alanı ekranı gösterildi olarak işaretle (tekrar açılışta sorulmasın).
    func markPrompted() {
        hasPrompted = true
        UserDefaults.standard.set(true, forKey: promptedKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: catsKey)
        }
    }
}
