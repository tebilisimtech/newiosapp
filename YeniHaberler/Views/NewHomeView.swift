import SwiftUI
import Combine
import GoogleMobileAds

// MARK: - Editorial Home View
//
// Server-driven UI mimarisine geçiş: Tüm content seksiyonları artık bağımsız
// component'ler (Components/HomeSections/). NewHomeView sadece layout
// orkestrasyonu, toolbar ve global elementler (banner reklamlar, footer)
// için sorumludur. Section'lar kendi data fetch'lerini yapar.
//
// İleride: section sırası ve görünürlüğü API'den gelecek (bkz: server-driven
// architecture memory). Şu an sıralama hardcoded fallback.
struct NewHomeView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var userInterests = UserInterests.shared
    /// Pull-to-refresh'te değişir → tüm section'lar yeniden oluşturulup
    /// .task'leri tekrar çalışır (API'ye yeni sorgu).
    @State private var refreshID = UUID()

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    homeHeader
                    content
                }
            }
            // Nav bar yerine özel header — logo, nav bar'ın ~44pt yükseklik
            // sınırına takılmadan büyük gösterilir.
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await appSettings.loadSettings()
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Header (büyük logo + menü)
    private var homeHeader: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button(action: { withAnimation { showSideMenu.toggle() } }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .accessibilityLabel("Menüyü aç")
            }

            Spacer()

            LogoView(maxHeight: 76)

            Spacer()

            // Menü butonu dengesi — logo ortalı kalsın
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.sm)
        .background(Theme.Colors.background)
    }

    // MARK: - Body
    //
    // Üst sabit elemanlar (date bar, story carousel, hero) → dinamik modüller (settings.modules,
    // position sırasına göre) → alt sabit elemanlar (QuickAccess servisler, banner, footer).
    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
                // EDITORIAL HEADER (sabit)
                BrandHairline()
                DateBar(date: Date(), label: AppBranding.homeBarLabel)
                Rectangle()
                    .fill(Theme.Colors.borderSubtle)
                    .frame(height: 0.5)

                // HİKAYELER (sabit)
                StoryCarouselSection()

                // SANA ÖZEL — yalnızca kullanıcı ilgi alanı seçtiyse görünür.
                // Seçim yoksa (onboarding'de atlandıysa) ana sayfada gizli;
                // Ayarlar → "İlgi Alanların" üzerinden seçilebilir.
                if userInterests.hasSelected {
                    ForYouSection(showSideMenu: $showSideMenu)
                }

                // Ana Sayfa - Üst Banner (#2000)
                AdPlacement(channel: AdChannel.homeTopBanner)

                // DİNAMİK MODÜLLER — her modülden sonra bir akış reklamı (#2001–#2011)
                ForEach(Array(appSettings.enabledModulesInOrder.enumerated()), id: \.element) { index, key in
                    moduleView(for: key)
                    if index < AdChannel.homeFeed.count {
                        AdPlacement(channel: AdChannel.homeFeed[index])
                    }
                }

                // SERVİSLER (sabit — modüllerdeki havadurumu/piyasalar/prayer_times burada toplu)
                QuickAccessSection()

                EditorialFooter()
                    .padding(.top, Theme.Spacing.xxl)
                    .padding(.bottom, 100)
            }
            // refreshID değişince bu alt ağaç yeniden oluşturulur → tüm section
            // viewModel'leri sıfırlanıp .task'leri yeniden API'ye sorgu atar.
            .id(refreshID)
        }
        .refreshable {
            await refreshAll()
        }
    }

    /// Pull-to-refresh: ayarları + tüm section'ları yeniden yükler.
    @MainActor
    private func refreshAll() async {
        await appSettings.loadSettings()
        // Reklamları da yeniden çek.
        await AdvertManager.shared.reload()
        // Section'ları yeniden oluştur (hepsi yeniden fetch eder).
        refreshID = UUID()
        // Spinner kısa süre görünür kalsın ki yenilendiği belli olsun.
        try? await Task.sleep(nanoseconds: 700_000_000)
    }

    /// Modül key'inden ilgili widget'ı üretir. Bilinmeyen / henüz implemente edilmemiş
    /// key'ler için EmptyView döndürür (sessiz skip).
    @ViewBuilder
    private func moduleView(for key: String) -> some View {
        switch key {
        case "son_dakika":
            SonDakikaSection(showSideMenu: $showSideMenu)
        case "ana_mansetler_baslik":
            HeadlinesSliderSection(showSideMenu: $showSideMenu)
        case "ust_mansetler":
            TopHeadlinesSection(showSideMenu: $showSideMenu)
        case "local_news":
            LatestStoriesSection(showSideMenu: $showSideMenu)
        case "yazarlar":
            AuthorsSection(showSideMenu: $showSideMenu)
        case "videolar":
            VideosSection(limit: 6)
        case "galeriler":
            GalleriesSection(limit: 6)
        case "trend_news":
            PopularPostsSection(showSideMenu: $showSideMenu)
        case "featured":
            EditorPicksSection(showSideMenu: $showSideMenu)
        case "five_headline":
            ArticleFivesSection(showSideMenu: $showSideMenu)
        case "biography":
            BiographiesSection(showSideMenu: $showSideMenu)
        case "interview":
            InterviewsSection(showSideMenu: $showSideMenu)
        case "daily_headline":
            DailyHeadlineSection()
        // QuickAccess'te birleşik gösterildiği için bu key'ler dynamic zone'da skip edilir:
        // havadurumu, piyasalar, prayer_times, puandurumu
        // Mevcut sürümde widget'ı olmayan modüller:
        // kategori_mansetler_baslik, tab_news
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var bannerSlot: some View {
        // AdMob unit ID API'den (yoksa .env/test) — HomeAdSlot adsEnabled'ı içeride kontrol eder.
        HomeAdSlot(adUnitID: appSettings.resolvedBannerAdUnitId)
    }
}

// MARK: - Compact Lead Card (yatay scroll için)
struct EditorialLeadCardCompact: View {
    let post: Post

    private let cardWidth: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ThemedAsyncImage(url: post.image.cropped.square, aspect: .fill)
                .frame(width: cardWidth, height: 168)
                .background(Theme.Colors.surfaceElevated)
                .clipped()
                .overlay(alignment: .topLeading) {
                    if let category = post.categories.values.first {
                        PillTag(text: category, color: Theme.Brand.primary, style: .filled)
                            .padding(Theme.Spacing.sm)
                    }
                }

            // Başlık + byline kartın gövdesinde — görselle aynı yüzeyde, içinde.
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(post.name)
                    .scaledFont(size: 16, weight: .bold, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(3)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Byline(
                    author: post.author?.name,
                    date: post.createdAt.prefix(10).description
                )
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: cardWidth)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .themedShadow(Theme.Shadow.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(post.accessibilityLabel)
        .accessibilityHint("Habere git")
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: - Editorial Author Portrait
struct EditorialAuthorPortrait: View {
    let author: AuthorDetail

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Theme.Brand.primary, Theme.Brand.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 90, height: 90)

                Group {
                    if !author.avatarURL.isEmpty {
                        ThemedAsyncImage(url: author.avatarURL)
                    } else {
                        ZStack {
                            Circle()
                                .fill(Theme.Brand.primary.opacity(0.15))
                            Text(author.name.prefix(1))
                                .scaledFont(size: 32, weight: .heavy, design: .serif)
                                .foregroundColor(Theme.Brand.primary)
                        }
                    }
                }
                .frame(width: 78, height: 78)
                .clipShape(Circle())
            }

            VStack(spacing: 2) {
                Text(author.name)
                    .scaledFont(size: 12, weight: .bold, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("YAZAR")
                    .scaledFont(size: 9, weight: .heavy)
                    .tracking(1.0)
                    .foregroundColor(Theme.Brand.primary)
            }
            .frame(width: 100)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Yazar: \(author.name)")
        .accessibilityHint("Yazarın sayfasına git")
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: - Editorial Video Card (yatay scroll)
struct EditorialVideoCard: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ZStack {
                Theme.Colors.surfaceElevated
                    .frame(width: 240, height: 150)
                ThemedAsyncImage(url: video.image.cropped.medium, aspect: .fit)
                    .frame(width: 240, height: 150)
                    .clipShape(Rectangle())

                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(width: 240, height: 150)

                ZStack {
                    Circle()
                        .fill(Theme.Brand.primary)
                        .frame(width: 52, height: 52)
                        .themedShadow(Theme.Shadow.medium)
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.white)
                        .offset(x: 2)
                }
            }
            .overlay(alignment: .topLeading) {
                PillTag(text: "VİDEO", icon: "play.fill", color: Theme.Brand.primary, style: .filled)
                    .padding(Theme.Spacing.sm)
            }

            if let category = video.categories.values.first {
                EditorialEyebrow(text: category, showDot: false)
            }

            Text(video.name)
                .scaledFont(size: 15, weight: .bold, design: .serif)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 240, alignment: .leading)
        }
        .frame(width: 240)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Video. \(video.categories.values.first ?? ""): \(video.name)")
        .accessibilityHint("Videoyu izle")
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: - Editorial Gallery Card
struct EditorialGalleryCard: View {
    let gallery: Gallery

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                Theme.Colors.surfaceElevated
                    .frame(width: 240, height: 150)
                ThemedAsyncImage(url: gallery.image.cropped.medium, aspect: .fit)
                    .frame(width: 240, height: 150)
                    .clipShape(Rectangle())

                HStack(spacing: 4) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("GALERİ")
                        .scaledFont(size: 10, weight: .heavy)
                }
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.7)))
                .padding(Theme.Spacing.sm)
            }

            if let category = gallery.categories.values.first {
                EditorialEyebrow(text: category, showDot: false)
            }

            Text(gallery.name)
                .scaledFont(size: 15, weight: .bold, design: .serif)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 240, alignment: .leading)
        }
        .frame(width: 240)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Galeri. \(gallery.categories.values.first ?? ""): \(gallery.name)")
        .accessibilityHint("Galeriyi aç")
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: - Editorial Article Five Card (yatay scroll)
struct EditorialArticleFiveCard: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ZStack(alignment: .topLeading) {
                Theme.Colors.surfaceElevated
                    .frame(width: 220, height: 150)
                Group {
                    if let img = article.image?.cropped.medium, !img.isEmpty {
                        ThemedAsyncImage(url: img, aspect: .fit)
                    } else {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Theme.Brand.gold.opacity(0.5), Theme.Brand.gold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .overlay(
                                Image(systemName: "quote.opening")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                }
                .frame(width: 220, height: 150)
                .clipShape(Rectangle())

                PillTag(text: "KÖŞE", color: Theme.Brand.gold, style: .filled)
                    .padding(Theme.Spacing.sm)
            }

            if let author = article.author?.name {
                EditorialEyebrow(text: author, showDot: false)
            }

            Text(article.name)
                .scaledFont(size: 15, weight: .bold, design: .serif)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(3)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 220, alignment: .leading)
        }
        .frame(width: 220)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Köşe yazısı. \(article.author?.name ?? ""). \(article.name)")
        .accessibilityHint("Yazıyı oku")
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: - Editorial Biography Tile
struct EditorialBiographyTile: View {
    let biography: Biography

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ZStack(alignment: .topLeading) {
                Theme.Colors.surfaceElevated
                    .frame(width: 200, height: 140)
                Group {
                    if let img = biography.image?.cropped.medium, !img.isEmpty {
                        ThemedAsyncImage(url: img, aspect: .fit)
                    } else {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Theme.Colors.categoryPurple.opacity(0.5), Theme.Colors.categoryPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .overlay(
                                Image(systemName: "person.text.rectangle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                }
                .frame(width: 200, height: 140)
                .clipShape(Rectangle())

                PillTag(text: "BİYOGRAFİ", color: Theme.Colors.categoryPurple, style: .filled)
                    .padding(Theme.Spacing.sm)
            }

            Text(biography.name)
                .scaledFont(size: 15, weight: .bold, design: .serif)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .frame(width: 200, alignment: .leading)
        }
        .frame(width: 200)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Biyografi: \(biography.name)")
        .accessibilityHint("Biyografiyi oku")
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: - Editorial Interview Tile
struct EditorialInterviewTile: View {
    let interview: Interview

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ZStack(alignment: .topLeading) {
                Theme.Colors.surfaceElevated
                    .frame(width: 200, height: 140)
                Group {
                    if let img = interview.image?.cropped.medium, !img.isEmpty {
                        ThemedAsyncImage(url: img, aspect: .fit)
                    } else {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Theme.Colors.warning.opacity(0.6), Theme.Colors.warning],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .overlay(
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                }
                .frame(width: 200, height: 140)
                .clipShape(Rectangle())

                PillTag(text: "RÖPORTAJ", color: Theme.Colors.warning, style: .filled)
                    .padding(Theme.Spacing.sm)
            }

            Text(interview.name)
                .scaledFont(size: 15, weight: .bold, design: .serif)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .frame(width: 200, alignment: .leading)
        }
        .frame(width: 200)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Röportaj: \(interview.name)")
        .accessibilityHint("Röportajı oku")
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: - Quick Access Tile
struct QuickAccessTile: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Rectangle()
                    .fill(color.opacity(0.10))
                    .aspectRatio(1, contentMode: .fit)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(title.uppercased())
                .scaledFont(size: 10, weight: .heavy)
                .tracking(1.0)
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Home Ad Slot (yumuşatılmış reklam kapsayıcısı)
/// `Config.adsEnabled` false ise hiç render olmaz.
struct HomeAdSlot: View {
    let adUnitID: String

    var body: some View {
        if Config.shared.adsEnabled {
            VStack(spacing: 4) {
                Text("REKLAM")
                    .scaledFont(size: 9, weight: .heavy)
                    .tracking(1.4)
                    .foregroundColor(Theme.Colors.textTertiary)

                AdBannerView(adUnitID: adUnitID)
                    .frame(height: 50)
            }
            .padding(.vertical, Theme.Spacing.lg)
        }
    }
}

// MARK: - Editorial Footer
struct EditorialFooter: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            BrandHairline()

            VStack(spacing: Theme.Spacing.sm) {
                Text(AppBranding.siteName.uppercased())
                    .scaledFont(size: 14, weight: .heavy, design: .serif)
                    .tracking(1.5)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text(AppBranding.portalLine)
                    .scaledFont(size: 11, weight: .medium)
                    .foregroundColor(Theme.Colors.textSecondary)

                Rectangle()
                    .fill(Theme.Brand.gold)
                    .frame(width: 32, height: 1)
                    .padding(.vertical, Theme.Spacing.sm)

                Text(AppBranding.copyright)
                    .scaledFont(size: 10)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .multilineTextAlignment(.center)

                Text("Haber Yazılımı: TE Bilişim")
                    .scaledFont(size: 9)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }
}
