//
//  AdBannerView.swift
//  YozgatHakimiyet
//
//  AdMob Banner Reklam Bileşeni
//

import SwiftUI
import GoogleMobileAds
import UIKit

struct AdBannerView: UIViewRepresentable {
    let adUnitID: String
    
    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        
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
}

// MARK: - AdMob Helper
class AdMobHelper {
    static let shared = AdMobHelper()
    
    private init() {}
    
    func initialize() {
        MobileAds.shared.start(completionHandler: { status in
            print("✅ AdMob initialized")
        })
    }
}
