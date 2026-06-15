import SwiftUI

// MARK: - Editorial Hero Card
/// Anasayfa hero — edge-to-edge yatay görsel + altta gradient overlay + serif başlık.
struct EditorialHeroCard: View {
    let post: Post
    /// Sabit yükseklik — yatay görseller için ideal (16:10 oranına yakın).
    var height: CGFloat = 380

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Theme.Colors.surfaceElevated
                    .frame(width: proxy.size.width, height: height)
                ThemedAsyncImage(url: post.image.cropped.large, aspect: .fit)
                    .frame(width: proxy.size.width, height: height)
                    .clipped()

                // Cinematic gradient — sadece alt yarı kapansın.
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.25),
                        .black.opacity(0.75),
                        .black.opacity(0.95)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: height)

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if let category = post.categories.values.first {
                        PillTag(text: category, color: Theme.Brand.primary, style: .filled)
                    }

                    Text(post.name)
                        .scaledFont(size: 24, weight: .heavy, design: .serif)
                        .foregroundColor(.white)
                        .lineLimit(4)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.5), radius: 8, y: 2)

                    if let author = post.author {
                        Byline(
                            author: author.name,
                            date: post.createdAt.prefix(10).description,
                            color: .white.opacity(0.92)
                        )
                    }
                }
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: proxy.size.width, alignment: .leading)
            }
            .frame(width: proxy.size.width, height: height)
            .clipped()
        }
        .frame(height: height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(post.accessibilityLabel)
        .accessibilityHint("Habere git")
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: - Editorial Lead Card
/// Görseli geniş, başlık altında — gazetenin "lead" haberi tarzı.
struct EditorialLeadCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image — AspectImage overflow yapmayan helper
            AspectImage(url: post.image.cropped.large, aspectRatio: 16/10, contentMode: .fit)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let category = post.categories.values.first {
                    EditorialEyebrow(text: category)
                }

                Text(post.name)
                    .scaledFont(size: 22, weight: .bold, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(4)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = post.description, !description.isEmpty {
                    Text(description)
                        .scaledFont(size: 14, design: .serif)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Byline(
                    author: post.author?.name,
                    date: post.createdAt.prefix(10).description
                )
                .padding(.top, Theme.Spacing.xs)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.surface)
        .overlay(
            Rectangle().stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(post.accessibilityLabel)
        .accessibilityHint("Habere git")
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: - Editorial Story Card
/// Standart liste kartı — sol görsel, sağda metin (NYT/Bloomberg stili).
struct EditorialStoryCard: View {
    let post: Post
    var showBookmark: Bool = true
    @ObservedObject private var favorites = FavoritesService.shared

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let category = post.categories.values.first {
                    EditorialEyebrow(text: category, showDot: false)
                }

                Text(post.name)
                    .scaledFont(size: 17, weight: .bold, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(3)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = post.description, !description.isEmpty {
                    Text(description)
                        .scaledFont(size: 13, design: .serif)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }

                Spacer(minLength: 0)

                HStack(spacing: Theme.Spacing.sm) {
                    Byline(
                        author: post.author?.name,
                        date: post.createdAt.prefix(10).description
                    )

                    if let badge = typeBadge {
                        PillTag(text: badge.label, icon: badge.icon, color: badge.color, style: .ghost)
                    }

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: Theme.Spacing.sm) {
                // Kare çerçeve için sunucunun KARE kırpması (square: 750×750) kullanılır —
                // medium (640×375, yatay) kareye sığınca ya beyaz boşluk ya fazla kesim olurdu.
                // square yoksa medium'a fallback eder (CroppedImages decoder).
                ThemedAsyncImage(url: post.image.cropped.square, aspect: .fill)
                    .frame(width: 110, height: 110)
                    .background(Theme.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

                if showBookmark {
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        favorites.togglePost(post)
                    } label: {
                        Image(systemName: favorites.isPostFavorited(post.id) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(favorites.isPostFavorited(post.id) ? Theme.Brand.primary : Theme.Colors.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityHidden(true)  // rotor action olarak sunulur
                }
            }
        }
        .padding(.vertical, Theme.Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(post.accessibilityLabel)
        .accessibilityHint("Habere git")
        .accessibilityAddTraits(.isLink)
        .accessibilityAction(named: favorites.isPostFavorited(post.id) ? "Yer imini kaldır" : "Yer imine ekle") {
            favorites.togglePost(post)
        }
    }

    private var typeBadge: (label: String, icon: String, color: Color)? {
        guard let type = post.type?.lowercased() else { return nil }
        switch type {
        case "video":   return ("VİDEO", "play.fill", Theme.Brand.primary)
        case "gallery": return ("GALERİ", "photo.fill", Theme.Colors.info)
        case "article": return ("YAZAR", "pencil", Theme.Colors.categoryPurple)
        default:        return nil
        }
    }
}

// MARK: - Editorial Brief Card
/// Text-only kompakt kart — gazetelerdeki "kısa haberler" tarzı.
/// Sol kenarda kırmızı/altın aksent çizgi.
struct EditorialBriefCard: View {
    let post: Post
    var accentColor: Color = Theme.Brand.primary

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                if let category = post.categories.values.first {
                    Text(category.uppercased())
                        .scaledFont(size: 10, weight: .heavy)
                        .tracking(0.8)
                        .foregroundColor(accentColor)
                }
                Text(post.name)
                    .scaledFont(size: 15, weight: .bold, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)

                Byline(
                    author: post.author?.name,
                    date: post.createdAt.prefix(10).description
                )
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.trailing, Theme.Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(post.accessibilityLabel)
        .accessibilityHint("Habere git")
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: - Numbered Story Row
/// "Çok Okunanlar" listesi için — büyük numaralı satır.
struct NumberedStoryRow: View {
    let index: Int
    let post: Post

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
            Text("\(index)")
                .scaledFont(size: 44, weight: .heavy, design: .serif)
                .foregroundColor(Theme.Brand.primary.opacity(0.85))
                .frame(width: 44)
                .baselineOffset(-4)

            VStack(alignment: .leading, spacing: 4) {
                if let category = post.categories.values.first {
                    EditorialEyebrow(text: category, showDot: false)
                }
                Text(post.name)
                    .scaledFont(size: 16, weight: .bold, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(3)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Byline(
                    author: post.author?.name,
                    date: post.createdAt.prefix(10).description
                )
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sıra \(index). " + post.accessibilityLabel)
        .accessibilityHint("Habere git")
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: - Editorial Card Selectors
/// Bir post listesini editorial varyasyonlarla göstermek için yardımcı.
enum EditorialCardVariant {
    case hero
    case lead
    case story
    case brief
    case numbered(Int)
}

// MARK: - Editorial Headlines Slider
/// Auto-rotating manşetler slider'ı — editorial stilde, dashed indicator + title overlay.
struct EditorialHeadlinesSlider<Destination: View>: View {
    let headlines: [Post]
    let destinationBuilder: (Post) -> Destination

    @State private var currentIndex = 0
    @State private var timer: Timer? = nil

    /// 16:10 aspect ratio + sağ/sol 20pt padding'i hesaba katarak slider yüksekliği.
    private var sliderHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let imageWidth = screenWidth - (Theme.Spacing.xl * 2)
        return imageWidth * 10 / 16
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            TabView(selection: $currentIndex) {
                ForEach(Array(headlines.enumerated()), id: \.element.id) { index, post in
                    NavigationLink(destination: destinationBuilder(post)) {
                        slide(for: post)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .tag(index)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Manşet \(index + 1)/\(headlines.count). " + post.accessibilityLabel)
                    .accessibilityHint("Habere git")
                    .accessibilityAddTraits(.isLink)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: sliderHeight)
            .onAppear(perform: startTimer)
            .onDisappear(perform: stopTimer)
            .onChange(of: currentIndex) { _ in resetTimer() }
            .accessibilityScrollAction { edge in
                switch edge {
                case .leading, .top:
                    currentIndex = (currentIndex - 1 + headlines.count) % headlines.count
                case .trailing, .bottom:
                    currentIndex = (currentIndex + 1) % headlines.count
                @unknown default:
                    break
                }
            }

            // Dashed indicator
            HStack(spacing: 6) {
                ForEach(0..<headlines.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(currentIndex == index ? Theme.Brand.primary : Theme.Colors.borderSubtle)
                        .frame(width: currentIndex == index ? 24 : 14, height: 3)
                        .animation(Theme.Animations.snappy, value: currentIndex)
                }
            }
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func slide(for post: Post) -> some View {
        ZStack(alignment: .bottomLeading) {
            AspectImage(url: post.image.cropped.large, aspectRatio: 16/10, contentMode: .fit)

            // Cinematic gradient
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.20),
                    .black.opacity(0.65),
                    .black.opacity(0.92)
                ],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let category = post.categories.values.first {
                    PillTag(text: category, color: Theme.Brand.primary, style: .filled)
                }

                Text(post.name)
                    .scaledFont(size: 20, weight: .heavy, design: .serif)
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .lineSpacing(1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 2)

                if let author = post.author {
                    Byline(
                        author: author.name,
                        date: post.createdAt.prefix(10).description,
                        color: .white.opacity(0.92)
                    )
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                currentIndex = (currentIndex + 1) % headlines.count
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func resetTimer() {
        stopTimer()
        startTimer()
    }
}
