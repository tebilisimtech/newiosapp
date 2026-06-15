import Foundation
import os
import UIKit
import AppTrackingTransparency

/// ATT izni alındıktan sonra tracking SDK'larını başlatan koordinatör.
/// Splash sonrası tek bir noktadan çağrılır — idempotent.
@MainActor
final class TrackingConsentCoordinator {
    static let shared = TrackingConsentCoordinator()

    private var hasInitializedSDKs = false

    private init() {}

    /// Tam consent akışı:
    ///   1) ATT prompt göster (iOS 14.5+)
    ///   2) UMP (GDPR) consent info update + form
    ///   3) AdMob SDK başlat
    ///   4) OneSignal başlat
    func requestConsentAndInitializeSDKs() async {
        guard !hasInitializedSDKs else { return }
        hasInitializedSDKs = true

        // 1) ATT prompt göster (sadece notDetermined ise gerçek prompt çıkar)
        _ = await ATTService.shared.requestAuthorization()

        // 2 + 3) UMP consent flow + AdMob SDK başlat
        await AdMobHelper.shared.prepareConsentAndStart()

        // 4) OneSignal başlat (IDFA bağımsız)
        OneSignalService.shared.initialize()

    }

    /// SDK'ları ATT prompt'u atlayarak başlat (mevcut izin durumuna göre).
    /// Re-launch sonrası veya tekrar açılışta kullanılır.
    func initializeSDKsIfNeeded() {
        guard !hasInitializedSDKs else { return }
        hasInitializedSDKs = true
        Task {
            await AdMobHelper.shared.prepareConsentAndStart()
            OneSignalService.shared.initialize()
        }
    }
}
