import SwiftUI
import Combine
import WebKit
import SafariServices
import GoogleMobileAds

// MARK: - Video List View
struct VideoListView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = VideoListViewModel()

    var body: some View {
        NavigationView {
            ListScreen(
                title: "Videolar",
                displayMode: .inline,
                showLogo: true,
                items: viewModel.videos,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                emptyConfig: EmptyConfig(
                    icon: "play.slash",
                    title: "Video Yok",
                    message: "Şu anda görüntülenecek video bulunmuyor."
                ),
                itemSpacing: Theme.Spacing.lg,
                onRefresh: { await viewModel.loadVideos() },
                onLoadMore: { await viewModel.loadMore() },
                isLoadingMore: viewModel.pagination.isLoadingMore,
                onRetry: { await viewModel.loadVideos() },
                showSideMenu: $showSideMenu,
                skeleton: { VideoListSkeleton() }
            ) { video in
                NavigationLink(destination: VideoDetailView(videoId: video.id)) {
                    VideoCard(video: video)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .task {
                if viewModel.videos.isEmpty {
                    await viewModel.loadVideos()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Video List Skeleton
struct VideoListSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 0) {
                        SkeletonBlock(height: 200, cornerRadius: 0)
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            SkeletonBlock(height: 12, width: 80, cornerRadius: 6)
                            SkeletonBlock(height: 16)
                            SkeletonBlock(height: 16, width: 220)
                        }
                        .padding(Theme.Spacing.md)
                    }
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.md)
        }
    }
}


// MARK: - Video Detail View
struct VideoDetailView: View {
    let videoId: Int
    @StateObject private var viewModel = VideoDetailViewModel()
    @StateObject private var favorites = FavoritesService.shared
    @StateObject private var userPrefs = UserPreferences.shared
    @Environment(\.dismiss) var dismiss
    @State private var scrollProgress: CGFloat = 0

    private var isFavorited: Bool {
        favorites.isVideoFavorited(videoId)
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
            await viewModel.loadVideo(id: videoId)
            if let video = viewModel.video {
                ReadingHistoryService.shared.recordVideo(
                    id: video.id, title: video.name,
                    imageURL: video.image.cropped.medium,
                    category: video.categories.values.first
                )
            }
        }
    }

    @ViewBuilder
    private var webBody: some View {
        if let video = viewModel.video,
           let target = ContentURLBuilder.url(rawURL: video.url, slug: video.slug,
                                              medium: "app", campaign: "video") {
            SafariWebView(url: target)
                .ignoresSafeArea()
                .navigationBarHidden(true)
        } else if let error = viewModel.errorMessage {
            ErrorView(message: error) {
                Task { await viewModel.loadVideo(id: videoId) }
            }
        } else {
            VideoDetailSkeleton(width: UIScreen.main.bounds.width)
        }
    }

    private var nativeBody: some View {
        ZStack(alignment: .top) {
            Theme.Colors.background.ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let video = viewModel.video {
                            content(for: video, width: geometry.size.width)
                        } else if viewModel.isLoading {
                            VideoDetailSkeleton(width: geometry.size.width)
                        } else if let error = viewModel.errorMessage {
                            ErrorView(message: error) {
                                Task { await viewModel.loadVideo(id: videoId) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 400)
                        }
                    }
                }
                .readingProgress($scrollProgress)
            }

            if viewModel.video != nil {
                ReadingProgressBar(progress: scrollProgress)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { LogoView() }

            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.video != nil {
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorited ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isFavorited ? Theme.Brand.primary : Theme.Colors.textPrimary)
                            .accessibilityLabel(isFavorited ? "Yer imini kaldır" : "Yer imine ekle")
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.video != nil {
                    Button(action: shareVideo) {
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
    private func content(for video: VideoDetail, width: CGFloat) -> some View {
        // Video player — embed/url'den platformu otomatik tespit edip uygun inline
        // oynatıcıyı kullanır (YouTube IFrame / Dailymotion / Vimeo / AVPlayer).
        InlineVideoPlayer(
            source: VideoSource.detect(embed: video.embed, url: video.url, mediaUrl: video.mediaUrl),
            posterURL: video.image.cropped.large,
            fallbackURL: URL(string: video.url)
        )
        .frame(width: width, height: width * 9 / 16)
        .background(Color.black)

        // Video Detay - Hero/Video Altı (#2017)
        AdPlacement(channel: AdChannel.videoHero)

        // Title section (editorial)
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.sm) {
                PillTag(text: "VİDEO", icon: "play.fill", color: Theme.Brand.primary, style: .filled)
                if let category = video.categories.values.first {
                    EditorialEyebrow(text: category, showDot: false)
                }
            }

            Text(video.name)
                .scaledFont(size: 26, weight: .heavy, design: .serif)
                .foregroundColor(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(3)

            if let description = video.description, !description.isEmpty {
                Text(description)
                    .scaledFont(size: 16, weight: .regular, design: .serif)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .italic()
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            EditorialDivider(withGlyph: true)

            VideoMetaStrip(video: video)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xl)

        // Video Detay - Başlık Altı (#2018)
        AdPlacement(channel: AdChannel.videoTitle)

        // Source info
        if video.source != nil || video.reporter != nil {
            videoSourceInfo(video: video)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.lg)
        }

        // HTML content
        if let content = video.content, !content.isEmpty {
            Divider().padding(.horizontal, Theme.Spacing.xl)

            HTMLContentView(
                htmlContent: content,
                width: width,
                hideFirstHeading: true,
                scale: userPrefs.fontScale.multiplier
            )
            .frame(width: width)
            .padding(.vertical, Theme.Spacing.sm)

            // Video Detay - İçerik Altı (#2019)
            AdPlacement(channel: AdChannel.videoContentBottom)
        }

        // Comments
        CommentsView(referenceId: video.id, referenceType: ReferenceType.video.apiValue)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxxl)
    }

    @ViewBuilder
    private func videoSourceInfo(video: VideoDetail) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Colors.info)

            VStack(alignment: .leading, spacing: 4) {
                if let source = video.source, !source.isEmpty {
                    HStack(spacing: 6) {
                        Text("Kaynak:")
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(source)
                            .scaledFont(size: 12, weight: .medium)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
                if let reporter = video.reporter, !reporter.isEmpty {
                    HStack(spacing: 6) {
                        Text("Muhabir:")
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(reporter)
                            .scaledFont(size: 12, weight: .medium)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.Colors.info.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Colors.info.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Actions
    private func toggleFavorite() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        guard let video = viewModel.video else { return }
        favorites.toggleVideo(
            id: video.id, title: video.name,
            imageURL: video.image.cropped.medium,
            category: video.categories.values.first,
            createdAt: video.createdAt
        )
    }

    private func shareVideo() {
        guard let video = viewModel.video else { return }
        ShareHelper.sharePost(
            title: video.name,
            url: video.url,
            imageUrl: video.image.cropped.large
        ) { _ in }
    }

}

// MARK: - Video Meta Strip
struct VideoMetaStrip: View {
    let video: VideoDetail

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Author or source
            if let author = video.author, !author.name.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: Theme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Theme.Brand.primary.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Text(String(author.name.prefix(1)))
                            .scaledFont(size: 13, weight: .bold)
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

            Label {
                Text("\(video.hit)")
                    .scaledFont(size: 11, weight: .semibold)
            } icon: {
                Image(systemName: "eye").font(.system(size: 10))
            }
            .foregroundColor(Theme.Colors.textSecondary)
        }
    }

    private var formattedDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFormatter.date(from: video.createdAt)
            ?? ISO8601DateFormatter().date(from: video.createdAt)
        guard let date = date else { return String(video.createdAt.prefix(10)) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM yyyy · HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Video Detail Skeleton
struct VideoDetailSkeleton: View {
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SkeletonBlock(height: width * 9 / 16, cornerRadius: 0)
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SkeletonBlock(height: 14, width: 100)
                SkeletonBlock(height: 24)
                SkeletonBlock(height: 24, width: 280)
                SkeletonBlock(height: 14)
                SkeletonBlock(height: 14, width: 200)
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredControlTintColor = .red
        safariVC.preferredBarTintColor = .white
        safariVC.dismissButtonStyle = .close
        return safariVC
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

