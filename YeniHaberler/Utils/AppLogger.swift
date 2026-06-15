import Foundation
import os

/// Merkezi logger — production-safe (privacy-aware).
///
/// Kullanım:
///   AppLogger.api.info("Settings loaded")
///   AppLogger.api.error("Endpoint failed: \(url.path, privacy: .public)")
///   AppLogger.ui.debug("Sheet presented")
///
/// `Logger` API tarihsel olarak Console.app, Xcode debug area, sysdiagnose
/// içinde görünür ama `.private` interpolation ile hassas alanlar maskelenir.
/// `print()` aksine **release build'de de çalışır** ama performans hassas
/// (Apple SLA: tek log < 0.1ms).
///
/// Hassas alanlar (`token`, `userId`, `apiKey`, kişisel email vs.) interpolation
/// içinde `, privacy: .private` flag'i ile yazılmalı.
enum AppLogger {
    private static let subsystem = "com.yenihaberler.app"

    // MARK: - Categories
    /// Network, API çağrıları
    nonisolated static let api      = Logger(subsystem: subsystem, category: "api")
    /// UI olayları, navigation, ekran açılışları
    nonisolated static let ui       = Logger(subsystem: subsystem, category: "ui")
    /// Veri senkronizasyonu, cache, persistence
    nonisolated static let sync     = Logger(subsystem: subsystem, category: "sync")
    /// Auth, ATT, izin akışları
    nonisolated static let auth     = Logger(subsystem: subsystem, category: "auth")
    /// Reklam SDK'ları (AdMob, UMP)
    nonisolated static let ads      = Logger(subsystem: subsystem, category: "ads")
    /// Push bildirimleri (OneSignal)
    nonisolated static let push     = Logger(subsystem: subsystem, category: "push")
    /// Crash reporting (Firebase Crashlytics)
    nonisolated static let crash    = Logger(subsystem: subsystem, category: "crash")
    /// Genel/sınıflandırılmamış
    nonisolated static let app      = Logger(subsystem: subsystem, category: "app")
}
