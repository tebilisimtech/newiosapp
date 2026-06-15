import SwiftUI
import Combine

// MARK: - App Theme Mode
enum AppThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Sistem"
        case .light:  return "Açık"
        case .dark:   return "Koyu"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Font Scale
enum FontScale: String, CaseIterable, Identifiable {
    case small, medium, large, xlarge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small:  return "Küçük"
        case .medium: return "Orta"
        case .large:  return "Büyük"
        case .xlarge: return "Çok Büyük"
        }
    }

    /// Tüm tipografide kullanılacak çarpan.
    var multiplier: CGFloat {
        switch self {
        case .small:  return 0.9
        case .medium: return 1.0
        case .large:  return 1.15
        case .xlarge: return 1.3
        }
    }
}

// MARK: - Notification Category

enum NotificationCategory: String, CaseIterable, Identifiable, Codable {
    case breaking      = "breaking"
    case yozgatNews    = "yozgat"
    case sports        = "sports"
    case economy       = "economy"
    case magazine      = "magazine"
    case weather       = "weather"
    case dailyBriefing = "daily_briefing"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breaking:      return "Son Dakika"
        case .yozgatNews:    return "\(AppBranding.cityName) Haberleri"
        case .sports:        return "Spor"
        case .economy:       return "Ekonomi"
        case .magazine:      return "Magazin"
        case .weather:       return "Hava Durumu"
        case .dailyBriefing: return "Günün Özeti"
        }
    }

    var description: String {
        switch self {
        case .breaking:      return "Anlık ve kritik gelişmeler"
        case .yozgatNews:    return "\(TurkishSuffix.dative(AppBranding.cityName)) dair haberler"
        case .sports:        return "Spor haberleri ve maç sonuçları"
        case .economy:       return "Piyasa ve ekonomi gündemi"
        case .magazine:      return "Magazin ve yaşam"
        case .weather:       return "Hava durumu uyarıları"
        case .dailyBriefing: return "Her sabah günün özeti hazır"
        }
    }

    var icon: String {
        switch self {
        case .breaking:      return "bolt.fill"
        case .yozgatNews:    return "newspaper.fill"
        case .sports:        return "sportscourt.fill"
        case .economy:       return "chart.line.uptrend.xyaxis"
        case .magazine:      return "sparkles"
        case .weather:       return "cloud.sun.fill"
        case .dailyBriefing: return "sun.horizon.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .breaking:      return Theme.Colors.danger
        case .yozgatNews:    return Theme.Brand.primary
        case .sports:        return Theme.Colors.categoryGreen
        case .economy:       return Theme.Colors.success
        case .magazine:      return Theme.Colors.categoryPink
        case .weather:       return Theme.Colors.info
        case .dailyBriefing: return Theme.Brand.gold
        }
    }
}

// MARK: - User Preferences
@MainActor
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    private enum Keys {
        static let themeMode = "user.themeMode"
        static let fontScale = "user.fontScale"
        static let notificationsEnabled = "user.notificationsEnabled"
        static let autoplayVideos = "user.autoplayVideos"
        static let breakingNewsAlerts = "user.breakingNewsAlerts"

        // Yeni: detaylı bildirim ayarları
        static let enabledNotificationCategories = "user.notif.enabledCategories"
        static let quietHoursEnabled = "user.notif.quietHoursEnabled"
        static let quietHoursStart = "user.notif.quietHoursStart"   // saniye cinsinden gün içi offset (0..86399)
        static let quietHoursEnd = "user.notif.quietHoursEnd"
        static let dailyNotificationLimit = "user.notif.dailyLimit"

        static let hasCompletedOnboarding = "user.hasCompletedOnboarding"
    }

    @Published var themeMode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: Keys.themeMode)
            if !isLoading {
                AnalyticsService.shared.logSettingChange(name: "theme_mode", value: themeMode.rawValue)
            }
        }
    }

    @Published var fontScale: FontScale {
        didSet {
            UserDefaults.standard.set(fontScale.rawValue, forKey: Keys.fontScale)
            if !isLoading {
                AnalyticsService.shared.logSettingChange(name: "font_scale", value: fontScale.rawValue)
            }
        }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
            scheduleSync()
        }
    }

    @Published var autoplayVideos: Bool {
        didSet { UserDefaults.standard.set(autoplayVideos, forKey: Keys.autoplayVideos) }
    }

    @Published var breakingNewsAlerts: Bool {
        didSet {
            UserDefaults.standard.set(breakingNewsAlerts, forKey: Keys.breakingNewsAlerts)
            scheduleSync()
        }
    }

    /// Aboneliği aktif olan bildirim kategorileri.
    @Published var enabledNotificationCategories: Set<NotificationCategory> {
        didSet {
            let raw = enabledNotificationCategories.map { $0.rawValue }
            UserDefaults.standard.set(raw, forKey: Keys.enabledNotificationCategories)
            scheduleSync()
        }
    }

    @Published var quietHoursEnabled: Bool {
        didSet {
            UserDefaults.standard.set(quietHoursEnabled, forKey: Keys.quietHoursEnabled)
            scheduleSync()
        }
    }

    /// Sessiz saat başlangıcı — sadece saat/dakika kullanılır.
    @Published var quietHoursStart: Date {
        didSet {
            UserDefaults.standard.set(Self.secondsOfDay(quietHoursStart), forKey: Keys.quietHoursStart)
            scheduleSync()
        }
    }

    @Published var quietHoursEnd: Date {
        didSet {
            UserDefaults.standard.set(Self.secondsOfDay(quietHoursEnd), forKey: Keys.quietHoursEnd)
            scheduleSync()
        }
    }

    /// Günlük bildirim limiti (0 = sınırsız).
    @Published var dailyNotificationLimit: Int {
        didSet {
            UserDefaults.standard.set(dailyNotificationLimit, forKey: Keys.dailyNotificationLimit)
            scheduleSync()
        }
    }

    /// Kullanıcı onboarding akışını tamamladı mı?
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    private var isLoading = true
    private var pendingSync: DispatchWorkItem?

    private init() {
        let defaults = UserDefaults.standard

        let storedTheme = defaults.string(forKey: Keys.themeMode) ?? AppThemeMode.system.rawValue
        self.themeMode = AppThemeMode(rawValue: storedTheme) ?? .system

        let storedScale = defaults.string(forKey: Keys.fontScale) ?? FontScale.medium.rawValue
        self.fontScale = FontScale(rawValue: storedScale) ?? .medium

        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.autoplayVideos = defaults.object(forKey: Keys.autoplayVideos) as? Bool ?? false
        self.breakingNewsAlerts = defaults.object(forKey: Keys.breakingNewsAlerts) as? Bool ?? true

        // Kategoriler — yoksa hepsi açık
        if let raws = defaults.array(forKey: Keys.enabledNotificationCategories) as? [String] {
            self.enabledNotificationCategories = Set(raws.compactMap(NotificationCategory.init(rawValue:)))
        } else {
            self.enabledNotificationCategories = Set(NotificationCategory.allCases)
        }

        self.quietHoursEnabled = defaults.bool(forKey: Keys.quietHoursEnabled)

        // Default: 23:00 → 07:00
        let startSecs = defaults.object(forKey: Keys.quietHoursStart) as? Int ?? (23 * 3600)
        let endSecs   = defaults.object(forKey: Keys.quietHoursEnd)   as? Int ?? (7 * 3600)
        self.quietHoursStart = Self.dateFromSecondsOfDay(startSecs)
        self.quietHoursEnd   = Self.dateFromSecondsOfDay(endSecs)

        self.dailyNotificationLimit = defaults.object(forKey: Keys.dailyNotificationLimit) as? Int ?? 10

        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)

        self.isLoading = false
    }

    // MARK: - Quiet hours yardımcıları

    /// Şu anki cihaz saati sessiz aralık içinde mi?
    func isQuietNow(at date: Date = Date()) -> Bool {
        guard quietHoursEnabled else { return false }
        let now = Self.secondsOfDay(date)
        let start = Self.secondsOfDay(quietHoursStart)
        let end = Self.secondsOfDay(quietHoursEnd)

        if start == end { return false }
        if start < end {
            return now >= start && now < end
        } else {
            // Gece yarısını kapsayan aralık (örn 23:00–07:00)
            return now >= start || now < end
        }
    }

    static func secondsOfDay(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60
    }

    private static func dateFromSecondsOfDay(_ secs: Int) -> Date {
        let hour = secs / 3600
        let minute = (secs % 3600) / 60
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    // MARK: - OneSignal sync orchestration

    /// didSet'lerden gelen ardışık değişiklikleri 0.3 sn debounce ederek tek sync'e indirir.
    private func scheduleSync() {
        guard !isLoading else { return }
        pendingSync?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard self != nil else { return }
            Task { @MainActor in
                OneSignalService.shared.syncPreferencesWithOneSignal()
            }
        }
        pendingSync = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}

// MARK: - Scaled Font Modifier
struct ScaledFontModifier: ViewModifier {
    @ObservedObject private var prefs = UserPreferences.shared
    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    @ObservedObject private var remoteTheme = RemoteTheme.shared

    func body(content: Content) -> some View {
        content.font(
            remoteTheme.font(
                size: baseSize * prefs.fontScale.multiplier,
                weight: weight,
                design: design
            )
        )
    }
}

extension View {
    /// Kullanıcının font scale tercihine göre büyüyen yazı tipi.
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        self.modifier(ScaledFontModifier(baseSize: size, weight: weight, design: design))
    }
}
