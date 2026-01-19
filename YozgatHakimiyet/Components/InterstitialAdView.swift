//
//  InterstitialAdView.swift
//  YozgatHakimiyet
//
//  AdMob Interstitial Reklam Bileşeni
//

import SwiftUI
import GoogleMobileAds
import UIKit

// MARK: - Interstitial Ad Manager
class InterstitialAdManager {
    static let shared = InterstitialAdManager()
    
    private var interstitialAd: InterstitialAdWrapper?
    private var adUnitID: String {
        // Info.plist'ten oku veya test ID kullan
        if let adUnitID = Bundle.main.object(forInfoDictionaryKey: "ADMOB_INTERSTITIAL_UNIT_ID") as? String, !adUnitID.isEmpty {
            return adUnitID
        }
        // Test Unit ID (Google'ın test reklamı)
        return "ca-app-pub-3940256099942544/4411468910"
    }
    
    private init() {}
    
    @MainActor
    func loadInterstitial() {
        let wrapper = InterstitialAdWrapper(adUnitID: adUnitID)
        interstitialAd = wrapper
        wrapper.load()
    }
    
    @MainActor
    func showInterstitial(from viewController: UIViewController) {
        if let ad = interstitialAd, ad.isReady {
            ad.show(from: viewController)
            // Gösterildikten sonra yeni bir reklam yükle
            loadInterstitial()
        }
    }
}

// MARK: - Interstitial Ad Wrapper
class InterstitialAdWrapper: NSObject, FullScreenContentDelegate {
    private var interstitialAd: InterstitialAd?
    private let adUnitID: String
    
    @MainActor
    var isReady: Bool {
        return interstitialAd != nil
    }
    
    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
    }
    
    @MainActor
    func load() {
        // Ad unit ID kontrolü - App ID formatında ise test ID kullan
        var finalAdUnitID = adUnitID
        if adUnitID.contains("~") {
            // App ID formatında, test ID kullan
            print("⚠️ Interstitial: App ID formatı algılandı, test ID kullanılıyor")
            finalAdUnitID = "ca-app-pub-3940256099942544/4411468910"
        }
        
        let request = Request()
        InterstitialAd.load(with: finalAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("❌ Interstitial ad failed to load: \(error.localizedDescription)")
                print("⚠️ Ad Unit ID kontrol edin: \(finalAdUnitID)")
                return
            }
            
            guard let self = self else { return }
            
            Task { @MainActor in
                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
                print("✅ Interstitial ad loaded successfully")
            }
        }
    }
    
    @MainActor
    func show(from viewController: UIViewController) {
        guard let ad = interstitialAd else {
            print("⚠️ Interstitial ad is not ready")
            return
        }
        
        ad.present(from: viewController)
    }
    
    // MARK: - FullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            print("✅ Interstitial ad dismissed")
            self?.interstitialAd = nil
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor [weak self] in
            print("❌ Interstitial ad failed to present: \(error.localizedDescription)")
            self?.interstitialAd = nil
        }
    }
}
