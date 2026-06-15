import SwiftUI
import Combine

struct ServicesView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = ServicesViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Weather Widget
                    if let weatherToday = viewModel.weather.first {
                        WeatherWidget(weatherData: weatherToday)
                    }
                    
                    // Prayer Times Widget
                    if let prayerTimes = viewModel.prayerTimes {
                        PrayerTimesWidget(prayerTimes: prayerTimes)
                    }
                    
                    // Currency Widget
                    if !viewModel.currencies.isEmpty {
                        CurrencyWidget(currencies: Array(viewModel.currencies.prefix(6)))
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    LogoView()
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation {
                            showSideMenu.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .accessibilityLabel("Menüyü aç")
                    }
                }
            }
            .refreshable {
                await viewModel.loadAllServices()
            }
            .task {
                await viewModel.loadAllServices()
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Weather Widget
struct WeatherWidget: View {
    let weatherData: WeatherData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .foregroundColor(.blue)
                Text("Hava Durumu")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            
            HStack {
                // Current weather icon
                AsyncImage(url: URL(string: weatherData.image)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(weatherData.degree)°C")
                        .font(.system(size: 40, weight: .bold))
                    
                    Text(weatherData.desc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("↑ \(weatherData.high)°")
                        Text("↓ \(weatherData.low)°")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(.blue)
                        Text("\(weatherData.humidity)%")
                    }
                    
                    HStack {
                        Image(systemName: "wind")
                            .foregroundColor(.gray)
                        Text(weatherData.wind)
                    }
                }
                .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Prayer Times Widget
struct PrayerTimesWidget: View {
    let prayerTimes: PrayerTimesData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(.purple)
                Text("Namaz Vakitleri")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                PrayerTimeRow(name: "İmsak", time: prayerTimes.imsak)
                PrayerTimeRow(name: "Güneş", time: prayerTimes.gunes)
                PrayerTimeRow(name: "Öğle", time: prayerTimes.ogle)
                PrayerTimeRow(name: "İkindi", time: prayerTimes.ikindi)
                PrayerTimeRow(name: "Akşam", time: prayerTimes.aksam)
                PrayerTimeRow(name: "Yatsı", time: prayerTimes.yatsi)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Text(prayerTimes.tarihUzun)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
}

struct PrayerTimeRow: View {
    let name: String
    let time: String
    
    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text(time)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Currency Widget
struct CurrencyWidget: View {
    let currencies: [CurrencyData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                Text("Döviz Kurları")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(currencies) { currency in
                    CurrencyRow(currency: currency)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct CurrencyRow: View {
    let currency: CurrencyData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(currency.code)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(currency.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f ₺", currency.calculated))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Image(systemName: currency.changeDirection.icon)
                        .font(.caption2)
                    Text(String(format: "%.2f%%", abs(currency.rate)))
                        .font(.caption)
                }
                .foregroundColor(currency.changeDirection == .up ? .green : (currency.changeDirection == .down ? .red : .gray))
            }
        }
    }
}

// MARK: - ViewModel
@MainActor
class ServicesViewModel: ObservableObject {
    @Published var weather: [WeatherData] = []
    @Published var prayerTimes: PrayerTimesData?
    @Published var currencies: [CurrencyData] = []
    @Published var isLoading = false
    
    private let apiService = APIService.shared
    
    func loadAllServices() async {
        isLoading = true
        
        async let weatherResult = try? apiService.fetchWeather()
        async let prayerResult = try? apiService.fetchPrayerTimes()
        async let currencyResult = try? apiService.fetchCurrency()
        
        let (weather, prayer, currency) = await (weatherResult, prayerResult, currencyResult)
        
        if let weather = weather {
            self.weather = weather.data
        }
        
        if let prayer = prayer {
            self.prayerTimes = prayer.data
        }
        
        if let currency = currency {
            self.currencies = currency.data
        }
        
        isLoading = false
    }
}
