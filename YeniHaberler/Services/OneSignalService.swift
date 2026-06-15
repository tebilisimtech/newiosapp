import Foundation
import os
import Combine
import UserNotifications
import UIKit
import OneSignalFramework

// MARK: - OneSignal Service
@MainActor
class OneSignalService: ObservableObject {
    static let shared = OneSignalService()
    
    @Published var isInitialized = false
    @Published var pushToken: String?
    @Published var userId: String?
    
    private let oneSignalAppId: String

    private init() {
        // OneSignal App ID artık .env üzerinden Config'e yüklenir (gitignored).
        self.oneSignalAppId = Config.shared.oneSignalAppId
    }

    /// OneSignal'i initialize et
    func initialize() {
        guard !oneSignalAppId.isEmpty else {
            AppLogger.push.error("OneSignal App ID missing — add ONESIGNAL_APP_ID to .env")
            return
        }


        OneSignal.initialize(oneSignalAppId, withLaunchOptions: nil)
        isInitialized = true

        // Bildirime tıklanınca uygulama-içi yönlendirme.
        // OneSignal v5 kendi delegate swizzling'ini yaptığından, sistem
        // UNUserNotificationCenterDelegate.didReceive bu durumda tetiklenmez —
        // tıklama olaylarını OneSignal'ın kendi click listener'ı ile yakalıyoruz.
        OneSignal.Notifications.addClickListener(NotificationClickRouter.shared)

        // Push notification izinleri — permission callback subscription oluşumundan
        // sonra geldiği için tag sync'i buradan tetikliyoruz. Aksi halde
        // OneSignal property update request reddedilir.
        OneSignal.Notifications.requestPermission({ [weak self] accepted in
            if accepted {
            } else {
                AppLogger.push.notice("Push permission denied")
            }
            // Permission akışı bittikten sonra (ister reddedilsin ister kabul) tercih
            // tag'lerini yaz; reddedilse bile user kaydı zaten oluşmuş oluyor.
            Task { @MainActor in
                // Subscription'ın sunucuya kaydedilmesi için kısa nefes
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self?.syncPreferencesWithOneSignal()
            }
        }, fallbackToSettings: false)
    }


    /// Push token'ı kaydet (token = sensitive, .private)
    func setPushToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        self.pushToken = tokenString
    }

    /// User ID'yi kaydet
    func setUserId(_ userId: String) {
        self.userId = userId
        OneSignal.login(userId)
    }

    /// Tag ekle (tag değerleri kullanıcı tercihi olabilir, .private)
    func addTag(key: String, value: String) {
        OneSignal.User.addTags([key: value])
    }

    /// Tag sil
    func removeTag(key: String) {
        OneSignal.User.removeTags([key])
    }

    /// Tüm bildirim tercihlerini OneSignal etiketlerine yansıtır.
    /// Sunucu tarafı segmentleme bu etiketler üzerinden yapılır:
    /// - `category_<key>`: "1"/"0"
    /// - `quiet_enabled`, `quiet_start`, `quiet_end` (HH:mm)
    /// - `daily_limit`: 0 = sınırsız
    /// - `push_enabled`: master switch
    func syncPreferencesWithOneSignal() {
        guard isInitialized else { return }

        let prefs = UserPreferences.shared
        var tags: [String: String] = [:]

        // Master switch
        tags["push_enabled"] = prefs.notificationsEnabled ? "1" : "0"
        tags["breaking_alerts"] = prefs.breakingNewsAlerts ? "1" : "0"

        // Kategori abonelikleri — CMS kategorileri (id bazlı): category_<id> = 1/0.
        // Panel ilgili kategoriden gönderirken bu etiketi filtre olarak kullanmalı
        // (örn. category_5 != 0). Kategoriler henüz yüklenmediyse atlanır; yüklenince
        // NotificationCategoryStore tekrar sync tetikler.
        let categoryStore = NotificationCategoryStore.shared
        for category in categoryStore.categories {
            tags["category_\(category.id)"] = categoryStore.isEnabled(category.id) ? "1" : "0"
        }

        // Quiet hours (HH:mm formatı)
        tags["quiet_enabled"] = prefs.quietHoursEnabled ? "1" : "0"
        tags["quiet_start"]   = Self.formatHHmm(prefs.quietHoursStart)
        tags["quiet_end"]     = Self.formatHHmm(prefs.quietHoursEnd)

        // Günlük limit
        tags["daily_limit"] = String(prefs.dailyNotificationLimit)

        OneSignal.User.addTags(tags)
    }

    private static func formatHHmm(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Notification Click Router
//
// OneSignal v5 bildirim tıklamalarını yakalar ve uygulama-içi yönlendirmeyi
// `NavigationManager` üzerinden yapar. URL kaynağı önceliği:
//   1) additionalData["url"]  (dashboard → Additional Data: url=...)
//   2) launchURL              (dashboard → Launch URL alanı)
final class NotificationClickRouter: NSObject, OSNotificationClickListener {
    static let shared = NotificationClickRouter()

    func onClick(event: OSNotificationClickEvent) {
        let notification = event.notification

        var target: String?
        if let data = notification.additionalData,
           let url = data["url"] as? String, !url.isEmpty {
            target = url
        } else if let launch = notification.launchURL, !launch.isEmpty {
            target = launch
        }

        guard let urlString = target else {
            AppLogger.push.notice("Notification clicked — no URL in payload")
            return
        }

        AnalyticsService.shared.logNotificationOpened(hasURL: true)

        Task { @MainActor in
            await NavigationManager.shared.handleURL(urlString)
        }
    }
}
