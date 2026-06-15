import Foundation
import Combine
import os

/// Sunucudan gelen özel reklam (Advert) için merkezi yükleyici.
/// Her reklam bir veya birden çok **kanal (placement)** id'sine atanır (2000–2025).
/// `advert(forChannel:)` o kanala atanmış, aktif ve gösterilebilir reklamı döndürür.
@MainActor
final class AdvertManager: ObservableObject {
    static let shared = AdvertManager()

    @Published private(set) var adverts: [AdvertItem] = []
    @Published private(set) var isLoading = false
    /// Splash sonrası gösterilecek özel interstitial reklam (kanal #2025). MainView izler.
    @Published var pendingInterstitial: AdvertItem?

    private let api = APIService.shared
    private var loadTask: Task<Void, Never>?

    private init() {}

    func loadIfNeeded() {
        guard loadTask == nil, adverts.isEmpty else { return }
        loadTask = Task { await load() }
    }

    /// Yüklenene kadar bekler (splash interstitial kararı için).
    func ensureLoaded() async {
        if !adverts.isEmpty { return }
        if let task = loadTask { await task.value; return }
        await load()
    }

    /// Pull-to-refresh vb. için zorla yeniden yükleme.
    func reload() async {
        adverts = []
        loadTask = nil
        await load()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false; loadTask = nil }

        do {
            let response = try await api.fetchAdverts(perPage: 50)
            // Aktif + gösterilebilir (kod veya görsel) olanları tut.
            adverts = response.data.filter { $0.isActive && $0.hasRenderableContent }
        } catch {
            AppLogger.ads.error("Advert load — \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Belirli bir kanala (placement id) atanmış ilk uygun reklamı döndürür.
    func advert(forChannel channelId: Int) -> AdvertItem? {
        adverts.first { $0.channelIds.contains(channelId) && $0.hasRenderableContent }
    }
}
