import Foundation
import os
import UIKit
import AppTrackingTransparency
import AdSupport

/// App Tracking Transparency (iOS 14.5+) yönetimi.
/// Reklam ve analitik SDK'larını ATT izni alındıktan sonra başlatmak için kullanılır.
@MainActor
final class ATTService {
    static let shared = ATTService()

    private init() {}

    /// Mevcut yetkilendirme durumunu döner (prompt göstermeden).
    var currentStatus: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    /// IDFA değerini döner (yetkilendirilmişse), aksi halde nil.
    var advertisingIdentifier: UUID? {
        guard currentStatus == .authorized else { return nil }
        return ASIdentifierManager.shared().advertisingIdentifier
    }

    /// Kullanıcının tracking izni vermiş mi (resmi sonuç bilinmiyorsa false).
    var isAuthorized: Bool {
        currentStatus == .authorized
    }

    /// ATT prompt'unu gösterir (eğer henüz sorulmamışsa) ve sonucu döner.
    ///
    /// - Important: iOS prompt'u sadece `.notDetermined` durumunda gösterir.
    ///   Daha önce sorulmuşsa mevcut durumu olduğu gibi döner.
    @discardableResult
    func requestAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        // notDetermined dışındaki durumlarda sistem prompt göstermez.
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        let status = await ATTrackingManager.requestTrackingAuthorization()
        let description = statusDescription(status)
        return status
    }

    /// Sistem ayarları > Gizlilik > Tracking ekranını açar.
    /// Kullanıcı daha önce reddetmişse buradan yeniden izin verebilir.
    func openSystemPrivacySettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Helpers
    private func statusDescription(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted:    return "restricted"
        case .denied:        return "denied"
        case .authorized:    return "authorized"
        @unknown default:    return "unknown"
        }
    }
}
