//
//  YeniHaberlerApp.swift
//  YeniHaberler
//
//  Created by Hamit DİNCEL  on 8.01.2026.
//

import SwiftUI
import os
import UserNotifications
import GoogleMobileAds

@main
struct YeniHaberlerApp: App {
    init() {
        // Firebase (Crashlytics + Analytics) — ATT'den ÖNCE başlatılmalı ki crash
        // raporları yakalanabilsin. GoogleService-Info.plist target bundle'da.
        CrashReporter.shared.configureIfAvailable()
        CrashReporter.shared.setAnonymousUserIdentifier()

        // CoreData stack'i erken yükle (loadPersistentStores asenkron çağrılır).
        _ = PersistenceController.shared

        // UserDefaults → CoreData migration (idempotent, bir kerelik).
        Task { await LegacyDataMigrator.shared.runIfNeeded() }

        // Image cache eviction: günde 1 kez (BackgroundScheduler henüz yok).
        ImageCacheLifecycle.shared.bootstrap()

        // Push notification delegate erken kurulsun (bildirim açılışta gelebilir).
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        // NOT: AdMob ve OneSignal artık SplashScreenView'da ATT izni
        // alındıktan sonra TrackingConsentCoordinator tarafından başlatılır.
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .onOpenURL { url in
                    NavigationManager.shared.handleUniversalLink(url)
                }
        }
    }
}

// MARK: - Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private let dailyCounterKeyPrefix = "notif.dailyCount."

    // Foreground'da bildirim geldiğinde
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            let prefs = UserPreferences.shared

            // Master switch
            guard prefs.notificationsEnabled else {
                completionHandler([])
                return
            }

            // Sessiz saatler
            if prefs.isQuietNow() {
                completionHandler([])
                return
            }

            // Günlük limit (0 = sınırsız)
            if prefs.dailyNotificationLimit > 0 {
                let count = self.incrementDailyCounter()
                if count > prefs.dailyNotificationLimit {
                    completionHandler([])
                    return
                }
            }

            completionHandler([.banner, .sound, .badge])
        }
    }

    /// Bugün için bildirim sayacını 1 artırır, yeni değeri döner.
    private func incrementDailyCounter() -> Int {
        let key = dailyCounterKeyPrefix + Self.todayKey()
        let defaults = UserDefaults.standard
        let current = defaults.integer(forKey: key)
        let next = current + 1
        defaults.set(next, forKey: key)
        return next
    }

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // Bildirime tıklandığında
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Deep link işleme
        handleNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {

        var urlString: String?

        // OneSignal format: custom -> a -> url
        if let additionalData = userInfo["custom"] as? [String: Any],
           let a = additionalData["a"] as? [String: Any],
           let url = a["url"] as? String {
            urlString = url
        }
        // Alternatif format: direkt url
        else if let url = userInfo["url"] as? String {
            urlString = url
        }
        // Alternatif format: additionalData içinde direkt url
        else if let additionalData = userInfo["additionalData"] as? [String: Any],
                let url = additionalData["url"] as? String {
            urlString = url
        }

        if let url = urlString {
            Task { @MainActor in
                AnalyticsService.shared.logNotificationOpened(hasURL: true)
                await NavigationManager.shared.handleURL(url)
            }
        } else {
            AppLogger.push.warning("Notification without URL")
            Task { @MainActor in
                AnalyticsService.shared.logNotificationOpened(hasURL: false)
            }
        }
    }
}

