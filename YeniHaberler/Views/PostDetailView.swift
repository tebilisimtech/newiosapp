import SwiftUI
import Combine
import WebKit
import UIKit
import GoogleMobileAds

// MARK: - Post Detail View
struct PostDetailView: View {
    let postId: Int

    @StateObject private var viewModel = PostDetailViewModel()
    @StateObject private var favorites = FavoritesService.shared
    @StateObject private var userPrefs = UserPreferences.shared
    @Environment(\.dismiss) var dismiss

    @State private var showShareSheet = false
    @State private var scrollProgress: CGFloat = 0

    private var isFavorited: Bool {
        favorites.isPostFavorited(postId)
    }

    var body: some View {
        Group {
            if Config.shared.articleOpenMode == .web {
                webBody
            } else {
                nativeBody
            }
        }
        .task {
            await viewModel.loadPost(id: postId)
            if let post = viewModel.post {
                ReadingHistoryService.shared.recordPostDetail(post)
            }
        }
    }

    // MARK: - Web mode (SFSafariViewController — site trafiği)
    @ViewBuilder
    private var webBody: some View {
        if let post = viewModel.post,
           let target = ContentURLBuilder.url(rawURL: post.url, slug: post.slug,
                                              medium: "app", campaign: "post") {
            SafariWebView(url: target)
                .ignoresSafeArea()
                .navigationBarHidden(true)
        } else if let error = viewModel.errorMessage {
            ErrorView(message: error) {
                Task { await viewModel.loadPost(id: postId) }
            }
        } else {
            PostDetailSkeleton().padding(.top, Theme.Spacing.lg)
        }
    }

    // MARK: - Native mode
    private var nativeBody: some View {
        ZStack(alignment: .top) {
            Theme.Colors.background.ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let post = viewModel.post {
                            content(
                                for: post,
                                parts: viewModel.htmlContentParts,
                                relatedPost: viewModel.relatedPost,
                                width: geometry.size.width
                            )

                            ForEach(viewModel.chainPosts) { chainPost in
                                NextStoryDivider()
                                content(
                                    for: chainPost,
                                    parts: viewModel.chainContent[chainPost.id] ?? (chainPost.content, ""),
                                    relatedPost: viewModel.chainRelated[chainPost.id],
                                    width: geometry.size.width
                                )
                            }

                            chainFooter
                        } else if viewModel.isLoading {
                            PostDetailSkeleton()
                                .padding(.top, Theme.Spacing.lg)
                        } else if let error = viewModel.errorMessage {
                            ErrorView(message: error) {
                                Task { await viewModel.loadPost(id: postId) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 400)
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadPost(id: postId)
                }
                .readingProgress($scrollProgress)
            }

            // Toolbar altı okuma ilerleme çubuğu
            if viewModel.post != nil {
                ReadingProgressBar(progress: scrollProgress)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { LogoView() }

            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.post != nil {
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorited ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isFavorited ? Theme.Brand.primary : Theme.Colors.textPrimary)
                            .accessibilityLabel(isFavorited ? "Yer imini kaldır" : "Yer imine ekle")
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.post != nil {
                    Button(action: sharePost) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .accessibilityLabel("Paylaş")
                    }
                }
            }
        }
    }

    // MARK: - Content
    @ViewBuilder
    private func content(
        for post: PostDetail,
        parts: (first: String, second: String),
        relatedPost: Post?,
        width: CGFloat
    ) -> some View {
        // Hero image
        DetailHeroImage(imageURL: post.image.cropped.large, width: width)

        // Haber Detay - Hero Görsel Altı (#2012)
        AdPlacement(channel: AdChannel.postHero)

        // Meta + title block (editorial)
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Eyebrow (kategori)
            if let category = post.categories.values.first {
                EditorialEyebrow(text: category)
            }

            // Title (serif, editorial)
            Text(post.name)
                .scaledFont(size: 28, weight: .heavy, design: .serif)
                .foregroundColor(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(3)

            // Description (lead, serif italik)
            if let description = post.description, !description.isEmpty {
                Text(description)
                    .scaledFont(size: 17, weight: .regular, design: .serif)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .italic()
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            EditorialDivider(withGlyph: true)

            // Meta strip
            PostMetaStrip(post: post, readingTimeMinutes: readingTimeMinutes(for: post))

            // Diğer kategoriler chip
            if post.categories.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Array(post.categories.values.dropFirst()), id: \.self) { category in
                            PillTag(text: category, color: Theme.Brand.primary, style: .outline)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xl)

        // Haber Detay - Başlık Altı (#2013)
        AdPlacement(channel: AdChannel.postTitle)

        Divider().padding(.horizontal, Theme.Spacing.xl)

        // HTML content - first half
        let firstHTML = parts.first.isEmpty ? post.content : parts.first

        HTMLContentView(
            htmlContent: firstHTML,
            width: width,
            scale: userPrefs.fontScale.multiplier
        )
        .frame(width: width)
        .padding(.vertical, Theme.Spacing.sm)

        // Haber Detay - İçerik Ortası (#2014)
        AdPlacement(channel: AdChannel.postContentMid)

        // Related post
        if let relatedPost = relatedPost {
            ModernRelatedPostSection(relatedPost: relatedPost)
                .padding(.vertical, Theme.Spacing.xxl)
        }

        // HTML content - second half
        if !parts.second.isEmpty {
            HTMLContentView(
                htmlContent: parts.second,
                width: width,
                scale: userPrefs.fontScale.multiplier
            )
            .frame(width: width)
            .padding(.vertical, Theme.Spacing.sm)
        }

        // Tags
        if !post.tags.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Etiketler", icon: "tag.fill")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(post.tags, id: \.self) { tag in
                            Tag("#\(tag)", color: Theme.Colors.textSecondary, style: .soft)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }
            }
            .padding(.top, Theme.Spacing.xl)
        }

        // Source / Reporter info
        if post.source != nil || post.reporter != nil || post.agency != nil {
            SourceInfoCard(post: post)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.lg)
        }

        // Haber Detay - İçerik Altı (#2015)
        AdPlacement(channel: AdChannel.postContentBottom)
            .padding(.top, Theme.Spacing.lg)

        // Haber Detay - Yorumlar Öncesi (#2016)
        AdPlacement(channel: AdChannel.postBeforeComments)

        // Comments
        CommentsView(referenceId: post.id, referenceType: ReferenceType.post.apiValue)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxxl)

        // Sonraki haberi yükleme tetikleyicisi — bu post'un sonu görününce çalışır.
        // LazyVStack içinde lazy oluşturulur, bu yüzden her post'un kendi tetiği
        // sadece o post'un altına ulaşıldığında bir kez ateşlenir.
        Color.clear
            .frame(height: 1)
            .onAppear {
                Task { await viewModel.loadNextInChain() }
            }
    }

    // MARK: - Chain footer (sonsuz kaydırma görsel durum göstergesi)
    @ViewBuilder
    private var chainFooter: some View {
        if viewModel.isLoadingNext {
            VStack(spacing: Theme.Spacing.md) {
                ProgressView()
                    .tint(Theme.Brand.primary)
                Text("Sonraki haber yükleniyor…")
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xxl)
        } else if !viewModel.hasMoreNext {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.Colors.textTertiary)
                Text("Tüm haberleri okudunuz")
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xxl)
        }
    }

    // MARK: - Actions

    private func toggleFavorite() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        guard let detail = viewModel.post else { return }
        let item = FavoriteItem(
            id: detail.id, type: .post,
            title: detail.name,
            imageURL: detail.image.cropped.medium,
            categoryName: detail.categories.values.first,
            authorName: detail.author?.name,
            createdAt: detail.createdAt,
            savedAt: Date()
        )
        favorites.toggle(item)
    }

    private func sharePost() {
        guard let post = viewModel.post else { return }
        AnalyticsService.shared.logShare(type: "post", id: post.id)
        let postURL: String
        if post.url.isEmpty {
            postURL = "\(Config.shared.baseURL)/\(post.slug)"
        } else {
            postURL = post.url
        }

        // Top view controller bul
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            var topViewController = rootViewController
            while let presented = topViewController.presentedViewController {
                topViewController = presented
            }
            ShareHelper.sharePost(
                title: post.name,
                url: postURL,
                imageUrl: post.image.cropped.large,
                onViewController: topViewController
            ) { _ in }
        } else {
            ShareHelper.sharePost(
                title: post.name,
                url: postURL,
                imageUrl: post.image.cropped.large
            ) { _ in }
        }
    }

    // MARK: - Helpers

    /// Yaklaşık okuma süresi hesaplar (200 kelime/dakika).
    private func readingTimeMinutes(for post: PostDetail) -> Int {
        let stripped = post.content
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let wordCount = stripped
            .split { !$0.isLetter && !$0.isNumber }
            .count
        return max(1, Int(ceil(Double(wordCount) / 200.0)))
    }
}

// MARK: - Next Story Divider
/// Zincirdeki haberler arasında "Sonraki Haber" geçişini gösteren editorial ayraç.
struct NextStoryDivider: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Rectangle()
                    .fill(Theme.Brand.primary.opacity(0.25))
                    .frame(height: 1)
                Text("SONRAKİ HABER")
                    .scaledFont(size: 10, weight: .bold)
                    .tracking(1.6)
                    .foregroundColor(Theme.Brand.primary)
                Rectangle()
                    .fill(Theme.Brand.primary.opacity(0.25))
                    .frame(height: 1)
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Brand.primary)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xxl)
        .background(Theme.Colors.surface.opacity(0.4))
    }
}

// MARK: - Detail Hero Image
/// Detay sayfası hero — görselin tüm içeriği görünür kalsın diye doğal aspect ratio kullanır.
/// Bütün detay sayfalarında (post/video/gallery/article/bio/interview) ortak kullanılır.
struct DetailHeroImage: View {
    let imageURL: String
    let width: CGFloat
    var placeholderIcon: String = "photo"

    var body: some View {
        AsyncImage(url: URL(string: imageURL)) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Theme.Colors.surface
                    ProgressView().tint(Theme.Colors.textSecondary)
                }
                .frame(width: width, height: width * 9 / 16)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: width)
            case .failure:
                ZStack {
                    LinearGradient(
                        colors: [Theme.Colors.surface, Theme.Colors.surfaceElevated],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: placeholderIcon)
                        .font(.system(size: 32))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                .frame(width: width, height: width * 9 / 16)
            @unknown default:
                Theme.Colors.surface
                    .frame(width: width, height: width * 9 / 16)
            }
        }
    }
}


// MARK: - Category Chips
struct CategoryChipsRow: View {
    let categories: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(categories, id: \.self) { category in
                    Tag(category, color: Theme.Brand.primary, style: .soft)
                }
            }
        }
    }
}

// MARK: - Meta Strip
struct PostMetaStrip: View {
    let post: PostDetail
    let readingTimeMinutes: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Author avatar + name
            if let author = post.author {
                HStack(spacing: Theme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Theme.Brand.primary.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Text(String(author.name.prefix(1)))
                            .scaledFont(size: 15, weight: .bold)
                            .foregroundColor(Theme.Brand.primary)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(author.name)
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Text(formattedDate)
                            .scaledFont(size: 11)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            } else {
                Text(formattedDate)
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            // View count and reading time
            HStack(spacing: Theme.Spacing.md) {
                Label {
                    Text("\(readingTimeMinutes) dk")
                        .scaledFont(size: 11, weight: .semibold)
                } icon: {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                }
                .foregroundColor(Theme.Colors.textSecondary)

                Label {
                    Text("\(post.hit)")
                        .scaledFont(size: 11, weight: .semibold)
                } icon: {
                    Image(systemName: "eye")
                        .font(.system(size: 10))
                }
                .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }

    private var formattedDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFormatter.date(from: post.createdAt)
            ?? ISO8601DateFormatter().date(from: post.createdAt)

        guard let date = date else {
            return String(post.createdAt.prefix(10))
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM yyyy · HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Source Info Card
struct SourceInfoCard: View {
    let post: PostDetail

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Colors.info)

            VStack(alignment: .leading, spacing: 4) {
                if let source = post.source, !source.isEmpty {
                    HStack(spacing: 6) {
                        Text("Kaynak:")
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(source)
                            .scaledFont(size: 12, weight: .medium)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
                if let reporter = post.reporter, !reporter.isEmpty {
                    HStack(spacing: 6) {
                        Text("Muhabir:")
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(reporter)
                            .scaledFont(size: 12, weight: .medium)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
                if let agency = post.agency, !agency.isEmpty {
                    HStack(spacing: 6) {
                        Text("Ajans:")
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(agency)
                            .scaledFont(size: 12, weight: .medium)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
            }

            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.Colors.info.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.info.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Modern Related Post Section
struct ModernRelatedPostSection: View {
    let relatedPost: Post

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.Brand.primary)
                Text("İLGİLİ HABER")
                    .scaledFont(size: 11, weight: .bold)
                    .tracking(1.2)
                    .foregroundColor(Theme.Brand.primary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Group {
                if let type = relatedPost.type?.lowercased() {
                    switch type {
                    case "video":
                        NavigationLink(destination: VideoDetailView(videoId: relatedPost.id)) { card }
                    case "gallery":
                        NavigationLink(destination: GalleryDetailView(galleryId: relatedPost.id)) { card }
                    case "article":
                        NavigationLink(destination: ArticleDetailView(articleId: relatedPost.id, showSideMenu: .constant(false))) { card }
                    default:
                        NavigationLink(destination: PostDetailView(postId: relatedPost.id)) { card }
                    }
                } else {
                    NavigationLink(destination: PostDetailView(postId: relatedPost.id)) { card }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }

    private var card: some View {
        ZStack(alignment: .bottomLeading) {
            ThemedAsyncImage(url: relatedPost.image.cropped.large)
                .frame(height: 200)
                .frame(maxWidth: .infinity)

            ImageGradientOverlay(intensity: 0.95)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let category = relatedPost.categories.values.first {
                    Tag(category, color: Theme.Brand.primary, style: .filled)
                }
                Text(relatedPost.name)
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
            }
            .padding(Theme.Spacing.lg)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .themedShadow(Theme.Shadow.medium)
    }
}

// MARK: - Ad Slot
/// Reklam alanını çevreleyen wrapper. `Config.adsEnabled` false ise hiç render olmaz.
struct AdSlot: View {
    var body: some View {
        if Config.shared.adsEnabled {
            VStack(spacing: 6) {
                Text("REKLAM")
                    .scaledFont(size: 9, weight: .semibold)
                    .tracking(1.0)
                    .foregroundColor(Theme.Colors.textTertiary)

                AdBannerView(adUnitID: AppSettings.shared.resolvedBannerAdUnitId)
                    .frame(height: 50)
            }
            .padding(.vertical, Theme.Spacing.md)
        }
    }
}

// MARK: - Skeleton for Detail
struct PostDetailSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SkeletonBlock(height: 280, cornerRadius: 0)
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SkeletonBlock(height: 14, width: 80, cornerRadius: 7)
                SkeletonBlock(height: 28)
                SkeletonBlock(height: 28, width: 280)
                SkeletonBlock(height: 14)
                SkeletonBlock(height: 14, width: 240)
                Spacer().frame(height: Theme.Spacing.md)
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonBlock(height: 14)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }
}


// MARK: - HTML Content View (themed, font-scale aware)
struct HTMLContentView: UIViewRepresentable {
    let htmlContent: String
    let width: CGFloat
    let hideFirstHeading: Bool
    let scale: CGFloat
    @State private var contentHeight: CGFloat = 400

    init(htmlContent: String, width: CGFloat, hideFirstHeading: Bool = false, scale: CGFloat = 1.0) {
        self.htmlContent = htmlContent
        self.width = width
        self.hideFirstHeading = hideFirstHeading
        self.scale = scale
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "heightChanged")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        var processedContent = htmlContent
        if hideFirstHeading {
            let patterns = [
                #"<h1[^>]*>.*?</h1>"#,
                #"<h2[^>]*>.*?</h2>"#,
                #"<h3[^>]*>.*?</h3>"#
            ]
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
                   let match = regex.firstMatch(in: processedContent, range: NSRange(processedContent.startIndex..., in: processedContent)),
                   let swiftRange = Range(match.range, in: processedContent) {
                    processedContent.removeSubrange(swiftRange)
                    break
                }
            }
        }

        let baseFont = 16.0 * Double(scale)

        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { -webkit-user-select: text; -webkit-touch-callout: default; }
                body {
                    font-family: 'Georgia', 'New York', 'Charter', 'Times New Roman', serif;
                    padding: 4px 20px 16px;
                    margin: 0;
                    font-size: \(baseFont + 1)px;
                    line-height: 1.75;
                    color: #0F1419;
                    background: transparent;
                    text-rendering: optimizeLegibility;
                    -webkit-font-smoothing: antialiased;
                    letter-spacing: 0.01em;
                }
                /* İlk paragrafa drop-cap efekti */
                p:first-of-type::first-letter {
                    font-size: \(baseFont * 3.2)px;
                    font-weight: 800;
                    line-height: 1;
                    float: left;
                    margin: 4px 8px -4px 0;
                    color: #C8102E;
                    font-family: 'Georgia', serif;
                }
                img {
                    max-width: 100%;
                    width: auto;
                    height: auto;
                    display: block;
                    margin: 24px auto;
                    border-radius: 4px;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
                }
                figure { margin: 24px 0; text-align: center; }
                figure img { margin: 0 auto; }
                figcaption {
                    font-size: \(baseFont * 0.85)px;
                    color: #56616D;
                    font-style: italic;
                    font-family: -apple-system, sans-serif;
                    text-align: center;
                    padding: 8px 0 0;
                }
                p { margin: 14px 0; }
                p:first-child { margin-top: 0; }
                h1, h2, h3, h4, h5, h6 {
                    margin: 28px 0 12px 0;
                    font-weight: 800;
                    line-height: 1.25;
                    color: #0F1419;
                    font-family: 'Georgia', 'New York', serif;
                    letter-spacing: -0.01em;
                }
                h1 { font-size: \(baseFont * 1.7)px; }
                h2 { font-size: \(baseFont * 1.45)px; }
                h3 { font-size: \(baseFont * 1.22)px; }
                a {
                    color: #C8102E;
                    text-decoration: none;
                    font-weight: 600;
                    border-bottom: 1px solid rgba(200, 16, 46, 0.35);
                }
                a:hover { border-bottom-color: #C8102E; }
                blockquote {
                    border-left: 3px solid #C8102E;
                    padding: 12px 20px;
                    margin: 24px -4px;
                    color: #0F1419;
                    font-style: italic;
                    font-size: \(baseFont * 1.15)px;
                    line-height: 1.55;
                    background: linear-gradient(90deg, rgba(200, 16, 46, 0.04), transparent);
                }
                blockquote::before {
                    content: '\\201C';
                    font-size: \(baseFont * 2.5)px;
                    color: #C8102E;
                    line-height: 0;
                    vertical-align: -16px;
                    margin-right: 4px;
                    font-family: Georgia, serif;
                }
                ul, ol { padding-left: 28px; margin: 14px 0; }
                li { margin: 8px 0; }
                strong, b { color: #0F1419; font-weight: 700; }
                em, i { color: #2A3038; }
                iframe {
                    max-width: 100%;
                    border-radius: 4px;
                    margin: 24px 0;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 20px 0;
                    font-size: \(baseFont * 0.92)px;
                    font-family: -apple-system, sans-serif;
                }
                th, td {
                    padding: 12px;
                    border-bottom: 0.5px solid #D9D2C8;
                    text-align: left;
                }
                th {
                    background: rgba(200, 16, 46, 0.05);
                    font-weight: 700;
                    border-top: 2px solid #C8102E;
                    border-bottom: 1px solid #C8102E;
                    text-transform: uppercase;
                    font-size: \(baseFont * 0.78)px;
                    letter-spacing: 0.08em;
                    color: #C8102E;
                }
                hr {
                    border: none;
                    text-align: center;
                    margin: 32px 0;
                }
                hr::after {
                    content: '· · ·';
                    color: #B89968;
                    font-size: 20px;
                    letter-spacing: 8px;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: #E8E0D2; }
                    h1, h2, h3, h4, h5, h6, strong, b { color: #F5F2EC; }
                    blockquote {
                        color: #E8E0D2;
                        background: linear-gradient(90deg, rgba(200, 16, 46, 0.10), transparent);
                    }
                    em, i { color: #B8B2A6; }
                    a { color: #E8617A; border-bottom-color: rgba(232, 97, 122, 0.35); }
                    a:hover { border-bottom-color: #E8617A; }
                    th, td { border-color: #2A2F37; }
                    th { background: rgba(232, 97, 122, 0.08); color: #E8617A; border-top-color: #E8617A; border-bottom-color: #E8617A; }
                    figcaption { color: #A8B0BB; border-bottom-color: #2A2F37; }
                    p:first-of-type::first-letter { color: #E8617A; }
                }
                \(hideFirstHeading ? """
                body > h1:first-of-type,
                body > h2:first-of-type,
                body > h3:first-of-type {
                    display: none !important;
                }
                """ : "")
            </style>
            <script>
                window.addEventListener('load', function() {
                    setTimeout(function() {
                        var height = document.body.scrollHeight;
                        window.webkit.messageHandlers.heightChanged.postMessage(height);
                    }, 100);
                });
                window.addEventListener('resize', function() {
                    setTimeout(function() {
                        var height = document.body.scrollHeight;
                        window.webkit.messageHandlers.heightChanged.postMessage(height);
                    }, 100);
                });
            </script>
        </head>
        <body>
            \(processedContent)
        </body>
        </html>
        """

        webView.loadHTMLString(htmlString, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: HTMLContentView

        init(parent: HTMLContentView) {
            self.parent = parent
            super.init()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightChanged", let height = message.body as? Double {
                DispatchQueue.main.async {
                    self.parent.contentHeight = CGFloat(height)
                }
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: WKWebView, context: Context) -> CGSize? {
        return CGSize(width: width, height: contentHeight)
    }
}
