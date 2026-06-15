import SwiftUI
import Combine

// MARK: - Section View
//
// Servisler (hava, namaz, döviz, eczane) hızlı erişim grid'i. Data fetch
// yapmaz; sadece AppSettings toggle'larına göre hangi tile'lar görünür
// onu belirler. AppSettings boş ise bütün tile'lar görünür (default).
struct QuickAccessSection: View {
    @ObservedObject private var appSettings = AppSettings.shared

    var isVisible: Bool {
        appSettings.isPiyasalarHavadurumuEnabled || appSettings.isPrayerTimesEnabled ||
        appSettings.isHavadurumuEnabled || appSettings.isPiyasalarEnabled
    }

    var body: some View {
        Group {
            if isVisible {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    EditorialSectionHeader(title: "Servisler", eyebrow: AppBranding.servicesEyebrow)

                    HStack(spacing: Theme.Spacing.md) {
                        if appSettings.isHavadurumuEnabled || appSettings.isPiyasalarHavadurumuEnabled {
                            NavigationLink(destination: WeatherDetailView(showSideMenu: .constant(false))) {
                                QuickAccessTile(icon: "cloud.sun.fill", title: "Hava", color: Theme.Colors.info)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if appSettings.isPrayerTimesEnabled {
                            NavigationLink(destination: PrayerTimesDetailView(showSideMenu: .constant(false))) {
                                QuickAccessTile(icon: "moon.stars.fill", title: "Namaz", color: Theme.Colors.categoryPurple)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if appSettings.isPiyasalarEnabled || appSettings.isPiyasalarHavadurumuEnabled {
                            NavigationLink(destination: CurrencyDetailView(showSideMenu: .constant(false))) {
                                QuickAccessTile(icon: "dollarsign.circle.fill", title: "Döviz", color: Theme.Colors.success)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        NavigationLink(destination: PharmacyDetailView(showSideMenu: .constant(false))) {
                            QuickAccessTile(icon: "cross.case.fill", title: "Eczane", color: Theme.Brand.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }
                .padding(.vertical, Theme.Spacing.xl)
            }
        }
    }
}
