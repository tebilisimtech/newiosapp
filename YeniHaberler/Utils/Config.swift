import Foundation
import os

class Config {
    static let shared = Config()
    
    private init() {
        loadEnvironmentVariables()
    }
    
    var baseURL: String = ""
    var apiKey: String = ""

    /// White-label marka bilgisi. API settings döndürmediği için Info.plist/.env'den
    /// okunur. Her müşteri sitesi için BASE_URL/API_KEY ile birlikte değiştirilir.
    var siteName: String = ""
    var cityName: String = ""

    /// Açılış (splash) ekranının arka plan rengi — hex. Info.plist `SPLASH_BG_COLOR`
    /// anahtarından okunur; white-label her site için buradan değiştirilir.
    /// Not: Uygulama açılmadan ÖNCEKİ sistem launch ekranının rengi ayrıca
    /// Assets → `LaunchBackground` renk setinden ayarlanır (ikisini eşitlemek iyi olur).
    var splashBackgroundHex: String = "#FFFFFF"

    /// Haber/video/galeri/makale detayının nasıl açılacağı.
    /// - `.native`: uygulama içi native ekran (varsayılan, zengin deneyim)
    /// - `.web`: SFSafariViewController ile site sayfası (BİK trafiği için —
    ///   site analytics/cookie/reklam çalışır, gerçek ziyaret sayılır)
    enum ArticleOpenMode: String {
        case native
        case web
    }
    var articleOpenMode: ArticleOpenMode = .native

    // MARK: - 3rd-party Credentials
    // Bu değerler artık `.env` dosyasından okunur (gitignored). Info.plist'te
    // tutulmazlar çünkü repo açık olduğunda credentials sızar.
    var oneSignalAppId: String = ""
    private var adMobBannerUnitIDFromEnv: String = ""
    private var adMobInterstitialUnitIDFromEnv: String = ""

    // MARK: - Ads Master Switch
    /// Tüm reklam alanlarını ve AdMob/UMP SDK initialization'ını kontrol eden tek anahtar.
    /// `false` iken: AdSlot/AdBannerView/AdvertBannerView/HomeAdSlot EmptyView döner,
    /// Interstitial yüklenmez, AdMob SDK başlatılmaz, UMP consent flow atlanır.
    ///
    /// Production'da AdMob hesabı onay alınca `true` yapıp tek satırla aktive edilir.
    var adsEnabled: Bool = true

    // MARK: - AdMob Test Mode
    /// AdMob hesabı onay sürecindeyken `true` tutulur — tüm reklam yerlerinde Google'ın
    /// resmi test ID'leri kullanılır (kazanç oluşturmaz ama yerleşimleri test edebilirsin).
    ///
    /// Hesap onaylandıktan sonra `false` yap → .env'deki gerçek Unit ID'ler ve
    /// API'den gelen `iosBannerAdUnitId` devreye girer.
    ///
    /// Google test ID'leri için: https://developers.google.com/admob/ios/test-ads
    var useAdMobTestIDs: Bool = false

    // MARK: - AdMob Unit ID'leri
    // Google resmi test Unit ID'leri inline (https://developers.google.com/admob/ios/test-ads)
    static let adMobTestBannerID = "ca-app-pub-3940256099942544/2934735716"
    static let adMobTestInterstitialID = "ca-app-pub-3940256099942544/4411468910"

    var adMobBannerUnitID: String {
        if useAdMobTestIDs { return Self.adMobTestBannerID }
        return adMobBannerUnitIDFromEnv.isEmpty ? Self.adMobTestBannerID : adMobBannerUnitIDFromEnv
    }

    var adMobInterstitialUnitID: String {
        if useAdMobTestIDs { return Self.adMobTestInterstitialID }
        return adMobInterstitialUnitIDFromEnv.isEmpty ? Self.adMobTestInterstitialID : adMobInterstitialUnitIDFromEnv
    }

    private func loadEnvironmentVariables() {
        // İki kaynak: Info.plist (public/white-label config) → .env (secrets, gitignored).
        // Secret değerler (API_KEY, ONESIGNAL_APP_ID, ADMOB_*_UNIT_ID) sadece .env'den okunur.

        // 1) Info.plist'ten public config oku
        if let baseURLFromPlist = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String, !baseURLFromPlist.isEmpty {
            baseURL = baseURLFromPlist
        }
        if let s = Bundle.main.object(forInfoDictionaryKey: "SITE_NAME") as? String, !s.isEmpty {
            siteName = s
        }
        if let c = Bundle.main.object(forInfoDictionaryKey: "CITY_NAME") as? String, !c.isEmpty {
            cityName = c
        }
        if let bg = Bundle.main.object(forInfoDictionaryKey: "SPLASH_BG_COLOR") as? String, !bg.isEmpty {
            splashBackgroundHex = bg
        }
        if let m = Bundle.main.object(forInfoDictionaryKey: "ARTICLE_OPEN_MODE") as? String,
           let mode = ArticleOpenMode(rawValue: m.lowercased()) {
            articleOpenMode = mode
        }

        // 2) .env dosyasını oku (önce bundle, sonra proje kök dev fallback'i)
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil) {
            loadFromEnvFile(path: envPath)
        } else {
            let projectRoot = FileManager.default.currentDirectoryPath
            let envPath = "\(projectRoot)/.env"
            if FileManager.default.fileExists(atPath: envPath) {
                loadFromEnvFile(path: envPath)
            }
        }

        // 3) Validasyon: gerekli değerler yoksa DEBUG'da uyar, RELEASE'de fallback.
        if baseURL.isEmpty {
            #if DEBUG
            assertionFailure("⚠️ BASE_URL boş. Info.plist'e ekleyin.")
            #endif
            baseURL = "https://www.yenihaberler.com.tr"
        }

        if apiKey.isEmpty {
            #if DEBUG
            assertionFailure("""
                ⚠️ API_KEY boş. Proje kökündeki `.env` dosyasını oluşturun (örnek: .env.example).
                Talimat için README.md → 'İlk Kurulum' bölümüne bakın.
                """)
            #endif
            // RELEASE'de API key olmadan çalışmak anlamsız — sessiz fail, API hataları zaten loglanır.
            apiKey = ""
        }

        if oneSignalAppId.isEmpty {
            AppLogger.app.notice("ONESIGNAL_APP_ID missing in .env — push notifications disabled")
        }
    }

    private func loadFromEnvFile(path: String) {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                guard trimmedLine.contains("="), !trimmedLine.hasPrefix("#") else { continue }

                let parts = trimmedLine.components(separatedBy: "=")
                guard parts.count >= 2 else { continue }

                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                guard !value.isEmpty else { continue }

                switch key {
                case "BASE_URL" where baseURL.isEmpty:
                    baseURL = value
                case "API_KEY" where apiKey.isEmpty:
                    apiKey = value
                case "SITE_NAME" where siteName.isEmpty:
                    siteName = value
                case "CITY_NAME" where cityName.isEmpty:
                    cityName = value
                case "ARTICLE_OPEN_MODE":
                    if let mode = ArticleOpenMode(rawValue: value.lowercased()) {
                        articleOpenMode = mode
                    }
                case "ONESIGNAL_APP_ID" where oneSignalAppId.isEmpty:
                    oneSignalAppId = value
                case "ADMOB_BANNER_UNIT_ID" where adMobBannerUnitIDFromEnv.isEmpty:
                    adMobBannerUnitIDFromEnv = value
                case "ADMOB_INTERSTITIAL_UNIT_ID" where adMobInterstitialUnitIDFromEnv.isEmpty:
                    adMobInterstitialUnitIDFromEnv = value
                default:
                    break
                }
            }
        } catch {
            AppLogger.app.error(".env load failed — \(error.localizedDescription, privacy: .public)")
        }
    }
}

