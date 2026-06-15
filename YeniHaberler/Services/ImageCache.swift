import UIKit
import CryptoKit
import os

/// 2 katmanlı görsel cache: memory (NSCache, 50MB cost limit) + disk (200MB LRU).
/// SwiftUI `CachedAsyncImage` bu cache üzerinden çalışır.
actor ImageCache {
    static let shared = ImageCache()

    // NSCache is thread-safe by Apple's design contract; nonisolated allows
    // synchronous access from nonisolated memoryImage/storeInMemory hot path.
    nonisolated(unsafe) private let memory: NSCache<NSString, UIImage>
    private let diskDirectory: URL
    private let maxDiskBytes: Int64 = 200 * 1024 * 1024  // 200MB
    private let session: URLSession

    init() {
        memory = NSCache()
        memory.totalCostLimit = 50 * 1024 * 1024  // 50MB
        memory.countLimit = 200

        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        diskDirectory = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? fm.createDirectory(at: diskDirectory, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15
        config.urlCache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 50_000_000)
        session = URLSession(configuration: config)
    }

    // MARK: - Memory (non-isolated için hızlı eşzamanlı erişim)

    nonisolated func memoryImage(for url: String) -> UIImage? {
        memory.object(forKey: url as NSString)
    }

    nonisolated func storeInMemory(_ image: UIImage, for url: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        memory.setObject(image, forKey: url as NSString, cost: cost)
    }

    /// Memory cache'i temizler (memory warning'de çağrılır). Disk korunur.
    nonisolated func purgeMemory() {
        memory.removeAllObjects()
    }

    // MARK: - Disk

    func diskImage(for url: String) async -> UIImage? {
        let path = filePath(for: url)
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let image = UIImage(data: data) else { return nil }

        // LRU için modifiedAt'i güncelle
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: path.path
        )
        return image
    }

    // MARK: - Network

    func fetchAndStore(url: String) async throws -> UIImage {
        guard let nsurl = URL(string: url) else { throw ImageCacheError.invalidURL }
        let (data, _) = try await session.data(from: nsurl)
        guard let image = UIImage(data: data) else { throw ImageCacheError.decodeFailed }

        storeInMemory(image, for: url)
        let path = filePath(for: url)
        try? data.write(to: path)

        return image
    }

    // MARK: - Eviction (LRU + 30 günden eski)

    func evictExpired() async {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: diskDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-30 * 86400)  // 30 gün
        let attributed: [(URL, Date, Int64)] = files.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let date = values.contentModificationDate,
                  let size = values.fileSize else { return nil }
            return (url, date, Int64(size))
        }

        // 30 günden eski olanları sil
        let expired = attributed.filter { $0.1 < cutoff }
        for item in expired {
            try? fm.removeItem(at: item.0)
        }

        // Boyut sınırı: en eski LRU'dan başlayarak sil
        let remaining = attributed.filter { $0.1 >= cutoff }.sorted { $0.1 < $1.1 }
        var totalSize = remaining.reduce(Int64(0)) { $0 + $1.2 }
        var index = 0
        while totalSize > maxDiskBytes && index < remaining.count {
            try? fm.removeItem(at: remaining[index].0)
            totalSize -= remaining[index].2
            index += 1
        }

        let removed = expired.count + index
        if removed > 0 {
        }
    }

    /// Komple disk cache'i temizler (kullanıcı manuel "cache temizle" için).
    func purgeDisk() async {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: diskDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fm.removeItem(at: file)
        }
    }

    // MARK: - Private

    private nonisolated func filePath(for url: String) -> URL {
        let hash = SHA256.hash(data: Data(url.utf8))
        let filename = hash.map { String(format: "%02x", $0) }.joined()
        return diskDirectory.appendingPathComponent(filename)
    }
}

enum ImageCacheError: Error {
    case invalidURL
    case decodeFailed
}
