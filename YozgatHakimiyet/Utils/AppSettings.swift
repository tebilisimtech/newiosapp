import SwiftUI
import Combine

// MARK: - App Settings Manager (Merkezi Logo Yönetimi)
@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var appLogo: String?
    @Published var isLoading = false
    
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
            appLogo = response.data.logoMobil
            print("✅ Settings loaded successfully - Logo: \(response.data.logoMobil ?? "nil")")
        } catch {
            // 500 hatası için daha detaylı log
            if let nsError = error as NSError?, nsError.code == 500 {
                print("⚠️ Settings API returned 500 error. Using default logo.")
            } else {
                print("⚠️ Error loading settings: \(error.localizedDescription)")
            }
            // Hata durumunda varsayılan logo kullanılacak (appLogo nil kalacak)
        }
        isLoading = false
    }
}

// MARK: - Logo View Component
struct LogoView: View {
    @StateObject private var appSettings = AppSettings.shared
    
    var body: some View {
        // Önce yerel icon görselini kontrol et (Assets'te "icon" olarak eklenmeli)
        if let localImage = UIImage(named: "icon") {
            Image(uiImage: localImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 200, maxHeight: 44)
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
                        .frame(maxWidth: 200, maxHeight: 44)
                        .clipped()
                case .failure:
                    Text("Yozgat Hakimiyet")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                @unknown default:
                    Text("Yozgat Hakimiyet")
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
            Text("Yozgat Hakimiyet")
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
