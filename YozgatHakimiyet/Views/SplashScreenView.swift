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
            // Arka plan
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // SplashIcon görseli göster
                Image("SplashIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
            }
        }
        .opacity(opacity)
        .onAppear {
            // Interstitial reklamı yükle (hata olsa bile devam et)
            Task { @MainActor in
                InterstitialAdManager.shared.loadInterstitial()
            }
            
            // Minimum gösterim süresi sonrası fade out ve reklam göster
            DispatchQueue.main.asyncAfter(deadline: .now() + minimumDisplayTime) {
                // Interstitial reklamı göster (hata olsa bile devam et)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    Task { @MainActor in
                        InterstitialAdManager.shared.showInterstitial(from: rootViewController)
                    }
                }
                
                // Reklam gösterildikten sonra fade out (reklam yoksa direkt geç)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        opacity = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isPresented = false
                    }
                }
            }
        }
    }
}
