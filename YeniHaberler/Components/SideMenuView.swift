import SwiftUI

// MARK: - Side Menu Destination
enum SideMenuDestination: Equatable {
    case tab(Int)
    case headlines
    case authors
    case categories
    case standings
    case fixture
    case earthquake
    case dailyBriefing
    case favorites
    case history
    case settings
    case services
}

// MARK: - Side Menu View
struct SideMenuView: View {
    @Binding var isShowing: Bool
    @Binding var selectedTab: Int
    @State private var presentedDestination: SideMenuDestination?
    @State private var showInterests = false
    @StateObject private var prefs = UserPreferences.shared

    var body: some View {
        ZStack(alignment: .leading) {
            if isShowing {
                // Overlay
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(Theme.Animations.snappy) {
                            isShowing = false
                        }
                    }

                // Side menu panel — sola yapışık, tam ekran yüksekliği
                panel
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(Theme.Animations.smooth, value: isShowing)
        // Yarım modal sheet yerine tam ekran sayfa açılışı — kullanıcı bir
        // "alt panel"den ziyade asıl bir sayfaya gitmiş hissi alır.
        .fullScreenCover(item: Binding(
            get: { presentedDestination.flatMap { IdentifiedDestination(destination: $0) } },
            set: { newValue in presentedDestination = newValue?.destination }
        )) { wrapper in
            NavigationView {
                destinationView(for: wrapper.destination)
            }
            .navigationViewStyle(.stack)
        }
        // İlgi alanları kendi NavigationView'ını içerdiği için ayrı sheet ile sunulur.
        .sheet(isPresented: $showInterests) {
            InterestsView(onboarding: false)
        }
    }

    // MARK: - Tema seçici (sidebar en üst)
    // Ayarlar'daki tema kontrolünün hızlı erişimli kopyası. UserPreferences.themeMode'u
    // değiştirir → tüm uygulama (ve Ayarlar sayfası) anında güncellenir.
    private var themeSwitcher: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(AppThemeMode.allCases) { mode in
                let selected = prefs.themeMode == mode
                Button {
                    withAnimation(Theme.Animations.snappy) { prefs.themeMode = mode }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(mode.displayName)
                            .scaledFont(size: 13, weight: .semibold)
                    }
                    .foregroundColor(selected ? Theme.Colors.textOnBrand : Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(selected ? Theme.Brand.primary : Theme.Colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .stroke(Theme.Colors.borderSubtle, lineWidth: selected ? 0 : 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("\(mode.displayName) tema")
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private var panel: some View {
        // Tek bir ScrollView — header + tüm gruplar + footer içeride.
        // Böylece menü ne kadar uzun olursa olsun her şey aşağı/yukarı kaydırılabilir.
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                header
                themeSwitcher
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    MenuGroup(title: "Ana Menü") {
                        MenuRow(icon: "house.fill", title: "Ana Sayfa", isSelected: selectedTab == AppTab.home.rawValue) {
                            switchTab(AppTab.home.rawValue)
                        }
                        MenuRow(icon: "sun.horizon.fill", title: "Günün Özeti", iconColor: Theme.Brand.gold) {
                            present(.dailyBriefing)
                        }
                        MenuRow(icon: "bolt.fill", title: "Son Dakika", iconColor: Theme.Colors.warning, isSelected: selectedTab == AppTab.breaking.rawValue) {
                            switchTab(AppTab.breaking.rawValue)
                        }
                        MenuRow(icon: "newspaper.fill", title: "Manşetler", iconColor: Theme.Brand.primary) {
                            present(.headlines)
                        }
                        MenuRow(icon: "square.grid.2x2.fill", title: "Kategoriler", iconColor: Theme.Colors.categoryPurple) {
                            present(.categories)
                        }
                    }

                    MenuGroup(title: "Medya") {
                        MenuRow(icon: "play.rectangle.fill", title: "Videolar", iconColor: Theme.Colors.danger, isSelected: selectedTab == AppTab.videos.rawValue) {
                            switchTab(AppTab.videos.rawValue)
                        }
                        MenuRow(icon: "photo.on.rectangle.angled", title: "Foto Galeri", iconColor: Theme.Colors.info, isSelected: selectedTab == AppTab.galleries.rawValue) {
                            switchTab(AppTab.galleries.rawValue)
                        }
                        MenuRow(icon: "person.2.fill", title: "Yazarlar", iconColor: Theme.Colors.categoryPurple) {
                            present(.authors)
                        }
                    }

                    MenuGroup(title: "Servisler") {
                        MenuRow(icon: "sportscourt.fill", title: "Puan Durumu", iconColor: Theme.Colors.categoryGreen) {
                            present(.standings)
                        }
                        MenuRow(icon: "soccerball", title: "Fikstür", iconColor: Theme.Colors.warning) {
                            present(.fixture)
                        }
                        MenuRow(icon: "waveform.path.ecg", title: "Son Depremler", iconColor: Theme.Colors.danger) {
                            present(.earthquake)
                        }
                        MenuRow(icon: "cloud.sun.fill", title: "Servisler", iconColor: Theme.Colors.info) {
                            present(.services)
                        }
                    }

                    MenuGroup(title: "Kişisel") {
                        MenuRow(icon: "sparkles", title: "İlgi Alanların", iconColor: Theme.Brand.gold) {
                            withAnimation(Theme.Animations.snappy) { isShowing = false }
                            showInterests = true
                        }
                        MenuRow(icon: "bookmark.fill", title: "Favorilerim", iconColor: Theme.Brand.primary) {
                            present(.favorites)
                        }
                        MenuRow(icon: "clock.fill", title: "Geçmiş", iconColor: Theme.Colors.categoryPurple) {
                            present(.history)
                        }
                        MenuRow(icon: "magnifyingglass", title: "Ara", isSelected: selectedTab == AppTab.search.rawValue) {
                            switchTab(AppTab.search.rawValue)
                        }
                    }

                    MenuGroup(title: "Diğer") {
                        MenuRow(icon: "gearshape.fill", title: "Ayarlar", iconColor: Theme.Colors.textSecondary) {
                            present(.settings)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.md)

                footer
            }
        }
        .frame(width: 320)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.Colors.background.ignoresSafeArea())
        .themedShadow(Theme.Shadow.large)
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    if let img = UIImage(named: "icon") {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    } else {
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(Theme.Brand.primary)
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: "newspaper.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24, weight: .bold))
                            )
                    }
                }
                .themedShadow(Theme.Shadow.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppBranding.siteName)
                        .scaledFont(size: 17, weight: .bold)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Haber Portalı")
                        .scaledFont(size: 12, weight: .medium)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()
            }

            Button(action: {
                withAnimation(Theme.Animations.snappy) {
                    isShowing = false
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("Kapat")
                        .scaledFont(size: 12, weight: .semibold)
                }
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Theme.Colors.surface)
                )
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, 48)
        .padding(.bottom, Theme.Spacing.md)
        .background(
            LinearGradient(
                colors: [
                    Theme.Brand.primary.opacity(0.08),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Footer
    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Versiyon \(appVersion)")
                        .scaledFont(size: 11, weight: .medium)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text("© \(Calendar.current.component(.year, from: Date())) \(AppBranding.siteName)")
                        .scaledFont(size: 10)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Actions
    private func switchTab(_ tab: Int) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        selectedTab = tab
        withAnimation(Theme.Animations.snappy) {
            isShowing = false
        }
    }

    private func present(_ destination: SideMenuDestination) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        withAnimation(Theme.Animations.snappy) {
            isShowing = false
        }
        // Side menu kapanma animasyonunu bekleyip sheet aç
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            presentedDestination = destination
        }
    }

    @ViewBuilder
    private func destinationView(for destination: SideMenuDestination) -> some View {
        let dismissButton = closeButton

        switch destination {
        case .tab:
            EmptyView()
        case .headlines:
            HeadlinesView(showSideMenu: .constant(false))
                .navigationBarItems(leading: dismissButton)
        case .authors:
            AuthorsListView(showSideMenu: .constant(false))
                .navigationBarItems(leading: dismissButton)
        case .categories:
            CategoriesView(showSideMenu: .constant(false))
                .navigationBarItems(leading: dismissButton)
        case .standings:
            StandingsDetailView(showSideMenu: .constant(false), selectedTab: $selectedTab)
                .navigationBarItems(leading: dismissButton)
        case .fixture:
            FixtureView(showSideMenu: .constant(false))
                .navigationBarItems(leading: dismissButton)
        case .earthquake:
            EarthquakeView(showSideMenu: .constant(false))
                .navigationBarItems(leading: dismissButton)
        case .dailyBriefing:
            DailyBriefingView()
                .navigationBarItems(leading: dismissButton)
        case .favorites:
            FavoritesView(showSideMenu: .constant(false))
                .navigationBarItems(leading: dismissButton)
        case .history:
            HistoryView(showSideMenu: .constant(false))
                .navigationBarItems(leading: dismissButton)
        case .settings:
            SettingsView(showSideMenu: .constant(false))
                .navigationBarItems(leading: dismissButton)
        case .services:
            ServicesView(showSideMenu: .constant(false))
                .navigationBarItems(leading: dismissButton)
        }
    }

    private var closeButton: some View {
        Button(action: { presentedDestination = nil }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text("Geri")
                    .font(.system(size: 16))
            }
            .foregroundColor(Theme.Brand.primary)
        }
        .accessibilityLabel("Geri")
    }
}

// MARK: - Identified Destination wrapper (for sheet item binding)
private struct IdentifiedDestination: Identifiable {
    let destination: SideMenuDestination
    var id: String {
        switch destination {
        case .tab(let v):    return "tab\(v)"
        case .headlines:     return "headlines"
        case .authors:       return "authors"
        case .categories:    return "categories"
        case .standings:     return "standings"
        case .fixture:       return "fixture"
        case .earthquake:    return "earthquake"
        case .dailyBriefing: return "dailyBriefing"
        case .favorites:     return "favorites"
        case .history:       return "history"
        case .settings:      return "settings"
        case .services:      return "services"
        }
    }
}

// MARK: - Menu Group
struct MenuGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .scaledFont(size: 11, weight: .bold)
                .tracking(0.8)
                .foregroundColor(Theme.Colors.textTertiary)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xs)

            content
        }
    }
}

// MARK: - Menu Row
struct MenuRow: View {
    let icon: String
    let title: String
    var iconColor: Color = Theme.Brand.primary
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? iconColor.opacity(0.18) : iconColor.opacity(0.10))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                Text(title)
                    .scaledFont(size: 15, weight: isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textPrimary.opacity(0.85))

                Spacer()

                if isSelected {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(iconColor)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(
                isSelected
                    ? iconColor.opacity(0.08)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        // ButtonStyle ile basma efekti — DragGesture yok, ScrollView gesture'ı serbest.
        .buttonStyle(MenuRowButtonStyle())
    }
}

/// Basma anında hafif scale efekti veren özel ButtonStyle.
/// Önemli: DragGesture kullanmaz, dolayısıyla içerikteki ScrollView'in
/// dikey kaydırma gesture'ı ile çakışmaz.
private struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
