import SwiftUI
import os
import Combine

// MARK: - App Settings Manager (Merkezi Ayar Yönetimi)
@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // Published properties
    @Published var settings: SettingsData?
    @Published var isLoading = false
    
    // Computed properties for easy access
    var appLogo: String? { settings?.logoMobil }
    
    // MARK: - Modules (server-driven home page)
    //
    // Yeni API: `settings.modules = { key: { value, position } }`.
    // `enabledModulesInOrder` görünür modülleri pozisyon sırasına göre döner;
    // NewHomeView buradan zincirleyip render eder.
    // Modules yoksa (eski API / yükleme başarısız) eski flat alanlara ve
    // varsayılan sıraya fallback yapılır.

    /// Görünür modülleri pozisyon sırasına göre döner.
    var enabledModulesInOrder: [String] {
        if let modules = settings?.modules, !modules.isEmpty {
            return modules
                .filter { $0.value.isEnabled }
                .sorted { $0.value.position < $1.value.position }
                .map { $0.key }
        }
        // Fallback: eski hardcoded sıra (modules gelmezse).
        return [
            "ana_mansetler_baslik",
            "ust_mansetler",
            "local_news",
            "yazarlar",
            "videolar",
            "galeriler",
            "trend_news",
            "featured",
            "five_headline",
            "biography",
            "interview"
        ]
    }

    /// Belirli modülün enabled durumunu döner. Modules yoksa flat-field fallback.
    func isModuleEnabled(_ key: String, fallback: Bool = true) -> Bool {
        if let modules = settings?.modules, !modules.isEmpty {
            return modules[key]?.isEnabled ?? false
        }
        return fallback
    }

    // MARK: - Widget Visibility (modules-first, flat-field fallback)
    var isSonDakikaEnabled: Bool { isModuleEnabled("son_dakika", fallback: settings?.isSonDakikaEnabled ?? true) }
    var isUstMansetlerEnabled: Bool { isModuleEnabled("ust_mansetler", fallback: settings?.isUstMansetlerEnabled ?? true) }
    var isAnasayfaYazarlarEnabled: Bool { isModuleEnabled("yazarlar", fallback: settings?.isAnasayfaYazarlarEnabled ?? true) }
    var isPiyasalarHavadurumuEnabled: Bool { settings?.isPiyasalarHavadurumuEnabled ?? true }
    var isHavadurumuEnabled: Bool { isModuleEnabled("havadurumu", fallback: settings?.isHavadurumuEnabled ?? true) }
    var isPiyasalarEnabled: Bool { isModuleEnabled("piyasalar", fallback: settings?.isPiyasalarEnabled ?? true) }
    var isAnasayfaVideolarEnabled: Bool { isModuleEnabled("videolar", fallback: settings?.isAnasayfaVideolarEnabled ?? true) }
    var isAnasayfaGalerilerEnabled: Bool { isModuleEnabled("galeriler", fallback: settings?.isAnasayfaGalerilerEnabled ?? true) }
    var isPuandurumuEnabled: Bool { isModuleEnabled("puandurumu", fallback: settings?.isPuandurumuEnabled ?? true) }
    var isAnaMansetlerBaslikEnabled: Bool { isModuleEnabled("ana_mansetler_baslik", fallback: settings?.isAnaMansetlerBaslikEnabled ?? true) }
    var isKategoriMansetlerBaslikEnabled: Bool { isModuleEnabled("kategori_mansetler_baslik", fallback: settings?.isKategoriMansetlerBaslikEnabled ?? true) }
    var isFeaturedEnabled: Bool { isModuleEnabled("featured", fallback: settings?.isFeaturedEnabled ?? true) }
    var isPrayerTimesEnabled: Bool { isModuleEnabled("prayer_times", fallback: settings?.isPrayerTimesEnabled ?? true) }
    var isBiographyEnabled: Bool {
        isModuleEnabled("biography", fallback: (settings?.mobileAppBiography?.lowercased() ?? "true") == "true")
    }
    var isInterviewEnabled: Bool {
        isModuleEnabled("interview", fallback: (settings?.mobileAppInterview?.lowercased() ?? "true") == "true")
    }
    
    // Widget Display Types
    var anasayfaYazarlarTipi: String { settings?.mobileAppAnasayfaYazarlarTipi ?? "vertical" }
    var anasayfaVideolarTipi: String { settings?.mobileAppAnasayfaVideolarTipi ?? "vertical" }
    var anasayfaGalerilerTipi: String { settings?.mobileAppAnasayfaGalerilerTipi ?? "vertical" }
    var digerHaberlerTipi: String { settings?.mobileAppDigerHaberlerTipi ?? "custom" }
    var onecikanlarTipi: String { settings?.mobileAppOnecikanlarTipi ?? "vertical" }
    var havaDurumuPiyasalarTipi: String { settings?.mobileAppHavaDurumuPiyasalarTipi ?? "vertical" }
    
    // Colors
    var primaryColor: Color { Color(hex: settings?.primaryColor ?? "#000000") }
    var barStyleColor: Color { Color(hex: settings?.mobileAppBarStyleColor ?? "#191a1f") }
    var barFontColor: Color { Color(hex: settings?.mobileAppBarFontColor ?? "#000000") }
    var menuFontColor: Color { Color(hex: settings?.mobileAppMenuFontColor ?? "#000000") }
    var menuStyleColor: Color { Color(hex: settings?.mobileAppMenuStyleColor ?? "#000000") }
    var titleFontColor: Color { Color(hex: settings?.titleFontColor ?? "#000000") }
    var fontColor: Color { Color(hex: settings?.fontColor ?? "#000000") }
    
    // Fonts
    var primaryFont: String { settings?.primaryFont ?? "Poppins-Regular" }
    var secondaryFont: String { settings?.secondaryFont ?? "Poppins-Bold" }
    var fontSize: CGFloat { CGFloat(settings?.fontSize ?? 10) }
    var detailTitleFontSize: CGFloat { CGFloat(settings?.detailTitleFontSize ?? 22) }
    var minFontSize: CGFloat { CGFloat(settings?.minFontSize ?? 10) }
    var maxFontSize: CGFloat { CGFloat(settings?.maxFontSize ?? 40) }
    
    // Layout
    var headlineHeight: CGFloat { CGFloat(settings?.mobileAppHeadlineHeight ?? 220) }
    var anaImagePercent: CGFloat { CGFloat(settings?.mobileAppAnaImagePercent ?? 60) / 100.0 }
    var headlineLimit: Int { settings?.mobileAppHeadlineLimit ?? 15 }
    
    // Status Bar
    var iosStatusBarStyle: UIStatusBarStyle {
        guard let style = settings?.mobileAppIosStatusBar?.lowercased() else {
            return .default
        }
        return style == "white" ? .lightContent : .darkContent
    }
    
    // Ad Units — Config.useAdMobTestIDs true ise test ID'leri döner (anasayfa banner'ları için)
    var iosBannerAdUnitId: String? {
        if Config.shared.useAdMobTestIDs { return Config.shared.adMobBannerUnitID }
        return settings?.mobileAppIosBanner
    }
    var androidBannerAdUnitId: String? { settings?.mobileAppAndroidBanner }
    var iosInterstitialAdUnitId: String? {
        if Config.shared.useAdMobTestIDs { return Config.shared.adMobInterstitialUnitID }
        return settings?.mobileAppIosInterstitial
    }
    var androidInterstitialAdUnitId: String? { settings?.mobileAppAndroidInterstitial }

    // MARK: - Resolved AdMob Unit IDs (tüm reklam bileşenleri bunları kullanır)
    //
    // Öncelik: 1) Config.useAdMobTestIDs → Google test ID  2) API (settings)
    // 3) .env (Config) gerçek ID  4) Google test ID (Config fallback).
    // Böylece AdMob unit ID'leri panelden (API) yönetilir; panel boşsa .env devreye girer.

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        return s
    }

    var resolvedBannerAdUnitId: String {
        if Config.shared.useAdMobTestIDs { return Config.shared.adMobBannerUnitID }
        return Self.nonEmpty(settings?.mobileAppIosBanner) ?? Config.shared.adMobBannerUnitID
    }

    var resolvedInterstitialAdUnitId: String {
        if Config.shared.useAdMobTestIDs { return Config.shared.adMobInterstitialUnitID }
        return Self.nonEmpty(settings?.mobileAppIosInterstitial) ?? Config.shared.adMobInterstitialUnitID
    }

    // OneSignal
    var onesignalAppId: String? { settings?.mobileOnesignalAppId }
    
    // Contact Info
    var adres: String? { settings?.adres }
    var telefon: String? { settings?.telefon }
    var adminmail: String? { settings?.adminmail }
    
    // Social Media
    var facebook: String? { settings?.facebook }
    var twitter: String? { settings?.twitter }
    var instagram: String? { settings?.instagram }
    var youtube: String? { settings?.youtube }
    var whatsapp: String? { settings?.whatsapp }
    
    // Links
    var tvLink: String? { settings?.tvLink }
    var fmLink: String? { settings?.fmLink }
    
    // Map
    var contactMap: String? { settings?.contactMap }
    
    // Footer
    var appFooterDescription: String? { settings?.appFooterDescription }
    
    private let apiService = APIService.shared
    
    private init() {
        Task {
            await loadSettings()
        }
    }
    
    func loadSettings() async {
        isLoading = true
        do {
            let response = try await apiService.fetchSettings()
            settings = response.data
            // Panel'den gelen tema renk/font değerlerini uygula.
            RemoteTheme.shared.update(from: response.data)
        } catch {
            // 500 hatası için daha detaylı log
            if let nsError = error as NSError?, nsError.code == 500 {
                AppLogger.api.error("Settings API 500 — using defaults")
            } else {
                AppLogger.api.error("Settings load failed — \(error.localizedDescription, privacy: .public)")
            }
            // Hata durumunda varsayılan ayarlar kullanılacak (settings nil kalacak)
        }
        isLoading = false
    }
}

// MARK: - Logo View Component
struct LogoView: View {
    @StateObject private var appSettings = AppSettings.shared

    /// Logo yüksekliği. Nav bar içinde ~50 ile sınırlıdır (üstü kırpılır); özel
    /// header'da (ör. ana sayfa) daha büyük verilebilir.
    var maxHeight: CGFloat = 50
    private var maxWidth: CGFloat { maxHeight * 4.8 }

    var body: some View {
        // Önce yerel icon görselini kontrol et (Assets'te "icon" olarak eklenmeli)
        if let localImage = UIImage(named: "icon") {
            Image(uiImage: localImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                .clipped()
        } else if let logoURL = appSettings.appLogo, let url = URL(string: logoURL) {
            // Yerel görsel yoksa API'den çek
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(.white)
                        .frame(width: 180, height: 44)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                        .clipped()
                case .failure:
                    Text(AppBranding.siteName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                @unknown default:
                    Text(AppBranding.siteName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: 200, maxHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        } else {
            // Hiçbiri yoksa text göster
            Text(AppBranding.siteName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                )
        }
    }
}
