import SwiftUI
import AppTrackingTransparency

// MARK: - Settings View
struct SettingsView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var prefs = UserPreferences.shared
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var favorites = FavoritesService.shared
    @StateObject private var history = ReadingHistoryService.shared
    @StateObject private var userInterests = UserInterests.shared

    @State private var showClearFavoritesAlert = false
    @State private var showClearHistoryAlert = false
    @State private var showAboutSheet = false
    @State private var showContactSheet = false
    @State private var showInterests = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    appearanceSection
                    notificationsSection
                    contentSection
                    dataSection
                    privacySection
                    socialSection
                    aboutSection
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.lg)
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation { showSideMenu.toggle() }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .accessibilityLabel("Menüyü aç")
                    }
                }
            }
            .sheet(isPresented: $showAboutSheet) {
                AboutView()
            }
            .sheet(isPresented: $showContactSheet) {
                ContactFormView()
            }
            .sheet(isPresented: $showInterests) {
                InterestsView(onboarding: false)
            }
        }
        .navigationViewStyle(.stack)
        // KENDİ color scheme'ini reaktif uygular. MainView'ın preferredColorScheme'i bu
        // kendi NavigationView'ına ilk değişimden sonra propagate olmuyordu (cache) —
        // prefs'i izleyip burada uygulayınca her tema değişiminde güncellenir.
        .preferredColorScheme(prefs.themeMode.colorScheme)
        .id(prefs.themeMode)
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        SettingsSection(title: "Görünüm", icon: "paintbrush.fill", iconColor: Theme.Colors.categoryPurple) {
            // Theme picker
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Tema")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundColor(Theme.Colors.textPrimary)

                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(AppThemeMode.allCases) { mode in
                        ThemeOptionCard(
                            mode: mode,
                            isSelected: prefs.themeMode == mode
                        ) {
                            withAnimation(Theme.Animations.snappy) {
                                prefs.themeMode = mode
                            }
                        }
                    }
                }
            }

            Divider().padding(.vertical, Theme.Spacing.sm)

            // Font scale
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Text("Yazı Boyutu")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                    Text(prefs.fontScale.displayName)
                        .scaledFont(size: 13)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                HStack(spacing: 0) {
                    ForEach(FontScale.allCases) { scale in
                        FontScaleOption(
                            scale: scale,
                            isSelected: prefs.fontScale == scale
                        ) {
                            withAnimation(Theme.Animations.snappy) {
                                prefs.fontScale = scale
                            }
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Theme.Colors.background)
                )

                // Preview
                Text("Bu metin örnek bir önizlemedir. Yazı boyutu değişikliği uygulamadaki tüm metinleri etkiler.")
                    .scaledFont(size: 14)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(Theme.Colors.background)
                    )
            }
        }
    }

    private var notificationsSection: some View {
        SettingsSection(title: "Bildirimler", icon: "bell.fill", iconColor: Theme.Colors.warning) {
            SettingsToggleRow(
                title: "Bildirimleri Aç",
                subtitle: "Push bildirimleri al",
                icon: "bell.badge.fill",
                iconColor: Theme.Colors.warning,
                isOn: $prefs.notificationsEnabled
            )

            Divider().padding(.leading, 56)

            SettingsToggleRow(
                title: "Son Dakika Uyarıları",
                subtitle: "Önemli haberler için anlık bildirim",
                icon: "bolt.fill",
                iconColor: Theme.Colors.danger,
                isOn: $prefs.breakingNewsAlerts
            )
            .disabled(!prefs.notificationsEnabled)
            .opacity(prefs.notificationsEnabled ? 1 : 0.5)

            Divider().padding(.leading, 56)

            NavigationLink(destination: NotificationPreferencesView()) {
                SettingsActionRowContent(
                    title: "Bildirim Tercihleri",
                    subtitle: "Kategoriler, sessiz saat, günlük limit",
                    icon: "slider.horizontal.3",
                    iconColor: Theme.Colors.categoryPurple,
                    showChevron: true,
                    isDestructive: false
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!prefs.notificationsEnabled)
            .opacity(prefs.notificationsEnabled ? 1 : 0.5)
        }
    }

    private var contentSection: some View {
        SettingsSection(title: "İçerik", icon: "play.rectangle.fill", iconColor: Theme.Colors.info) {
            // İlgi alanları — seçilince ana sayfada "Sana Özel" akışı görünür.
            Button {
                showInterests = true
            } label: {
                SettingsActionRowContent(
                    title: "İlgi Alanların",
                    subtitle: userInterests.hasSelected
                        ? interestsSubtitle
                        : "Seçim yok — ana sayfada kişiselleştirme kapalı",
                    icon: "sparkles",
                    iconColor: Theme.Brand.primary,
                    showChevron: true
                )
            }
            .buttonStyle(PlainButtonStyle())

            Divider().padding(.leading, 56)

            SettingsToggleRow(
                title: "Videoları Otomatik Oynat",
                subtitle: "Video sayfasına girince başlat",
                icon: "play.circle.fill",
                iconColor: Theme.Colors.info,
                isOn: $prefs.autoplayVideos
            )
        }
    }

    /// Seçili ilgi alanlarını "Spor, Ekonomi, +2" biçiminde özetler.
    private var interestsSubtitle: String {
        let names = userInterests.categories.map { $0.name }
        guard !names.isEmpty else { return "Seçili" }
        let shown = names.prefix(2).joined(separator: ", ")
        let extra = names.count - min(2, names.count)
        return extra > 0 ? "\(shown), +\(extra)" : shown
    }

    private var dataSection: some View {
        SettingsSection(title: "Verilerim", icon: "externaldrive.fill", iconColor: Theme.Colors.categoryGreen) {
            SettingsInfoRow(
                title: "Favoriler",
                value: "\(favorites.items.count) öğe",
                icon: "bookmark.fill",
                iconColor: Theme.Brand.primary
            )

            if !favorites.items.isEmpty {
                Divider().padding(.leading, 56)
                SettingsActionRow(
                    title: "Favorileri Temizle",
                    icon: "trash",
                    iconColor: Theme.Colors.danger,
                    isDestructive: true
                ) {
                    showClearFavoritesAlert = true
                }
            }

            Divider().padding(.leading, 56)

            SettingsInfoRow(
                title: "Okuma Geçmişi",
                value: "\(history.items.count) öğe",
                icon: "clock.fill",
                iconColor: Theme.Colors.categoryPurple
            )

            if !history.items.isEmpty {
                Divider().padding(.leading, 56)
                SettingsActionRow(
                    title: "Geçmişi Temizle",
                    icon: "trash",
                    iconColor: Theme.Colors.danger,
                    isDestructive: true
                ) {
                    showClearHistoryAlert = true
                }
            }
        }
        .alert("Favorileri Temizle", isPresented: $showClearFavoritesAlert) {
            Button("Vazgeç", role: .cancel) {}
            Button("Temizle", role: .destructive) {
                favorites.clearAll()
            }
        } message: {
            Text("Tüm favori öğeleri silinecek. Bu işlem geri alınamaz.")
        }
        .alert("Geçmişi Temizle", isPresented: $showClearHistoryAlert) {
            Button("Vazgeç", role: .cancel) {}
            Button("Temizle", role: .destructive) {
                history.clearAll()
            }
        } message: {
            Text("Tüm okuma geçmişi silinecek. Bu işlem geri alınamaz.")
        }
    }

    // MARK: - Privacy
    private var privacySection: some View {
        SettingsSection(title: "Gizlilik", icon: "hand.raised.fill", iconColor: Theme.Colors.info) {
            // Tracking durumu (read-only)
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Colors.info)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.Colors.info.opacity(0.14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tanıtım İzleme")
                        .scaledFont(size: 15, weight: .medium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(trackingStatusLabel)
                        .scaledFont(size: 12)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm + 2)

            Divider().padding(.leading, 56)

            // Sistem ayarlarına yönlendirme
            SettingsActionRow(
                title: "Tanıtım Kimliği Ayarları",
                icon: "gearshape.2.fill",
                iconColor: Theme.Colors.info
            ) {
                ATTService.shared.openSystemPrivacySettings()
            }

            // Reklam İzinlerini Yönet (GDPR UMP form) — sadece gerektiğinde göster
            if AdMobHelper.shared.privacyOptionsRequired {
                Divider().padding(.leading, 56)
                SettingsActionRow(
                    title: "Reklam İzinlerini Yönet",
                    icon: "checkmark.shield.fill",
                    iconColor: Theme.Colors.warning
                ) {
                    presentAdConsentForm()
                }
            }

            Divider().padding(.leading, 56)

            // Yasal Bilgiler (API'den gelen sayfalar — KVKK, Gizlilik, Hakkımızda, vs.)
            NavigationLink(destination: PagesListView()) {
                SettingsActionRowContent(
                    title: "Yasal Bilgiler",
                    subtitle: "KVKK, Gizlilik, Hakkımızda",
                    icon: "doc.text.fill",
                    iconColor: Theme.Colors.categoryPurple,
                    showChevron: true,
                    isDestructive: false
                )
            }
        }
    }

    private func presentAdConsentForm() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              var top = window.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        AdMobHelper.shared.presentPrivacyOptionsForm(from: top)
    }

    private var trackingStatusLabel: String {
        switch ATTService.shared.currentStatus {
        case .authorized:    return "İzin verildi"
        case .denied:        return "İzin reddedildi"
        case .restricted:    return "Kısıtlanmış"
        case .notDetermined: return "Henüz sorulmadı"
        @unknown default:    return "Bilinmiyor"
        }
    }

    @ViewBuilder
    private var socialSection: some View {
        if hasAnySocial {
            SettingsSection(title: "Bizi Takip Edin", icon: "heart.fill", iconColor: Theme.Brand.primary) {
                if let url = appSettings.facebook {
                    SocialLinkRow(name: "Facebook", icon: "f.circle.fill", color: Color(hex: "#1877F2"), urlString: url)
                    Divider().padding(.leading, 56)
                }
                if let url = appSettings.twitter {
                    SocialLinkRow(name: "Twitter / X", icon: "x.circle.fill", color: Color.black, urlString: url)
                    Divider().padding(.leading, 56)
                }
                if let url = appSettings.instagram {
                    SocialLinkRow(name: "Instagram", icon: "camera.circle.fill", color: Color(hex: "#E4405F"), urlString: url)
                    Divider().padding(.leading, 56)
                }
                if let url = appSettings.youtube {
                    SocialLinkRow(name: "YouTube", icon: "play.rectangle.fill", color: Color(hex: "#FF0000"), urlString: url)
                    Divider().padding(.leading, 56)
                }
                if let url = appSettings.whatsapp {
                    SocialLinkRow(name: "WhatsApp", icon: "message.fill", color: Color(hex: "#25D366"), urlString: url)
                }
            }
        }
    }

    private var hasAnySocial: Bool {
        appSettings.facebook != nil ||
        appSettings.twitter != nil ||
        appSettings.instagram != nil ||
        appSettings.youtube != nil ||
        appSettings.whatsapp != nil
    }

    private var aboutSection: some View {
        SettingsSection(title: "Hakkında", icon: "info.circle.fill", iconColor: Theme.Colors.info) {
            SettingsActionRow(
                title: "Uygulama Hakkında",
                icon: "info.circle.fill",
                iconColor: Theme.Colors.info
            ) {
                showAboutSheet = true
            }

            // Bize Ulaşın — Contact form
            Divider().padding(.leading, 56)
            SettingsActionRow(
                title: "Bize Ulaşın",
                icon: "envelope.fill",
                iconColor: Theme.Brand.primary
            ) {
                showContactSheet = true
            }

            if let url = URL(string: Config.shared.baseURL) {
                Divider().padding(.leading, 56)
                Link(destination: url) {
                    SettingsActionRowContent(
                        title: "Web Sitesi",
                        icon: "globe",
                        iconColor: Theme.Colors.info,
                        showChevron: true,
                        isDestructive: false
                    )
                }
            }

            Divider().padding(.leading, 56)
            HStack {
                Image(systemName: "app.badge")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Theme.Colors.surface)
                    )

                Text("Versiyon")
                    .scaledFont(size: 15)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                Text(appVersion)
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(iconColor)
                Text(title.uppercased())
                    .scaledFont(size: 12, weight: .bold)
                    .tracking(0.8)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.leading, Theme.Spacing.md)

            VStack(spacing: 0) {
                content
            }
            .padding(Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .fill(Theme.Colors.surface)
            )
        }
    }
}

// MARK: - Settings Rows

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(Circle().fill(iconColor.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundColor(Theme.Colors.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .scaledFont(size: 12)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.Brand.primary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 2)
    }
}

struct SettingsInfoRow: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(Circle().fill(iconColor.opacity(0.14)))

            Text(title)
                .scaledFont(size: 15)
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            Text(value)
                .scaledFont(size: 13, weight: .medium)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 2)
    }
}

struct SettingsActionRowContent: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let iconColor: Color
    var showChevron: Bool = true
    var isDestructive: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(Circle().fill(iconColor.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundColor(isDestructive ? Theme.Colors.danger : Theme.Colors.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .scaledFont(size: 12)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 2)
        .contentShape(Rectangle())
    }
}

struct SettingsActionRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsActionRowContent(
                title: title,
                icon: icon,
                iconColor: iconColor,
                showChevron: true,
                isDestructive: isDestructive
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SocialLinkRow: View {
    let name: String
    let icon: String
    let color: Color
    let urlString: String

    var body: some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                SettingsActionRowContent(
                    title: name,
                    icon: icon,
                    iconColor: color,
                    showChevron: true,
                    isDestructive: false
                )
            }
        }
    }
}

// MARK: - Theme Option Card

struct ThemeOptionCard: View {
    let mode: AppThemeMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.Brand.primary : Theme.Colors.background)
                        .frame(width: 48, height: 48)

                    Image(systemName: mode.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .white : Theme.Colors.textSecondary)
                }

                Text(mode.displayName)
                    .scaledFont(size: 12, weight: isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? Theme.Brand.primary : Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(Theme.Colors.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(
                        isSelected ? Theme.Brand.primary : Theme.Colors.borderSubtle,
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Font Scale Option

struct FontScaleOption: View {
    let scale: FontScale
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("A")
                .font(.system(size: 14 * scale.multiplier, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    isSelected ? Theme.Brand.primary : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(2)
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var appSettings = AppSettings.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Logo
                    VStack(spacing: Theme.Spacing.md) {
                        if let img = UIImage(named: "icon") {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
                                .themedShadow(Theme.Shadow.medium)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.Radius.xl)
                                    .fill(Theme.Brand.primary)
                                    .frame(width: 100, height: 100)
                                Image(systemName: "newspaper.fill")
                                    .font(.system(size: 44, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .themedShadow(Theme.Shadow.medium)
                        }

                        Text(AppBranding.siteName)
                            .scaledFont(size: 24, weight: .bold)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text("Haber Portalı")
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    // Description
                    if let desc = appSettings.appFooterDescription, !desc.isEmpty {
                        Text(desc)
                            .scaledFont(size: 14)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xxl)
                    }

                    // Contact info
                    VStack(spacing: 0) {
                        if let address = appSettings.adres {
                            AboutInfoRow(icon: "mappin.and.ellipse", color: Theme.Colors.danger, title: "Adres", value: address)
                        }
                        if let phone = appSettings.telefon {
                            Divider().padding(.leading, 56)
                            AboutInfoRow(icon: "phone.fill", color: Theme.Colors.categoryGreen, title: "Telefon", value: phone)
                        }
                        if let mail = appSettings.adminmail {
                            Divider().padding(.leading, 56)
                            AboutInfoRow(icon: "envelope.fill", color: Theme.Brand.primary, title: "E-posta", value: mail)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .fill(Theme.Colors.surface)
                    )
                    .padding(.horizontal, Theme.Spacing.xl)

                    Text(AppBranding.copyrightShort)
                        .scaledFont(size: 12)
                        .foregroundColor(Theme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .navigationTitle("Hakkında")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct AboutInfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(Theme.Colors.textSecondary)
                Text(value)
                    .scaledFont(size: 14)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }
}
