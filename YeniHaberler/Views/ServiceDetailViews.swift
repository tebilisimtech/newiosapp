import SwiftUI
import os
import Combine

// MARK: - Location Settings Helper
class LocationSettings: ObservableObject {
    static let shared = LocationSettings()
    
    @Published var selectedCity: String
    @Published var selectedDistrict: String?
    
    private let defaults = UserDefaults.standard
    
    private init() {
        self.selectedCity = defaults.string(forKey: "selectedCity") ?? "istanbul"
        self.selectedDistrict = defaults.string(forKey: "selectedDistrict")
    }
    
    func saveLocation(city: String, district: String?) {
        selectedCity = city.lowercased()
        selectedDistrict = district?.lowercased()
        
        defaults.set(selectedCity, forKey: "selectedCity")
        if let district = selectedDistrict {
            defaults.set(district, forKey: "selectedDistrict")
        } else {
            defaults.removeObject(forKey: "selectedDistrict")
        }
    }
}

// MARK: - Shared: Location Selector Button
//
// Hava / Namaz / Eczane detaylarında ortak kullanılan şehir-ilçe seçim butonu.
struct ServiceLocationButton: View {
    let city: String
    let district: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "location.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Brand.primary)
                Text(district == nil ? city.capitalized : "\(city.capitalized) · \(district!.capitalized)")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Text("Değiştir")
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundColor(Theme.Colors.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .fill(Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// "yyyy-MM-dd..." → Türkçe gün adı (ör. "Pazartesi"). İlk gün için "Bugün".
private func turkishWeekday(from dt: String, isToday: Bool) -> String {
    if isToday { return "Bugün" }
    let parts = String(dt.prefix(10)).split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return String(dt.prefix(10)) }
    var comps = DateComponents()
    comps.year = parts[0]; comps.month = parts[1]; comps.day = parts[2]
    guard let date = Calendar.current.date(from: comps) else { return String(dt.prefix(10)) }
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "tr_TR")
    fmt.dateFormat = "EEEE"
    return fmt.string(from: date).capitalized
}

// MARK: - Weather Detail View
struct WeatherDetailView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = WeatherDetailViewModel()
    @StateObject private var locationSettings = LocationSettings.shared
    @State private var showLocationPicker = false

    var body: some View {
        ZStack {
            Theme.Colors.groupedBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    ServiceLocationButton(
                        city: locationSettings.selectedCity,
                        district: locationSettings.selectedDistrict
                    ) { showLocationPicker = true }

                    if viewModel.isLoading && viewModel.weather.isEmpty {
                        ProgressView().padding(.top, 60)
                    } else if let current = viewModel.weather.first {
                        CurrentWeatherCard(weather: current)

                        if viewModel.weather.count > 1 {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                Text("GÜNLÜK TAHMİN")
                                    .scaledFont(size: 11, weight: .heavy)
                                    .tracking(1.2)
                                    .foregroundColor(Theme.Colors.textTertiary)

                                VStack(spacing: 0) {
                                    ForEach(Array(viewModel.weather.enumerated()), id: \.element.id) { index, weather in
                                        WeatherForecastRow(weather: weather, isToday: index == 0)
                                        if weather.id != viewModel.weather.last?.id {
                                            Divider().padding(.leading, Theme.Spacing.lg)
                                        }
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                                        .fill(Theme.Colors.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                                        .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
                                )
                            }
                        }
                    } else {
                        EmptyStateView(icon: "cloud.slash", title: "Veri Yok", message: "Hava durumu bilgisi alınamadı.")
                            .padding(.top, 40)
                    }
                }
                .padding(Theme.Spacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { LogoView() }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(isPresented: $showLocationPicker, needsDistrict: true) {
                Task { await viewModel.loadWeather() }
            }
        }
        .refreshable { await viewModel.loadWeather() }
        .task { await viewModel.loadWeather() }
    }
}

struct CurrentWeatherCard: View {
    let weather: WeatherData

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(weather.degree)°")
                        .scaledFont(size: 64, weight: .heavy, design: .rounded)
                        .foregroundColor(.white)
                    Text(weather.desc)
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.white.opacity(0.9))
                    if !weather.location.isEmpty {
                        Text(weather.location)
                            .scaledFont(size: 13, weight: .medium)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                Spacer()
                AsyncImage(url: URL(string: weather.image)) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.85))
                }
                .frame(width: 96, height: 96)
            }

            HStack(spacing: Theme.Spacing.sm) {
                weatherStat(icon: "thermometer.high", value: "\(weather.high)°", label: "En Yüksek")
                weatherStat(icon: "thermometer.low", value: "\(weather.low)°", label: "En Düşük")
                weatherStat(icon: "humidity.fill", value: "%\(weather.humidity)", label: "Nem")
            }

            HStack(spacing: Theme.Spacing.sm) {
                weatherStat(icon: "wind", value: weather.wind, label: "Rüzgar")
                weatherStat(icon: "gauge.medium", value: weather.pressure, label: "Basınç")
            }
        }
        .padding(Theme.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#2E6FD6"), Color(hex: "#1B3F87")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color(hex: "#1B3F87").opacity(0.25), radius: 16, x: 0, y: 8)
    }

    private func weatherStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text(value)
                .scaledFont(size: 15, weight: .bold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .scaledFont(size: 10, weight: .medium)
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Color.white.opacity(0.15))
        )
    }
}

struct WeatherForecastRow: View {
    let weather: WeatherData
    let isToday: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(turkishWeekday(from: weather.dt, isToday: isToday))
                .scaledFont(size: 14, weight: isToday ? .bold : .semibold)
                .foregroundColor(isToday ? Theme.Brand.primary : Theme.Colors.textPrimary)
                .frame(width: 92, alignment: .leading)

            AsyncImage(url: URL(string: weather.image)) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "cloud.fill").foregroundColor(Theme.Colors.textTertiary)
            }
            .frame(width: 34, height: 34)

            Text(weather.desc)
                .scaledFont(size: 12, weight: .regular)
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(weather.high)°")
                .scaledFont(size: 14, weight: .bold)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("\(weather.low)°")
                .scaledFont(size: 14, weight: .medium)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }
}

@MainActor
class WeatherDetailViewModel: ObservableObject {
    @Published var weather: [WeatherData] = []
    @Published var isLoading = false

    private let apiService = APIService.shared
    private let locationSettings = LocationSettings.shared

    func loadWeather() async {
        isLoading = true
        do {
            let normalizedCity = TurkishCities.normalize(locationSettings.selectedCity)
            let normalizedDistrict = locationSettings.selectedDistrict.map(TurkishCities.normalize)
            let response = try await apiService.fetchWeather(city: normalizedCity, district: normalizedDistrict)
            weather = response.data
        } catch {
            AppLogger.api.error("Weather load — \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}

// MARK: - Prayer Times Detail View

/// Tek namaz vakti temsili — view ve geri sayım hesabı için.
fileprivate struct PrayerSlot: Identifiable {
    let id = UUID()
    let name: String
    let time: String   // "HH:mm"
    let icon: String
}

fileprivate extension PrayerTimesData {
    var slots: [PrayerSlot] {
        [
            PrayerSlot(name: "İmsak", time: imsak, icon: "moon.stars.fill"),
            PrayerSlot(name: "Güneş", time: gunes, icon: "sunrise.fill"),
            PrayerSlot(name: "Öğle", time: ogle, icon: "sun.max.fill"),
            PrayerSlot(name: "İkindi", time: ikindi, icon: "sun.min.fill"),
            PrayerSlot(name: "Akşam", time: aksam, icon: "sunset.fill"),
            PrayerSlot(name: "Yatsı", time: yatsi, icon: "moon.fill")
        ]
    }
}

struct PrayerTimesDetailView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = PrayerTimesDetailViewModel()
    @StateObject private var locationSettings = LocationSettings.shared
    @State private var showLocationPicker = false

    var body: some View {
        ZStack {
            Theme.Colors.groupedBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    ServiceLocationButton(
                        city: locationSettings.selectedCity,
                        district: locationSettings.selectedDistrict
                    ) { showLocationPicker = true }

                    if let prayerTimes = viewModel.prayerTimes {
                        NextPrayerCard(prayerTimes: prayerTimes)

                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(prayerTimes.slots) { slot in
                                PrayerTimeDetailRow(
                                    slot: slot,
                                    isNext: slot.name == nextPrayerName(prayerTimes)
                                )
                            }
                        }

                        Text("\(prayerTimes.tarihUzun)  ·  \(prayerTimes.hicriTarih)")
                            .scaledFont(size: 12, weight: .medium)
                            .foregroundColor(Theme.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.xs)
                    } else if viewModel.isLoading {
                        ProgressView().padding(.top, 60)
                    } else {
                        EmptyStateView(icon: "moon.zzz", title: "Veri Yok", message: "Namaz vakitleri alınamadı.")
                            .padding(.top, 40)
                    }
                }
                .padding(Theme.Spacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { LogoView() }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(isPresented: $showLocationPicker, needsDistrict: true) {
                Task { await viewModel.loadPrayerTimes() }
            }
        }
        .refreshable { await viewModel.loadPrayerTimes() }
        .task { await viewModel.loadPrayerTimes() }
    }
}

// MARK: - Prayer time helpers (next prayer + countdown)

private func prayerDate(_ hhmm: String, on day: Date) -> Date? {
    let parts = hhmm.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2 else { return nil }
    return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
}

/// Bugünün vakitleri içinde şu andan sonraki ilk vakit; hepsi geçtiyse yarının imsağı.
private func nextPrayer(_ data: PrayerTimesData, now: Date = Date()) -> (slot: PrayerSlot, date: Date)? {
    for slot in data.slots {
        if let d = prayerDate(slot.time, on: now), d > now {
            return (slot, d)
        }
    }
    // Tüm vakitler geçti → yarın imsak
    if let imsak = data.slots.first,
       let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
       let d = prayerDate(imsak.time, on: tomorrow) {
        return (imsak, d)
    }
    return nil
}

private func nextPrayerName(_ data: PrayerTimesData) -> String? {
    nextPrayer(data)?.slot.name
}

struct NextPrayerCard: View {
    let prayerTimes: PrayerTimesData

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let next = nextPrayer(prayerTimes, now: context.date)
            VStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: next?.slot.icon ?? "moon.stars.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("SIRADAKİ VAKİT")
                        .scaledFont(size: 11, weight: .heavy)
                        .tracking(1.2)
                }
                .foregroundColor(.white.opacity(0.85))

                Text(next?.slot.name ?? "—")
                    .scaledFont(size: 30, weight: .heavy, design: .serif)
                    .foregroundColor(.white)

                Text(next?.slot.time ?? "")
                    .scaledFont(size: 16, weight: .bold)
                    .foregroundColor(.white.opacity(0.9))

                if let next = next {
                    Text(countdownText(to: next.date, from: context.date) + " kaldı")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.18)))
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.xl)
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.categoryPurple, Color(hex: "#3B1A6E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: Theme.Colors.categoryPurple.opacity(0.3), radius: 16, x: 0, y: 8)
        }
    }

    private func countdownText(to target: Date, from now: Date) -> String {
        let secs = max(0, Int(target.timeIntervalSince(now)))
        let h = secs / 3600, m = (secs % 3600) / 60, s = secs % 60
        if h > 0 { return String(format: "%d sa %02d dk", h, m) }
        return String(format: "%02d:%02d dk", m, s)
    }
}

struct PrayerTimeDetailRow: View {
    fileprivate let slot: PrayerSlot
    let isNext: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: slot.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isNext ? .white : Theme.Colors.categoryPurple)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(isNext ? Theme.Colors.categoryPurple : Theme.Colors.categoryPurple.opacity(0.12))
                )
            Text(slot.name)
                .scaledFont(size: 16, weight: isNext ? .bold : .semibold)
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
            Text(slot.time)
                .scaledFont(size: 18, weight: .heavy, design: .rounded)
                .foregroundColor(isNext ? Theme.Colors.categoryPurple : Theme.Colors.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(isNext ? Theme.Colors.categoryPurple.opacity(0.08) : Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(isNext ? Theme.Colors.categoryPurple.opacity(0.4) : Theme.Colors.borderSubtle, lineWidth: isNext ? 1 : 0.5)
        )
    }
}

@MainActor
class PrayerTimesDetailViewModel: ObservableObject {
    @Published var prayerTimes: PrayerTimesData?
    @Published var isLoading = false
    
    private let apiService = APIService.shared
    private let locationSettings = LocationSettings.shared
    
    func loadPrayerTimes() async {
        isLoading = true
        do {
            let normalizedCity = TurkishCities.normalize(locationSettings.selectedCity)
            let normalizedDistrict = locationSettings.selectedDistrict.map(TurkishCities.normalize)

            let response = try await apiService.fetchPrayerTimes(city: normalizedCity, district: normalizedDistrict)
            prayerTimes = response.data
        } catch {
            AppLogger.api.error("Prayer times load — \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}

// MARK: - Currency Detail View
struct CurrencyDetailView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = CurrencyDetailViewModel()

    var body: some View {
        ZStack {
            Theme.Colors.groupedBackground.ignoresSafeArea()

            ScrollView {
                if viewModel.isLoading && viewModel.currencies.isEmpty {
                    ProgressView().padding(.top, 60)
                } else if viewModel.currencies.isEmpty {
                    EmptyStateView(icon: "dollarsign.circle", title: "Veri Yok", message: "Döviz kurları alınamadı.")
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.currencies) { currency in
                            CurrencyDetailRow(currency: currency)
                        }
                    }
                    .padding(Theme.Spacing.xl)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { LogoView() }
        }
        .refreshable { await viewModel.loadCurrencies() }
        .task { await viewModel.loadCurrencies() }
    }
}

struct CurrencyDetailRow: View {
    let currency: CurrencyData

    private var trendColor: Color {
        switch currency.changeDirection {
        case .up: return Theme.Colors.success
        case .down: return Theme.Colors.danger
        case .stable: return Theme.Colors.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Kod rozeti
            Text(currency.code)
                .scaledFont(size: 13, weight: .heavy)
                .foregroundColor(Theme.Brand.primary)
                .frame(width: 52, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Theme.Brand.primary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(currency.name)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text("Alış \(currency.buyingstr) · Satış \(currency.sellingstr)")
                    .scaledFont(size: 11, weight: .regular)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.4f ₺", currency.calculated))
                    .scaledFont(size: 16, weight: .bold, design: .rounded)
                    .foregroundColor(Theme.Colors.textPrimary)

                HStack(spacing: 3) {
                    Image(systemName: currency.changeDirection.icon)
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "%.2f%%", abs(currency.rate)))
                        .scaledFont(size: 11, weight: .semibold)
                }
                .foregroundColor(trendColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(trendColor.opacity(0.12)))
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
        )
    }
}

@MainActor
class CurrencyDetailViewModel: ObservableObject {
    @Published var currencies: [CurrencyData] = []
    @Published var isLoading = false
    
    private let apiService = APIService.shared
    
    func loadCurrencies() async {
        isLoading = true
        do {
            let response = try await apiService.fetchCurrency()
            currencies = response.data
        } catch {
            AppLogger.api.error("Currency load — \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}

// MARK: - Pharmacy Detail View
struct PharmacyDetailView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = PharmacyDetailViewModel()
    @StateObject private var locationSettings = LocationSettings.shared
    @State private var showLocationPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Location selector
            Button(action: { showLocationPicker = true }) {
                HStack {
                    Image(systemName: "location.fill")
                    Text(locationSettings.selectedCity.capitalized)
                    if let district = locationSettings.selectedDistrict {
                        Text("/ \(district.capitalized)")
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .buttonStyle(PlainButtonStyle())
            
            List(viewModel.pharmacies) { pharmacy in
                PharmacyRow(pharmacy: pharmacy)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                LogoView()
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(isPresented: $showLocationPicker, needsDistrict: true) {
                Task {
                    await viewModel.loadPharmacies()
                }
            }
        }
        .task {
            await viewModel.loadPharmacies()
        }
    }
}

struct PharmacyRow: View {
    let pharmacy: PharmacyData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pharmacy.name)
                .font(.headline)
            
            Text(pharmacy.address)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let district = pharmacy.district {
                Text(district)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if !pharmacy.phone.isEmpty {
                let sanitized = pharmacy.phone.filter { $0.isNumber || $0 == "+" }
                if let phoneURL = URL(string: "tel://\(sanitized)") {
                    Link(destination: phoneURL) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text(pharmacy.phone)
                        }
                        .font(.subheadline)
                        .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class PharmacyDetailViewModel: ObservableObject {
    @Published var pharmacies: [PharmacyData] = []
    @Published var isLoading = false
    
    private let apiService = APIService.shared
    private let locationSettings = LocationSettings.shared
    
    func loadPharmacies() async {
        isLoading = true
        do {
            let normalizedCity = TurkishCities.normalize(locationSettings.selectedCity)
            let normalizedDistrict = locationSettings.selectedDistrict.map(TurkishCities.normalize)

            let response = try await apiService.fetchPharmacy(
                city: normalizedCity,
                district: normalizedDistrict
            )
            pharmacies = response.data
        } catch {
            AppLogger.api.error("Pharmacy load — \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}

// MARK: - Standings Detail View
struct StandingsDetailView: View {
    @Binding var showSideMenu: Bool
    @Binding var selectedTab: Int
    @StateObject private var viewModel = StandingsDetailViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // League Selector - Modern Design
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text("Lig Seçimi")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    // Custom Picker Button
                    Menu {
                        ForEach(viewModel.availableLeagues) { league in
                            Button(action: {
                                viewModel.selectedLeague = league.slug
                                Task {
                                    await viewModel.loadStandings(league: league.slug)
                                }
                            }) {
                                HStack {
                                    Text(league.league.name)
                                    if viewModel.selectedLeague == league.slug {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.currentLeagueName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.blue)
                                .rotationEffect(.degrees(viewModel.selectedLeague.isEmpty ? 0 : 0))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.blue.opacity(0.3),
                                                    Color.purple.opacity(0.2)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                        )
                        .shadow(color: Color.blue.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            Color(.systemGray6).opacity(0.5),
                            Color(.systemBackground)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Divider
                Divider()
                    .background(Color(.systemGray4))
                
                // Table Header
                HStack(spacing: 8) {
                    Text("Sıra")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 35)
                    
                    Text("Takım")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("O")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 25)
                    Text("G")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 25)
                    Text("B")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 25)
                    Text("M")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 25)
                    Text("A")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 30)
                    Text("Y")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 30)
                    Text("P")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 35)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGray5))
                
                // Teams
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if viewModel.standings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Puan durumu verisi bulunamadı")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(viewModel.standings) { team in
                        StandingsDetailRow(team: team, totalTeams: viewModel.standings.count)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                LogoView()
            }
        }
        .refreshable {
            await viewModel.loadStandings(league: viewModel.selectedLeague)
        }
        .task {
            await viewModel.loadAvailableLeagues()
            await viewModel.loadStandings(league: viewModel.selectedLeague)
        }
    }
}

struct StandingsDetailRow: View {
    let team: TeamStanding
    let totalTeams: Int
    
    var body: some View {
        HStack(spacing: 8) {
            // Rank
            Text("\(team.rank)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 35)
            
            // Team Logo
            if let logoURL = team.logo, let url = URL(string: logoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .frame(width: 24, height: 24)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    case .failure:
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .frame(width: 24, height: 24)
                    @unknown default:
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .frame(width: 24, height: 24)
                    }
                }
                .frame(width: 24, height: 24)
            } else {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
            }
            
            // Team Name
            Text(team.team)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            
            // Matches Played
            Text("\(team.played)")
                .font(.subheadline)
                .frame(width: 25)
            
            // Won
            Text("\(team.won)")
                .font(.subheadline)
                .foregroundColor(.green)
                .frame(width: 25)
            
            // Drawn
            Text("\(team.drawn)")
                .font(.subheadline)
                .foregroundColor(.orange)
                .frame(width: 25)
            
            // Lost
            Text("\(team.lost)")
                .font(.subheadline)
                .foregroundColor(.red)
                .frame(width: 25)
            
            // Goals For
            Text("\(team.goalsFor)")
                .font(.subheadline)
                .frame(width: 30)
            
            // Goal Difference
            Text("\(team.goalDifference >= 0 ? "+" : "")\(team.goalDifference)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(team.goalDifference >= 0 ? .green : .red)
                .frame(width: 30)
            
            // Points
            Text("\(team.points)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 35)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            team.rank <= 4 ? Color.blue.opacity(0.1) :
            team.rank <= 6 ? Color.orange.opacity(0.1) :
            team.rank >= totalTeams - 3 ? Color.red.opacity(0.1) :
            Color(.systemBackground)
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray5)),
            alignment: .bottom
        )
    }
}

@MainActor
class StandingsDetailViewModel: ObservableObject {
    @Published var standings: [TeamStanding] = []
    @Published var availableLeagues: [LeagueItem] = []
    @Published var selectedLeague: String = "super-lig"
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var currentLeagueName: String {
        availableLeagues.first(where: { $0.slug == selectedLeague })?.league.name ?? "Süper Lig"
    }
    
    private let apiService = APIService.shared
    
    func loadAvailableLeagues() async {
        do {
            let response = try await apiService.fetchAvailableLeagues()
            
            // Response'dan sadece lig bilgilerini çıkar
            // data dictionary'sinin key'leri lig slug'ları, value'ları StandingsData
            availableLeagues = response.data.map { (slug, standingsData) in
                LeagueItem(league: standingsData.league, slug: slug)
            }
            .sorted { $0.league.name < $1.league.name }
            
            // Süper Lig'i en başa taşı
            if let superLigIndex = availableLeagues.firstIndex(where: { $0.slug == "super-lig" }) {
                let superLig = availableLeagues.remove(at: superLigIndex)
                availableLeagues.insert(superLig, at: 0)
            }
            
            // Süper Lig'i default olarak seç
            if selectedLeague.isEmpty || !availableLeagues.contains(where: { $0.slug == selectedLeague }) {
                selectedLeague = "super-lig"
            }
        } catch {
            AppLogger.api.error("Leagues load — \(error.localizedDescription, privacy: .public)")
            // Hata durumunda en azından Süper Lig'i ekle
            let superLig = LeagueItem(
                league: LeagueInfo(name: "Süper Lig", country: "Turkey", logo: nil, flag: nil),
                slug: "super-lig"
            )
            availableLeagues = [superLig]
            selectedLeague = "super-lig"
        }
    }
    
    func loadStandings(league: String = "super-lig") async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.fetchStandings(league: league)
            standings = response.data.standings
            let count = standings.count
            if standings.isEmpty {
                errorMessage = "Puan durumu verisi bulunamadı"
            }
        } catch {
            errorMessage = "Puan durumu yüklenirken bir hata oluştu"
            AppLogger.api.error("Standings load — \(error.localizedDescription, privacy: .public)")
            if let decodingError = error as? DecodingError {
                AppLogger.api.error("Decoding — \(String(describing: decodingError), privacy: .public)")
            }
        }
        isLoading = false
    }
}

// MARK: - Location Picker View
struct LocationPickerView: View {
    @Binding var isPresented: Bool
    let needsDistrict: Bool
    @StateObject private var locationSettings = LocationSettings.shared
    @State private var selectedCity = "istanbul"
    @State private var selectedDistrict: String? = nil
    
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("İl Seçin")) {
                    Picker("İl", selection: $selectedCity) {
                        ForEach(TurkishCities.cityNames, id: \.self) { city in
                            Text(city.capitalized).tag(city)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                if needsDistrict, let cityDistricts = TurkishCities.cities[selectedCity], !cityDistricts.isEmpty {
                    Section(header: Text("İlçe Seçin (Opsiyonel)")) {
                        Picker("İlçe", selection: Binding(
                            get: { selectedDistrict ?? "" },
                            set: { selectedDistrict = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("Tümü").tag("")
                            ForEach(cityDistricts, id: \.self) { district in
                                Text(district.capitalized).tag(district)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section {
                    Button("Kaydet") {
                        locationSettings.saveLocation(city: selectedCity, district: needsDistrict ? selectedDistrict : nil)
                        isPresented = false
                        onSave()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Konum Seçimi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("İptal") {
                        isPresented = false
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            selectedCity = locationSettings.selectedCity
            selectedDistrict = locationSettings.selectedDistrict
        }
    }
}
