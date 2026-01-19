import Foundation

class Config {
    static let shared = Config()
    
    private init() {
        loadEnvironmentVariables()
    }
    
    var baseURL: String = ""
    var apiKey: String = ""
    
    // AdMob Unit ID'leri
    var adMobBannerUnitID: String {
        // Info.plist'ten oku veya test ID kullan
        if let adUnitID = Bundle.main.object(forInfoDictionaryKey: "ADMOB_BANNER_UNIT_ID") as? String, !adUnitID.isEmpty {
            return adUnitID
        }
        // Test Unit ID (Google'ın test reklamı)
        return "ca-app-pub-3940256099942544/2934735716"
    }
    
    var adMobInterstitialUnitID: String {
        // Info.plist'ten oku veya test ID kullan
        if let adUnitID = Bundle.main.object(forInfoDictionaryKey: "ADMOB_INTERSTITIAL_UNIT_ID") as? String, !adUnitID.isEmpty {
            return adUnitID
        }
        // Test Unit ID (Google'ın test reklamı)
        return "ca-app-pub-3940256099942544/4411468910"
    }
    
    private func loadEnvironmentVariables() {
        // Önce Info.plist'ten oku
        if let baseURLFromPlist = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String {
            baseURL = baseURLFromPlist
        }
        
        if let apiKeyFromPlist = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String {
            apiKey = apiKeyFromPlist
        }
        
        // Eğer Info.plist'te yoksa, .env dosyasından oku
        if baseURL.isEmpty || apiKey.isEmpty {
            if let envPath = Bundle.main.path(forResource: ".env", ofType: nil) {
                loadFromEnvFile(path: envPath)
            } else {
                // Proje kök dizinindeki .env dosyasını dene
                let projectRoot = FileManager.default.currentDirectoryPath
                let envPath = "\(projectRoot)/.env"
                if FileManager.default.fileExists(atPath: envPath) {
                    loadFromEnvFile(path: envPath)
                }
            }
        }
        
        // Hala boşsa fallback değerler
        if baseURL.isEmpty {
            baseURL = "https://www.yozgathakimiyet.com.tr"
        }
        
        if apiKey.isEmpty {
            apiKey = "vD3CUfsWewPIqIhZmNYDVDdYft9nIEHXeuMI8wPI23c2e7ba"
        }
    }
    
    private func loadFromEnvFile(path: String) {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                if trimmedLine.contains("=") && !trimmedLine.starts(with: "#") {
                    let parts = trimmedLine.components(separatedBy: "=")
                    if parts.count >= 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespaces)
                        let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                        
                        if key == "BASE_URL" && baseURL.isEmpty {
                            baseURL = value
                        } else if key == "API_KEY" && apiKey.isEmpty {
                            apiKey = value
                        }
                    }
                }
            }
        } catch {
            print("Error loading .env file: \(error)")
        }
    }
}

