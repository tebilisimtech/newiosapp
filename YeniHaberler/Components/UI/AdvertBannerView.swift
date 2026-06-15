import SwiftUI
import Combine
import WebKit

// MARK: - Reklam Kanalları (placement id'leri)
//
// CMS'teki "Mobil Uygulama" reklam bölümleri. Her sabit bir API kanal id'sine
// karşılık gelir; panelde bu kanala atanan reklam ilgili yerde gösterilir.
enum AdChannel {
    // Ana Sayfa
    static let homeTopBanner = 2000
    /// Ana Sayfa akış reklamları #1–#11 (modüller arasına serpiştirilir).
    static let homeFeed: [Int] = Array(2001...2011)

    // Haber Detay
    static let postHero = 2012
    static let postTitle = 2013
    static let postContentMid = 2014
    static let postContentBottom = 2015
    static let postBeforeComments = 2016

    // Video Detay
    static let videoHero = 2017
    static let videoTitle = 2018
    static let videoContentBottom = 2019

    // Galeri Detay
    static let galleryHero = 2020
    static let galleryTitle = 2021
    static let galleryBetweenPhotos = 2022
    static let galleryBeforeComments = 2023

    // Video Listesi
    static let videoListInline = 2024

    // Interstitial
    static let splashInterstitial = 2025
}

// MARK: - Advert Banner View
//
// Verilen kanala (placement) atanmış özel reklamı gösterir.
// Öncelik: reklamda KOD varsa (AdMob web snippet / özel HTML) onu render eder;
// kod yoksa GÖRSEL + url'yi (tıklanınca açılır) gösterir. Atanmış reklam yoksa
// veya reklamlar kapalıysa hiçbir şey göstermez.
struct AdvertBannerView: View {
    let channel: Int
    var maxHeight: CGFloat = 160
    var cornerRadius: CGFloat = Theme.Radius.md

    @ObservedObject private var manager = AdvertManager.shared

    init(channel: Int, maxHeight: CGFloat = 160, cornerRadius: CGFloat = Theme.Radius.md) {
        self.channel = channel
        self.maxHeight = maxHeight
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if Config.shared.adsEnabled, let advert = manager.advert(forChannel: channel) {
                AdvertSlot(advert: advert, maxHeight: maxHeight, cornerRadius: cornerRadius)
            } else {
                EmptyView()
            }
        }
        .onAppear {
            guard Config.shared.adsEnabled else { return }
            manager.loadIfNeeded()
        }
    }
}

// MARK: - Reklam Yerleşimi
//
// Bir placement (kanal) için: panelden o kanala reklam atanmışsa gösterir
// (kod → AdMob unit ID ise native AdMob, değilse HTML; kod yoksa görsel + url).
// Reklam atanmamışsa HİÇBİR ŞEY göstermez (boş "REKLAM" etiketi bırakmaz).
struct AdPlacement: View {
    let channel: Int
    var body: some View { AdvertBannerView(channel: channel) }
}

// MARK: - Tek Reklam Yuvası
private struct AdvertSlot: View {
    let advert: AdvertItem
    let maxHeight: CGFloat
    let cornerRadius: CGFloat

    @State private var codeHeight: CGFloat = 90

    var body: some View {
        if let unitId = advert.admobUnitId {
            // Native AdMob — kendi "REKLAM" etiketini yönetir, dolmazsa gizlenir.
            AdMobBannerSlot(adUnitID: unitId)
                .padding(.horizontal, Theme.Spacing.xl)
        } else {
            VStack(spacing: 4) {
                Text("REKLAM")
                    .scaledFont(size: 9, weight: .heavy)
                    .tracking(1.4)
                    .foregroundColor(Theme.Colors.textTertiary)

                if let snippet = advert.snippet {
                    // KOD reklamı (özel HTML / AdSense web snippet)
                    AdvertCodeWebView(html: snippet, dynamicHeight: $codeHeight)
                        .frame(height: codeHeight)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                } else if let imageURL = advert.bestImage {
                    // GÖRSEL reklamı (tıklanınca url açılır)
                    imageBanner(imageURL: imageURL)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    @ViewBuilder
    private func imageBanner(imageURL: String) -> some View {
        let img = ThemedAsyncImage(url: imageURL, aspect: .fit)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: maxHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
            )

        if let urlString = advert.url, let url = URL(string: urlString) {
            Link(destination: url) { img }
                .buttonStyle(PlainButtonStyle())
        } else {
            img
        }
    }
}

// MARK: - Interstitial (tam ekran, #2025)
//
// Splash sonrası gösterilen özel tam-ekran reklam. Kod varsa kodu, yoksa
// görsel + url'yi gösterir. Kısa süre sonra kapatma (X) butonu aktifleşir.
struct AdvertInterstitialView: View {
    let advert: AdvertItem
    let onClose: () -> Void

    @State private var canClose = false
    @State private var codeHeight: CGFloat = 250

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // İçerik
            Group {
                if let snippet = advert.snippet {
                    AdvertCodeWebView(html: snippet, dynamicHeight: $codeHeight)
                        .frame(height: codeHeight)
                        .frame(maxWidth: .infinity)
                } else if let imageURL = advert.bestImage {
                    imageContent(imageURL: imageURL)
                }
            }
            .padding(Theme.Spacing.lg)

            // Kapat butonu
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.18)))
                    }
                    .opacity(canClose ? 1 : 0.35)
                    .disabled(!canClose)
                    .accessibilityLabel("Reklamı kapat")
                }
                Spacer()

                Text("REKLAM")
                    .scaledFont(size: 10, weight: .heavy)
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, Theme.Spacing.xl)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
        }
        .task {
            // 2 sn sonra kapatılabilir.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            canClose = true
        }
    }

    @ViewBuilder
    private func imageContent(imageURL: String) -> some View {
        let img = ThemedAsyncImage(url: imageURL, aspect: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))

        if let urlString = advert.url, let url = URL(string: urlString) {
            Link(destination: url) { img }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { onClose() })
        } else {
            img
        }
    }
}

// MARK: - Kod Reklamı WebView (dinamik yükseklik)
//
// Reklam HTML/JS kodunu (AdMob web snippet, özel banner vb.) render eder.
// İçerik yüklendikten sonra gerçek yüksekliği ölçüp binding'e yazar; böylece
// reklam ne çok kırpılır ne de boş alan bırakır.
private struct AdvertCodeWebView: UIViewRepresentable {
    let html: String
    @Binding var dynamicHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // baseURL = yayıncı domain'i (AdSense/AdMob web partner kuralları için).
        webView.loadHTMLString(Self.wrap(html), baseURL: URL(string: Config.shared.baseURL))
    }

    private static func wrap(_ inner: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
            html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
            * { max-width: 100%; }
            img { max-width: 100%; height: auto; display: block; margin: 0 auto; }
            iframe { max-width: 100%; border: 0; }
        </style>
        </head>
        <body>\(inner)</body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: AdvertCodeWebView
        init(_ parent: AdvertCodeWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            measure(webView, retriesLeft: 3)
        }

        /// Yükseklik ölç; reklam (AdMob) geç dolabileceği için birkaç kez dener.
        private func measure(_ webView: WKWebView, retriesLeft: Int) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                guard let self else { return }
                if let h = result as? CGFloat, h > 1 {
                    if abs(h - self.parent.dynamicHeight) > 1 {
                        self.parent.dynamicHeight = h
                    }
                }
                if retriesLeft > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.measure(webView, retriesLeft: retriesLeft - 1)
                    }
                }
            }
        }
    }
}
