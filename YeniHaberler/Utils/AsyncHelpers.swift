import Foundation

/// Bir async operation'ı belirlenen saniye sınırı içinde çalıştırır.
/// Operation tamamlanırsa sonucunu, timeout'a uğrarsa nil döner.
/// Hata durumunda da nil döner — çağıran tarafa exception sızmaz.
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async -> T? {
    return await withTaskGroup(of: T?.self) { group -> T? in
        group.addTask {
            do { return try await operation() } catch { return nil }
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        guard let result = await group.next() else {
            group.cancelAll()
            return nil
        }
        group.cancelAll()
        return result
    }
}
