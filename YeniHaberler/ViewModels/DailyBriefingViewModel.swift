import Foundation
import Combine

@MainActor
final class DailyBriefingViewModel: ObservableObject {
    @Published var weather: WeatherData?
    @Published var prayerTimes: PrayerTimesData?
    @Published var topNews: [Post] = []
    @Published var currencies: [CurrencyData] = []
    @Published var featuredArticle: Article?
    @Published var recentMatches: [MatchFixture] = []
    @Published var sportsWeek: Int?
    @Published var isLoading = false

    private let api = APIService.shared

    /// Hava durumu/namaz vakti için şehir — Info.plist/.env'deki `CITY_NAME`'den gelir.
    /// `CITY_NAME` boşsa veya ülke geneli ("Türkiye") ise varsayılan olarak İstanbul.
    private var city: String {
        let configCity = TurkishCities.normalize(Config.shared.cityName)
        if configCity.isEmpty || configCity == "turkiye" {
            return "istanbul"
        }
        return configCity
    }

    func loadBriefing() async {
        isLoading = true

        async let weatherTask    = withTimeout(seconds: 8) { try await self.api.fetchWeather(city: self.city) }
        async let prayerTask     = withTimeout(seconds: 8) { try await self.api.fetchPrayerTimes(city: self.city) }
        async let popularTask    = withTimeout(seconds: 8) { try await self.api.fetchPopularPosts() }
        async let currencyTask   = withTimeout(seconds: 8) { try await self.api.fetchCurrency() }
        async let articleTask    = withTimeout(seconds: 8) { try await self.api.fetchArticlesFives(limit: 1) }
        async let fixtureTask    = withTimeout(seconds: 8) { try await self.api.fetchFixture(league: "super-lig") }

        let (weatherR, prayerR, popularR, currencyR, articleR, fixtureR) =
            await (weatherTask, prayerTask, popularTask, currencyTask, articleTask, fixtureTask)

        if let r = weatherR { weather = r.data.first }
        if let r = prayerR { prayerTimes = r.data }
        if let r = popularR { topNews = Array(r.data.prefix(5)) }
        if let r = currencyR {
            // Sadece USD, EUR, gram altın — hızlı bakış
            let wanted = ["USD", "EUR", "GRA", "ALTIN", "GLD"]
            currencies = r.data.filter { c in
                wanted.contains(where: { c.code.uppercased().contains($0) })
            }
            if currencies.isEmpty { currencies = Array(r.data.prefix(3)) }
        }
        if let r = articleR { featuredArticle = r.data.first }
        if let r = fixtureR {
            let all = MatchFixture.flatten(r.data)
            let (week, matches) = Self.lastWeekMatches(from: all)
            sportsWeek = week
            recentMatches = matches
        }

        isLoading = false
    }

    // MARK: - Sıradaki namaz vakti

    /// (vakit adı, kalan süre metni) — şu anki saate göre.
    var nextPrayer: (name: String, remaining: String)? {
        guard let p = prayerTimes else { return nil }
        let slots: [(String, String)] = [
            ("İmsak", p.imsak),
            ("Güneş", p.gunes),
            ("Öğle", p.ogle),
            ("İkindi", p.ikindi),
            ("Akşam", p.aksam),
            ("Yatsı", p.yatsi)
        ]

        let now = Date()
        let cal = Calendar.current
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)

        for (name, time) in slots {
            guard let mins = Self.minutes(from: time) else { continue }
            if mins > nowMinutes {
                let diff = mins - nowMinutes
                return (name, Self.formatRemaining(diff))
            }
        }
        // Tüm vakitler geçti → yarın imsak
        if let imsakMins = Self.minutes(from: p.imsak) {
            let diff = (24 * 60 - nowMinutes) + imsakMins
            return ("İmsak", Self.formatRemaining(diff))
        }
        return nil
    }

    private static func minutes(from hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    private static func formatRemaining(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h) sa \(m) dk" }
        return "\(m) dk"
    }

    /// Süper Lig'in en son oynanan haftası ve o haftanın maçları.
    /// "Son hafta" = tarihi bugüne eşit/önce olan en güncel maçın haftası
    /// (sezon başlamadıysa en küçük hafta numarası).
    private static func lastWeekMatches(from matches: [MatchFixture]) -> (week: Int?, matches: [MatchFixture]) {
        guard !matches.isEmpty else { return (nil, []) }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        let today = Date()

        // Oynanmış maçlar içinde en güncel tarihli olanın haftası.
        var latestPlayed: (week: String, date: Date)?
        for m in matches {
            guard let d = fmt.date(from: m.date), d <= today else { continue }
            if latestPlayed == nil || d > latestPlayed!.date {
                latestPlayed = (m.week, d)
            }
        }

        let targetWeek: String
        if let lp = latestPlayed {
            targetWeek = lp.week
        } else {
            // Henüz hiç maç oynanmadıysa en erken hafta.
            targetWeek = matches.compactMap { Int($0.week) }.min().map(String.init) ?? matches[0].week
        }

        let weekMatches = matches
            .filter { $0.week == targetWeek }
            .sorted { $0.date < $1.date }
        return (Int(targetWeek), weekMatches)
    }
}
