import SwiftUI
import UIKit
import ImageIO
import GoogleMobileAds

// MARK: - GIF Image View
struct GIFImageView: UIViewRepresentable {
    let gifName: String
    let duration: TimeInterval
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        
        // GIF'i yükle
        if let gifURL = Bundle.main.url(forResource: gifName, withExtension: "gif") {
            if let gifData = try? Data(contentsOf: gifURL) {
                imageView.image = UIImage.animatedImage(withAnimatedGIFData: gifData)
            }
        } else if let gifPath = Bundle.main.path(forResource: gifName, ofType: "gif") {
            if let gifData = try? Data(contentsOf: URL(fileURLWithPath: gifPath)) {
                imageView.image = UIImage.animatedImage(withAnimatedGIFData: gifData)
            }
        }
        
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Güncelleme gerekmiyor
    }
}

// MARK: - UIImage Extension for GIF
extension UIImage {
    static func animatedImage(withAnimatedGIFData data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var duration: Double = 0
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let image = UIImage(cgImage: cgImage)
                images.append(image)
                
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any] {
                    let gifKey = kCGImagePropertyGIFDictionary as String
                    if let gifProperties = properties[gifKey] as? [String: Any] {
                        let delayTimeKey = kCGImagePropertyGIFDelayTime as String
                        if let delayTime = gifProperties[delayTimeKey] as? Double {
                            duration += delayTime
                        } else {
                            // Default delay if not specified
                            duration += 0.1
                        }
                    } else {
                        duration += 0.1
                    }
                } else {
                    duration += 0.1
                }
            }
        }
        
        if images.isEmpty {
            return nil
        }
        
        return UIImage.animatedImage(with: images, duration: duration)
    }
}

// MARK: - Splash Screen View
struct SplashScreenView: View {
    @Binding var isPresented: Bool
    @State private var opacity: Double = 1.0
    let minimumDisplayTime: TimeInterval
    
    init(isPresented: Binding<Bool>, minimumDisplayTime: TimeInterval = 2.0) {
        self._isPresented = isPresented
        self.minimumDisplayTime = minimumDisplayTime
    }
    
    var body: some View {
        ZStack {
            // Arka plan — solma animasyonuna dahil DEĞİL; tam opak kalır ki splash
            // kaybolurken altındaki pencere arka planı görünmesin.
            // Renk Info.plist `SPLASH_BG_COLOR`'dan gelir (Config.splashBackgroundHex).
            Color(hex: Config.shared.splashBackgroundHex)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // SplashIcon görseli göster
                Image("SplashIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 240, height: 240)
            }
            // Sadece logo solar; arka plan siyah kalır.
            .opacity(opacity)
        }
        .task {
            await runSplashSequence()
        }
    }

    // MARK: - Splash Sequence
    @MainActor
    private func runSplashSequence() async {
        // 1) 1.5 saniye UI nefes alsın, kullanıcı logoyu görsün
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // 2) ATT/AdMob/OneSignal — sadece onboarding tamamlandıysa burada başlat.
        // İlk açılışta consent akışı OnboardingView'in son sayfasında yapılır,
        // splash burada SDK promptlarını tetiklemez.
        if UserPreferences.shared.hasCompletedOnboarding {
            await TrackingConsentCoordinator.shared.requestConsentAndInitializeSDKs()
        }

        // 3) Interstitial reklamı önyükle (SDK artık hazır)
        InterstitialAdManager.shared.loadInterstitial()

        // 4) Minimum gösterim süresine ulaşmak için kalan süreyi bekle
        let elapsed: TimeInterval = 1.5
        let remaining = max(0, minimumDisplayTime - elapsed)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }

        // 5) Interstitial — önce panelden özel reklam (#2025), yoksa AdMob.
        if Config.shared.adsEnabled {
            await AdvertManager.shared.ensureLoaded()
            if let advert = AdvertManager.shared.advert(forChannel: AdChannel.splashInterstitial) {
                // Özel interstitial: MainView fullScreenCover ile gösterir.
                AdvertManager.shared.pendingInterstitial = advert
            } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController {
                InterstitialAdManager.shared.showInterstitial(from: rootViewController)
            }
        }

        // 6) Kısa bekleme — reklamın görünmesi için
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 7) Fade out + dismiss
        withAnimation(.easeOut(duration: 0.5)) {
            opacity = 0
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        isPresented = false
    }
}
