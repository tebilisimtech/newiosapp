//
//  InterstitialAdView.swift
//  YeniHaberler
//
//  AdMob Interstitial Reklam Bileşeni
//

import SwiftUI
import os
import GoogleMobileAds
import UIKit

// MARK: - Interstitial Ad Manager
class InterstitialAdManager {
    static let shared = InterstitialAdManager()
    
    private var interstitialAd: InterstitialAdWrapper?

    private init() {}

    @MainActor
    func loadInterstitial() {
        guard Config.shared.adsEnabled else { return }
        // Interstitial unit ID önce API'den (panel), yoksa .env/test.
        let adUnitID = AppSettings.shared.resolvedInterstitialAdUnitId
        let wrapper = InterstitialAdWrapper(adUnitID: adUnitID)
        interstitialAd = wrapper
        wrapper.load()
    }

    @MainActor
    func showInterstitial(from viewController: UIViewController) {
        guard Config.shared.adsEnabled else { return }
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
            AppLogger.ads.warning("App ID format detected — falling back to test interstitial ID")
            finalAdUnitID = "ca-app-pub-3940256099942544/4411468910"
        }

        let request = Request()
        InterstitialAd.load(with: finalAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                AppLogger.ads.error("Interstitial load failed — \(error.localizedDescription, privacy: .public)")
                return
            }

            guard let self = self else { return }

            Task { @MainActor in
                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
            }
        }
    }

    @MainActor
    func show(from viewController: UIViewController) {
        guard let ad = interstitialAd else {
            AppLogger.ads.notice("Interstitial not ready")
            return
        }

        ad.present(from: viewController)
    }

    // MARK: - FullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            self?.interstitialAd = nil
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor [weak self] in
            AppLogger.ads.error("Interstitial present failed — \(error.localizedDescription, privacy: .public)")
            self?.interstitialAd = nil
        }
    }
}
