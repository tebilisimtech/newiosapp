import Foundation

// MARK: - Weather Service
struct WeatherResponse: Codable {
    let data: [WeatherData]
    let error: Bool
    let message: String?
}

struct WeatherData: Codable, Identifiable {
    let dt: String
    let degree: Int
    let desc: String
    let pressure: String
    let humidity: Int
    let image: String
    let icon: String
    let wind: String
    let country: String
    let city: String
    let location: String
    let low: Int
    let high: Int
    
    var id: String { dt }
}

// MARK: - Prayer Times Service
struct PrayerTimesResponse: Codable {
    let data: PrayerTimesData
    let error: Bool
    let message: String?
}

struct PrayerTimesData: Codable {
    let tarih: String
    let tarihUzun: String
    let hicriTarih: String
    let imsak: String
    let gunes: String
    let ogle: String
    let ikindi: String
    let aksam: String
    let yatsi: String
    
    enum CodingKeys: String, CodingKey {
        case tarih
        case tarihUzun = "tarih_uzun"
        case hicriTarih = "hicri_tarih"
        case imsak, gunes, ogle, ikindi, aksam, yatsi
    }
}

// MARK: - Currency Service
struct CurrencyResponse: Codable {
    let data: [CurrencyData]
    let error: Bool
    let message: String?
}

struct CurrencyData: Codable, Identifiable {
    let name: String
    let code: String
    let buying: Double
    let buyingstr: String
    let selling: Double
    let sellingstr: String
    let rate: Double
    let time: String
    let date: String
    let datetime: String
    let calculated: Double
    
    var id: String { code }
    
    var changeDirection: ChangeDirection {
        if rate > 0 {
            return .up
        } else if rate < 0 {
            return .down
        } else {
            return .stable
        }
    }
    
    enum ChangeDirection {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "minus"
            }
        }
        
        var color: String {
            switch self {
            case .up: return "green"
            case .down: return "red"
            case .stable: return "gray"
            }
        }
    }
}

// MARK: - Sports Service (Standings)
struct StandingsResponse: Codable {
    let data: StandingsData
    let error: Bool
    let message: String?
}

// MARK: - Leagues List Response
//
// API tutarsız: bazen `{ "super-lig": { league: {...}, standings: [...] }, ... }` dict,
// bazen `[{ "slug": "super-lig", "id": 203 }, ...]` array döndürüyor.
// Custom decoder her iki yapıyı da `[String: StandingsData]` formuna indirgiyor.
struct LeaguesListResponse: Codable {
    let data: [String: StandingsData]
    let error: Bool
    let message: String?
    let errors: String?

    enum CodingKeys: String, CodingKey { case data, error, message, errors }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = (try? container.decode(Bool.self, forKey: .error)) ?? false
        message = try? container.decodeIfPresent(String.self, forKey: .message)
        errors = try? container.decodeIfPresent(String.self, forKey: .errors)

        if let dict = try? container.decode([String: StandingsData].self, forKey: .data) {
            data = dict
        } else if let array = try? container.decode([LeagueSlugRef].self, forKey: .data) {
            // Array formatı — minimal StandingsData üret (standings boş, league name slug'tan)
            var out: [String: StandingsData] = [:]
            for ref in array {
                let info = LeagueInfo(
                    name: LeagueSlugRef.displayName(for: ref.slug),
                    country: "Türkiye",
                    logo: nil,
                    flag: nil
                )
                out[ref.slug] = StandingsData(league: info, standings: [])
            }
            data = out
        } else {
            data = [:]
        }
    }
}

/// Yardımcı: `/services/standing/leagues` array varyantı için minimal kayıt.
struct LeagueSlugRef: Codable {
    let slug: String
    let id: Int?

    /// "super-lig" → "Süper Lig", "tff-1-lig" → "TFF 1. Lig" gibi okunur isim.
    static func displayName(for slug: String) -> String {
        switch slug {
        case "super-lig":           return "Süper Lig"
        case "tff-1-lig":           return "TFF 1. Lig"
        case "tff-2-lig-beyaz":     return "TFF 2. Lig Beyaz"
        case "tff-2-lig-kirmizi":   return "TFF 2. Lig Kırmızı"
        case "tff-3-lig-1-grup":    return "TFF 3. Lig 1. Grup"
        case "tff-3-lig-2-grup":    return "TFF 3. Lig 2. Grup"
        case "tff-3-lig-3-grup":    return "TFF 3. Lig 3. Grup"
        case "tff-3-lig-4-grup":    return "TFF 3. Lig 4. Grup"
        default:
            // Genel fallback: kelime başlarını büyüt
            return slug
                .replacingOccurrences(of: "-", with: " ")
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }
}

struct LeagueItem: Codable, Identifiable {
    let league: LeagueInfo
    let slug: String
    
    var id: String { slug }
    
    init(league: LeagueInfo, slug: String) {
        self.league = league
        self.slug = slug
    }
    
    // Slug'ı league name'den oluştur (küçük harf, tire ile)
    static func slugFromName(_ name: String) -> String {
        return name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "ğ", with: "g")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ç", with: "c")
    }
}

struct StandingsData: Codable {
    let league: LeagueInfo
    let standings: [TeamStanding]

    enum CodingKeys: String, CodingKey {
        case league
        // API v2: tekil "standing" key kullanıyor; modelde çoğul tutup mapliyoruz.
        case standings = "standing"
    }
}

struct LeagueInfo: Codable {
    let name: String
    let country: String
    let logo: String?
    let flag: String?
}

struct TeamStanding: Codable, Identifiable {
    let rank: Int
    let team: String
    let logo: String?
    let form: String?
    let played: Int
    let won: Int
    let drawn: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDifference: Int
    let points: Int
    let description: String?
    
    var id: String {
        "\(rank)-\(team)"
    }
    
    enum CodingKeys: String, CodingKey {
        case rank, team, logo, form, played
        case won = "win"
        case drawn = "draw"
        case lost = "lose"
        case goalsFor
        case goalsAgainst
        case goalDifference = "goalsDiff"
        case points, description
    }
}

// MARK: - Fixture Service
// API yapısı:
// data: {
//   info: { league, logo },
//   fixture: { weekNo: { "yyyy-MM-dd": [match] } }
// }

struct FixtureResponse: Codable {
    let data: FixtureData
    let error: Bool
    let message: String?

    enum CodingKeys: String, CodingKey { case data, error, message }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = (try? container.decode(Bool.self, forKey: .error)) ?? false
        message = try? container.decodeIfPresent(String.self, forKey: .message)
        // API tutarsız: veri varsa object, yoksa [] array dönüyor.
        if let value = try? container.decode(FixtureData.self, forKey: .data) {
            data = value
        } else {
            data = FixtureData(info: nil, fixture: [:])
        }
    }
}

struct FixtureData: Codable {
    let info: FixtureLeagueInfo?
    let fixture: [String: [String: [FixtureMatch]]]
}

struct FixtureLeagueInfo: Codable {
    let league: String?
    let logo: String?
}

struct FixtureMatch: Codable {
    let time: String?
    let stadium: String?
    let city: String?
    let round: String?
    let teams: [FixtureTeam]
    let score: String?
}

struct FixtureTeam: Codable {
    let id: Int?
    let name: String
    let logo: String?
    let goal: Int?
}

/// View tarafı için düzleştirilmiş tek maç temsili.
struct MatchFixture: Identifiable {
    let id: String
    let date: String           // "yyyy-MM-dd"
    let time: String
    let week: String
    let stadium: String?
    let homeTeam: String
    let awayTeam: String
    let homeLogo: String?
    let awayLogo: String?
    let homeScore: Int?
    let awayScore: Int?

    static func flatten(_ data: FixtureData) -> [MatchFixture] {
        var out: [MatchFixture] = []
        for (week, days) in data.fixture {
            for (date, matches) in days {
                for (idx, match) in matches.enumerated() {
                    guard match.teams.count >= 2 else { continue }
                    let home = match.teams[0]
                    let away = match.teams[1]
                    out.append(MatchFixture(
                        id: "w\(week)_\(date)_\(idx)",
                        date: date,
                        time: match.time ?? "",
                        week: week,
                        stadium: match.stadium,
                        homeTeam: home.name,
                        awayTeam: away.name,
                        homeLogo: home.logo,
                        awayLogo: away.logo,
                        homeScore: home.goal,
                        awayScore: away.goal
                    ))
                }
            }
        }
        return out.sorted { $0.date < $1.date }
    }
}

// MARK: - Earthquake Service (API v2)
/// GET /api/v2/services/earthquake/last — son depremler.
/// Yapı sunucudan dönen JSON'a göre uyarlanabilir.
struct EarthquakeResponse: Codable {
    let data: [EarthquakeData]
    let error: Bool
    let message: String?
}

struct EarthquakeData: Codable, Identifiable {
    let eventID: String?
    let date: String?            // "2026-05-13T13:33:50"
    let latitude: Double?
    let longitude: Double?
    let depth: Double?
    let magnitude: Double?
    let location: String?
    let province: String?
    let district: String?
    let neighborhood: String?
    let country: String?
    let type: String?            // ör. "ML"

    var id: String {
        if let eventID = eventID { return "eq_\(eventID)" }
        return [date, location].compactMap { $0 }.joined(separator: "_")
    }

    /// "2026-05-13T13:33:50" → "13.05.2026"
    var displayDate: String {
        guard let date = date, date.count >= 10 else { return "" }
        let parts = String(date.prefix(10)).split(separator: "-")
        if parts.count == 3 { return "\(parts[2]).\(parts[1]).\(parts[0])" }
        return String(date.prefix(10))
    }

    /// "2026-05-13T13:33:50" → "13:33"
    var displayTime: String {
        guard let date = date else { return "" }
        let comps = date.split(separator: "T")
        guard comps.count == 2 else { return "" }
        return String(comps[1].prefix(5))
    }

    /// Konum gösterimi: location > province/district kombinasyonu
    var displayLocation: String? {
        if let location = location, !location.isEmpty { return location }
        if let p = province, let d = district { return "\(d) (\(p))" }
        return province ?? district
    }

    enum CodingKeys: String, CodingKey {
        case eventID, date, latitude, longitude, depth, magnitude, location
        case province, district, neighborhood, country, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventID = try? container.decodeIfPresent(String.self, forKey: .eventID)
        date = try? container.decodeIfPresent(String.self, forKey: .date)
        latitude = EarthquakeData.flexibleDouble(container, key: .latitude)
        longitude = EarthquakeData.flexibleDouble(container, key: .longitude)
        depth = EarthquakeData.flexibleDouble(container, key: .depth)
        magnitude = EarthquakeData.flexibleDouble(container, key: .magnitude)
        location = try? container.decodeIfPresent(String.self, forKey: .location)
        province = try? container.decodeIfPresent(String.self, forKey: .province)
        district = try? container.decodeIfPresent(String.self, forKey: .district)
        neighborhood = try? container.decodeIfPresent(String.self, forKey: .neighborhood)
        country = try? container.decodeIfPresent(String.self, forKey: .country)
        type = try? container.decodeIfPresent(String.self, forKey: .type)
    }

    private static func flexibleDouble(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        if let dbl = try? container.decode(Double.self, forKey: key) { return dbl }
        if let str = try? container.decode(String.self, forKey: key) { return Double(str) }
        return nil
    }
}

// MARK: - Pharmacy Service
struct PharmacyResponse: Codable {
    let data: [PharmacyData]
    let error: Bool
    let message: String?
}

struct PharmacyData: Codable, Identifiable {
    let name: String
    let dist: String?
    let address: String
    let phone: String
    let loc: String?
    
    var id: String { name + (dist ?? "") }
    
    var district: String? { dist }
    
    var coordinates: (latitude: Double, longitude: Double)? {
        guard let loc = loc else { return nil }
        let parts = loc.split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]) else {
            return nil
        }
        return (lat, lon)
    }
}

// MARK: - Settings Service
struct SettingsResponse: Codable {
    let data: SettingsData
    let error: Bool
    let message: String?
}

/// Sunucu kontrollü ana sayfa modülü — `{ value, position }`.
/// `value` "true"/"false" string'i, `position` int (bazen string olarak gelebilir).
struct ModuleConfig: Codable {
    let value: String
    let position: Int

    var isEnabled: Bool { value.lowercased() == "true" }

    enum CodingKeys: String, CodingKey { case value, position }

    init(value: String, position: Int) {
        self.value = value
        self.position = position
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .value) {
            value = s
        } else if let b = try? c.decode(Bool.self, forKey: .value) {
            value = b ? "true" : "false"
        } else {
            value = "false"
        }
        if let i = try? c.decode(Int.self, forKey: .position) {
            position = i
        } else if let s = try? c.decode(String.self, forKey: .position), let i = Int(s) {
            position = i
        } else {
            position = .max
        }
    }
}

struct SettingsData: Codable {
    // Logo
    let logoMobil: String?
    
    // Widget Visibility Settings (Boolean as String "true"/"false")
    let mobileAppSonDakika: String?
    let mobileAppUstMansetler: String?
    let mobileAppAnasayfaYazarlar: String?
    let mobileAppPiyasalarHavadurumu: String?
    let mobileAppHavadurumu: String?
    let mobileAppPiyasalar: String?
    let mobileAppAnasayfaVideolar: String?
    let mobileAppAnasayfaGaleriler: String?
    let mobileAppPuandurumu: String?
    let mobileAppAnaMansetlerBaslik: String?
    let mobileAppKategoriMansetlerBaslik: String?
    let mobileAppBiography: String?
    let mobileAppInterview: String?
    let mobileAppFiveHeadline: String?
    let mobileAppDailyHeadline: String?
    let mobileAppFeatured: String?
    let mobileAppLocalNews: String?
    let mobileAppTrendNews: String?
    let mobileAppTabNews: String?
    let mobileAppPrayerTimes: String?
    
    // Widget Display Types
    let mobileAppAnasayfaYazarlarTipi: String?
    let mobileAppAnasayfaVideolarTipi: String?
    let mobileAppAnasayfaGalerilerTipi: String?
    let mobileAppDigerHaberlerTipi: String?
    let mobileAppOnecikanlarTipi: String?
    let mobileAppHavaDurumuPiyasalarTipi: String?
    
    // Color Settings
    let primaryColor: String?
    let mobileAppBarStyleColor: String?
    let mobileAppBarFontColor: String?
    let mobileAppMenuFontColor: String?
    let mobileAppMenuStyleColor: String?
    let titleFontColor: String?
    let fontColor: String?
    
    // Font Settings
    let primaryFont: String?
    let secondaryFont: String?
    let fontSize: Int?
    let detailTitleFontSize: Int?
    let minFontSize: Int?
    let maxFontSize: Int?
    
    // Layout Settings
    let mobileAppHeadlineHeight: Int?
    let mobileAppAnaImagePercent: Int?
    let mobileAppHeadlineLimit: Int?
    let mobileAppAnasayfaKategorilerIds: String?
    
    // Status Bar Style
    let mobileAppIosStatusBar: String?
    
    // Ad Unit IDs
    let mobileAppIosBanner: String?
    let mobileAppAndroidBanner: String?
    let mobileAppIosInterstitial: String?
    let mobileAppAndroidInterstitial: String?
    
    // OneSignal
    let mobileOnesignalAppId: String?
    
    // Contact Info
    let adres: String?
    let telefon: String?
    let adminmail: String?
    
    // Social Media
    let facebook: String?
    let twitter: String?
    let instagram: String?
    let youtube: String?
    let whatsapp: String?
    
    // Links
    let tvLink: String?
    let fmLink: String?
    
    // Map
    let contactMap: String?
    
    // Footer
    let appFooterDescription: String?

    // Modules — server-driven ana sayfa widget sırası ve görünürlüğü.
    // `{ key: { value: "true"/"false", position: Int } }` formatında gelir.
    let modules: [String: ModuleConfig]?

    enum CodingKeys: String, CodingKey {
        case logoMobil = "logo_mobil"
        case mobileAppSonDakika = "mobile_app_son_dakika"
        case mobileAppUstMansetler = "mobile_app_ust_mansetler"
        case mobileAppAnasayfaYazarlar = "mobile_app_anasayfa_yazarlar"
        case mobileAppPiyasalarHavadurumu = "mobile_app_piyasalar_havadurumu"
        case mobileAppHavadurumu = "mobile_app_havadurumu"
        case mobileAppPiyasalar = "mobile_app_piyasalar"
        case mobileAppAnasayfaVideolar = "mobile_app_anasayfa_videolar"
        case mobileAppAnasayfaGaleriler = "mobile_app_anasayfa_galeriler"
        case mobileAppPuandurumu = "mobile_app_puandurumu"
        case mobileAppAnaMansetlerBaslik = "mobile_app_ana_mansetler_baslik"
        case mobileAppKategoriMansetlerBaslik = "mobile_app_kategori_mansetler_baslik"
        case mobileAppBiography = "mobile_app_biography"
        case mobileAppInterview = "mobile_app_interview"
        case mobileAppFiveHeadline = "mobile_app_five_headline"
        case mobileAppDailyHeadline = "mobile_app_daily_headline"
        case mobileAppFeatured = "mobile_app_featured"
        case mobileAppLocalNews = "mobile_app_local_news"
        case mobileAppTrendNews = "mobile_app_trend_news"
        case mobileAppTabNews = "mobile_app_tab_news"
        case mobileAppPrayerTimes = "mobile_app_prayer_times"
        case mobileAppAnasayfaYazarlarTipi = "mobile_app_anasayfa_yazarlar_tipi"
        case mobileAppAnasayfaVideolarTipi = "mobile_app_anasayfa_videolar_tipi"
        case mobileAppAnasayfaGalerilerTipi = "mobile_app_anasayfa_galeriler_tipi"
        case mobileAppDigerHaberlerTipi = "mobile_app_diger_haberler_tipi"
        case mobileAppOnecikanlarTipi = "mobile_app_onecikanlar_tipi"
        case mobileAppHavaDurumuPiyasalarTipi = "mobile_app_hava_durumu_piyasalar_tipi"
        case primaryColor = "primary_color"
        case mobileAppBarStyleColor = "mobile_app_bar_style_color"
        case mobileAppBarFontColor = "mobile_app_bar_font_color"
        case mobileAppMenuFontColor = "mobile_app_menu_font_color"
        case mobileAppMenuStyleColor = "mobile_app_menu_style_color"
        case titleFontColor = "title_font_color"
        case fontColor = "font_color"
        case primaryFont = "primary_font"
        case secondaryFont = "secondary_font"
        case fontSize = "font_size"
        case detailTitleFontSize = "detail_title_font_size"
        case minFontSize = "min_font_size"
        case maxFontSize = "max_font_size"
        case mobileAppHeadlineHeight = "mobile_app_headline_height"
        case mobileAppAnaImagePercent = "mobile_app_ana_image_percent"
        case mobileAppHeadlineLimit = "mobile_app_headline_limit"
        case mobileAppAnasayfaKategorilerIds = "mobile_app_anasayfa_kategoriler_ids"
        case mobileAppIosStatusBar = "mobile_app_ios_status_bar"
        case mobileAppIosBanner = "mobile_app_ios_banner"
        case mobileAppAndroidBanner = "mobile_app_android_banner"
        case mobileAppIosInterstitial = "mobile_app_ios_interstitial"
        case mobileAppAndroidInterstitial = "mobile_app_android_interstitial"
        case mobileOnesignalAppId = "mobile_onesignal_app_id"
        case adres, telefon, adminmail
        case facebook, twitter, instagram, youtube, whatsapp
        case tvLink = "tv_link"
        case fmLink = "fm_link"
        case contactMap = "contact_map"
        case appFooterDescription = "app_footer_description"
        case modules
    }
    
    // Helper computed properties for boolean values
    var isSonDakikaEnabled: Bool {
        mobileAppSonDakika?.lowercased() == "true"
    }
    
    var isUstMansetlerEnabled: Bool {
        mobileAppUstMansetler?.lowercased() == "true"
    }
    
    var isAnasayfaYazarlarEnabled: Bool {
        mobileAppAnasayfaYazarlar?.lowercased() == "true"
    }
    
    var isPiyasalarHavadurumuEnabled: Bool {
        mobileAppPiyasalarHavadurumu?.lowercased() == "true"
    }
    
    var isHavadurumuEnabled: Bool {
        mobileAppHavadurumu?.lowercased() == "true"
    }
    
    var isPiyasalarEnabled: Bool {
        mobileAppPiyasalar?.lowercased() == "true"
    }
    
    var isAnasayfaVideolarEnabled: Bool {
        mobileAppAnasayfaVideolar?.lowercased() == "true"
    }
    
    var isAnasayfaGalerilerEnabled: Bool {
        mobileAppAnasayfaGaleriler?.lowercased() == "true"
    }
    
    var isPuandurumuEnabled: Bool {
        mobileAppPuandurumu?.lowercased() == "true"
    }
    
    var isAnaMansetlerBaslikEnabled: Bool {
        mobileAppAnaMansetlerBaslik?.lowercased() == "true"
    }
    
    var isKategoriMansetlerBaslikEnabled: Bool {
        mobileAppKategoriMansetlerBaslik?.lowercased() == "true"
    }
    
    var isFeaturedEnabled: Bool {
        mobileAppFeatured?.lowercased() == "true"
    }
    
    var isPrayerTimesEnabled: Bool {
        mobileAppPrayerTimes?.lowercased() == "true"
    }
}
