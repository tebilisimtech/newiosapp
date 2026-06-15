import Foundation
import os
import UIKit
import GoogleMobileAds

#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

/// AdMob başlatma + Google UMP (GDPR/EU consent) entegrasyonu.
///
/// Doğru başlatma sırası:
///   1. ATT izni iste (iOS 14.5+)
///   2. UMP consent durumunu güncelle
///   3. Gerekirse UMP consent formunu göster
///   4. AdMob SDK'sını başlat (sadece consent OK olunca)
///
/// Bu sınıf `TrackingConsentCoordinator` tarafından çağrılır.
@MainActor
final class AdMobHelper {
    static let shared = AdMobHelper()

    private var hasStartedSDK = false
    private var isPreparingConsent = false

    private init() {}

    // MARK: - Public API

    /// Eski API uyumluluğu — UMP olmadan direkt başlat.
    /// `TrackingConsentCoordinator.initializeSDKsIfNeeded()` tarafından çağrılır.
    func initialize() {
        Task { await prepareConsentAndStart() }
    }

    /// Consent akışını tamamla ve SDK'yı başlat.
    /// Tekrar çağrılırsa idempotent — sadece bir kez SDK başlatır.
    /// `Config.adsEnabled` false ise SDK/UMP hiç başlatılmaz.
    func prepareConsentAndStart() async {
        guard Config.shared.adsEnabled else { return }
        guard !hasStartedSDK, !isPreparingConsent else { return }
        isPreparingConsent = true
        defer { isPreparingConsent = false }

        #if canImport(UserMessagingPlatform)
        await runUMPFlow()
        #endif

        startMobileAdsIfNeeded()
    }

    /// Settings'ten "Reklam İzinlerini Yönet" tıklanınca privacy options formu göster.
    func presentPrivacyOptionsForm(from viewController: UIViewController) {
        #if canImport(UserMessagingPlatform)
        ConsentForm.presentPrivacyOptionsForm(from: viewController) { error in
            if let error = error {
                AppLogger.ads.error("UMP privacy options form — \(error.localizedDescription, privacy: .public)")
            }
        }
        #endif
    }

    /// Privacy options'in UI'da gösterilip gösterilmeyeceği (button'u gizlemek için).
    var privacyOptionsRequired: Bool {
        #if canImport(UserMessagingPlatform)
        return ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #else
        return false
        #endif
    }

    // MARK: - Private

    private func startMobileAdsIfNeeded() {
        guard !hasStartedSDK else { return }
        hasStartedSDK = true

        MobileAds.shared.start { _ in
        }
    }

    #if canImport(UserMessagingPlatform)
    private func runUMPFlow() async {
        let parameters = RequestParameters()
        // Production'da bu kapalı, sadece debug için açılır:
        // parameters.debugSettings = configureDebugSettings()

        // 1) Consent info update
        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error = error {
                    AppLogger.ads.warning("UMP consent info update — \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume()
            }
        }

        // 2) Consent form gerekirse otomatik göster
        guard let rootVC = Self.topViewController() else { return }
        await withCheckedContinuation { continuation in
            ConsentForm.loadAndPresentIfRequired(from: rootVC) { error in
                if let error = error {
                    AppLogger.ads.warning("UMP form load — \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume()
            }
        }

        // 3) canRequestAds doğrulaması (consent verilmediyse reklam istenmemeli)
    }

    /// Sadece DEBUG'da çağrılacak — geography .EEA ile form testi.
    private func configureDebugSettings() -> DebugSettings {
        let debug = DebugSettings()
        debug.geography = .EEA
        // Test cihaz hash'ini gerçek cihaz log'undan alarak ekleyebilirsiniz.
        // debug.testDeviceIdentifiers = ["TEST_DEVICE_HASH"]
        return debug
    }
    #endif

    // MARK: - Top view controller helper
    private static func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow })
                ?? windowScene.windows.first,
              var top = window.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
