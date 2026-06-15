//
//  AdBannerView.swift
//  YeniHaberler
//
//  AdMob Banner Reklam Bileşeni
//

import SwiftUI
import GoogleMobileAds
import UIKit

struct AdBannerView: UIViewRepresentable {
    let adUnitID: String
    /// Reklam yüklendi mi? (true: doldu, false: no-fill/hata). Boş slotu gizlemek için.
    var onLoad: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(onLoad: onLoad) }

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator

        // Root view controller'ı bul
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            bannerView.rootViewController = rootViewController
        }

        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // Güncelleme gerekmiyor
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        let onLoad: (Bool) -> Void
        init(onLoad: @escaping (Bool) -> Void) { self.onLoad = onLoad }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            onLoad(true)
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            onLoad(false)
        }
    }
}

// MARK: - Native AdMob Banner Yuvası
//
// AdMob banner'ı yalnızca gerçekten reklam DOLDUĞUNDA gösterir; no-fill/hata
// durumunda hiçbir şey çizmez (boş "REKLAM" etiketi bırakmaz).
struct AdMobBannerSlot: View {
    let adUnitID: String
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 4) {
            if loaded {
                Text("REKLAM")
                    .scaledFont(size: 9, weight: .heavy)
                    .tracking(1.4)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            AdBannerView(adUnitID: adUnitID, onLoad: { loaded = $0 })
                .frame(height: loaded ? 50 : 0)
        }
        .frame(maxHeight: loaded ? nil : 0)
        .padding(.vertical, loaded ? Theme.Spacing.lg : 0)
        .clipped()
    }
}
