import SwiftUI
import UserNotifications
import os

// MARK: - Onboarding View
/// İlk açılışta gösterilen 4 sayfalık tanıtım akışı.
/// Page 3: bildirim izni, Page 4: ATT izni → bittiğinde SDK'lar başlatılır.
struct OnboardingView: View {
    let onFinished: () -> Void

    @State private var currentPage: Int = 0
    @StateObject private var prefs = UserPreferences.shared

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    notificationsPage.tag(2)
                    trackingPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .never))
                .animation(Theme.Animations.smooth, value: currentPage)

                // Sayfa indikatörü + ana CTA + alt buton
                bottomControls
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // Logo
            if let img = UIImage(named: "icon") {
                // Logo'nun en-boy oranı korunur (kare zorlanmaz); geniş wordmark
                // logolar da büyük ve net görünür.
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                    .themedShadow(Theme.Shadow.large)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.xl)
                        .fill(Theme.Brand.primary)
                        .frame(width: 120, height: 120)
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white)
                }
                .themedShadow(Theme.Shadow.large)
            }

            // Gold accent
            Rectangle()
                .fill(Theme.Brand.gold)
                .frame(width: 48, height: 2)

            VStack(spacing: Theme.Spacing.md) {
                Text(AppBranding.welcomeTitle)
                    .scaledFont(size: 30, weight: .heavy, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text(AppBranding.tagline)
                    .scaledFont(size: 16, design: .serif)
                    .italic()
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var featuresPage: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                EditorialEyebrow(text: "Öne Çıkan Özellikler")
                Text("Size Özel\nDeneyim")
                    .scaledFont(size: 28, weight: .heavy, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: Theme.Spacing.xl) {
                featureRow(
                    icon: "bolt.fill",
                    title: "Son Dakika Bildirimleri",
                    description: "Önemli gelişmelerden anında haberdar olun"
                )
                featureRow(
                    icon: "wifi.slash",
                    title: "Çevrimdışı Okuma",
                    description: "Açtığınız haberler internetsiz de okunabilir"
                )
                featureRow(
                    icon: "slider.horizontal.3",
                    title: "Kişiselleştirme",
                    description: "Bildirim kategorileri, sessiz saatler, yazı boyutu"
                )
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var notificationsPage: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.Brand.primary.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(Theme.Brand.primary)
            }

            Rectangle()
                .fill(Theme.Brand.gold)
                .frame(width: 48, height: 2)

            VStack(spacing: Theme.Spacing.md) {
                Text("Önemli gelişmelerden\nanında haberdar olun")
                    .scaledFont(size: 24, weight: .heavy, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text("Son dakika, hava durumu uyarıları ve daha fazlası için bildirim izni veriyor musunuz?")
                    .scaledFont(size: 14, design: .serif)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var trackingPage: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.Brand.gold.opacity(0.18))
                    .frame(width: 140, height: 140)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(Theme.Brand.gold)
            }

            Rectangle()
                .fill(Theme.Brand.primary)
                .frame(width: 48, height: 2)

            VStack(spacing: Theme.Spacing.md) {
                Text("Gizliliğiniz\nÖnemli")
                    .scaledFont(size: 26, weight: .heavy, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text("Bir sonraki adımda Apple size daha alakalı reklamlar gösterebilmemiz için izin isteyecek. Kararınıza saygı duyuyoruz; istediğiniz zaman ayarlardan değiştirebilirsiniz.")
                    .scaledFont(size: 14, design: .serif)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: - Feature row

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.Brand.primary.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.Brand.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .scaledFont(size: 16, weight: .bold, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(description)
                    .scaledFont(size: 13, design: .serif)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? Theme.Brand.primary : Theme.Colors.borderSubtle)
                        .frame(width: currentPage == index ? 24 : 8, height: 6)
                        .animation(Theme.Animations.snappy, value: currentPage)
                }
            }

            // Primary CTA
            Button(action: primaryAction) {
                Text(primaryButtonTitle)
                    .scaledFont(size: 16, weight: .bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(Theme.Brand.primary)
                    )
            }
            .buttonStyle(PlainButtonStyle())

            // Secondary action (skip / atla)
            if let secondary = secondaryButton {
                Button(action: secondary.action) {
                    Text(secondary.title)
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Hizalama için boş yer
                Color.clear.frame(height: 20)
            }
        }
    }

    // MARK: - Actions

    private var primaryButtonTitle: String {
        switch currentPage {
        case 0: return "Devam"
        case 1: return "Devam"
        case 2: return "Bildirimleri Aç"
        case 3: return "Başla"
        default: return "Devam"
        }
    }

    private var secondaryButton: (title: String, action: () -> Void)? {
        switch currentPage {
        case 2: return ("Şimdi Değil", { advance() })
        default: return nil
        }
    }

    private func primaryAction() {
        switch currentPage {
        case 0, 1:
            advance()
        case 2:
            Task { await requestNotificationPermission(); advance() }
        case 3:
            Task { await finish() }
        default:
            advance()
        }
    }

    private func advance() {
        guard currentPage < 3 else { return }
        withAnimation(Theme.Animations.smooth) {
            currentPage += 1
        }
        AnalyticsService.shared.logOnboardingStep("page_\(currentPage + 1)")
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                prefs.notificationsEnabled = granted
            }
        } catch {
            AppLogger.push.warning("Notif permission error — \(error.localizedDescription, privacy: .public)")
        }
    }

    private func finish() async {
        // ATT prompt (varsa) + AdMob/OneSignal başlat
        await TrackingConsentCoordinator.shared.requestConsentAndInitializeSDKs()
        await MainActor.run {
            prefs.hasCompletedOnboarding = true
            AnalyticsService.shared.logOnboardingCompleted()
            onFinished()
        }
    }
}
