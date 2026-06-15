import Foundation
import os

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Crashlytics ve genel hata raporlama servisi.
///
/// Firebase SDK projede yoksa tüm metodlar no-op olarak çalışır (build kırılmaz).
/// Firebase eklendiğinde otomatik aktive olur — code değişikliği gerekmez.
final class CrashReporter {
    static let shared = CrashReporter()

    private init() {}

    // MARK: - Lifecycle

    /// FirebaseApp.configure() çağrısı.
    /// App başlatma sırasında bir kez çağrılır (ATT prompt'undan önce).
    /// GoogleService-Info.plist target bundle'da olmalı.
    func configureIfAvailable() {
        #if canImport(FirebaseCore)
        // FirebaseApp.configure() idempotent değildir, sadece bir kez çağrılmalı.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #else
        AppLogger.crash.notice("Firebase SDK not in project — CrashReporter no-op")
        #endif
    }

    // MARK: - Identity

    /// Anonim kullanıcı kimliği ayarla (her cihaz için sabit UUID).
    /// Crash raporlarında kullanıcı bazlı filtreleme için.
    func setAnonymousUserIdentifier() {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(Self.anonymousUserId)
        #endif
    }

    /// Manuel kullanıcı kimliği (login varsa).
    func setUserIdentifier(_ id: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(id)
        #endif
    }

    // MARK: - Logging

    /// Yakalanan Error'u Crashlytics'e non-fatal olarak gönder.
    ///
    /// - Parameters:
    ///   - error: Yakalanan hata
    ///   - context: Hata anındaki ek bilgi (endpoint, post ID, vs.)
    ///   - file/function/line: Debug için, otomatik doldurulur
    func logError(
        _ error: Error,
        context: [String: Any]? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        #if canImport(FirebaseCrashlytics)
        let nsError = enrichedNSError(from: error, context: context, file: file, function: function, line: line)
        Crashlytics.crashlytics().record(error: nsError)
        #else
        AppLogger.crash.error("\(file, privacy: .public):\(line, privacy: .public) \(function, privacy: .public) → \(error.localizedDescription, privacy: .public)")
        if let context = context {
            AppLogger.crash.error("Context: \(String(describing: context), privacy: .private)")
        }
        #endif
    }

    /// Custom mesaj (breadcrumb tarzı).
    /// Crash öncesi son kullanıcı aksiyonlarını izlemek için.
    func logMessage(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #else
        #endif
    }

    /// Custom key-value ayarla (örn. "screen": "PostDetail", "post_id": "1234").
    func setCustomValue(_ value: Any, forKey key: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #endif
    }

    // MARK: - Helpers

    #if canImport(FirebaseCrashlytics)
    private func enrichedNSError(
        from error: Error,
        context: [String: Any]?,
        file: String,
        function: String,
        line: Int
    ) -> NSError {
        let original = error as NSError
        var userInfo = original.userInfo
        userInfo[NSLocalizedDescriptionKey] = error.localizedDescription
        userInfo["file"] = file
        userInfo["function"] = function
        userInfo["line"] = line
        if let context = context {
            for (key, value) in context {
                userInfo["ctx.\(key)"] = "\(value)"
            }
        }
        return NSError(domain: original.domain, code: original.code, userInfo: userInfo)
    }
    #endif

    // MARK: - Anonymous user ID
    private static let anonymousUserIdKey = "crashreporter.anonymous.id"
    private static var anonymousUserId: String {
        if let stored = UserDefaults.standard.string(forKey: anonymousUserIdKey) {
            return stored
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: anonymousUserIdKey)
        return new
    }
}
