import SwiftUI
import Combine
import GoogleMobileAds

// MARK: - Gallery Detail View
struct GalleryDetailView: View {
    let galleryId: Int
    @StateObject private var viewModel = GalleryDetailViewModel()
    @StateObject private var favorites = FavoritesService.shared
    @StateObject private var userPrefs = UserPreferences.shared

    @State private var selectedPhotoIndex: Int = 0
    @State private var showPhotoViewer = false
    @State private var selectedTab: Int = 0  // 0: Galeri, 1: Bilgi
    @State private var scrollProgress: CGFloat = 0

    private var isFavorited: Bool {
        favorites.isGalleryFavorited(galleryId)
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
            await viewModel.loadGallery(id: galleryId)
            if let gallery = viewModel.gallery {
                ReadingHistoryService.shared.recordGallery(
                    id: gallery.id, title: gallery.name,
                    imageURL: gallery.image.cropped.medium,
                    category: gallery.categories.values.first
                )
            }
        }
    }

    @ViewBuilder
    private var webBody: some View {
        if let gallery = viewModel.gallery,
           let target = ContentURLBuilder.url(rawURL: gallery.url, slug: gallery.slug,
                                              medium: "app", campaign: "gallery") {
            SafariWebView(url: target)
                .ignoresSafeArea()
                .navigationBarHidden(true)
        } else if let error = viewModel.errorMessage {
            ErrorView(message: error) {
                Task { await viewModel.loadGallery(id: galleryId) }
            }
        } else {
            PostDetailSkeleton().padding(.top, Theme.Spacing.lg)
        }
    }

    private var nativeBody: some View {
        ZStack(alignment: .top) {
            Theme.Colors.background.ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let gallery = viewModel.gallery {
                            content(for: gallery, width: geometry.size.width)
                        } else if viewModel.isLoading {
                            PostDetailSkeleton()
                                .padding(.top, Theme.Spacing.lg)
                        } else if let error = viewModel.errorMessage {
                            ErrorView(message: error) {
                                Task { await viewModel.loadGallery(id: galleryId) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 400)
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadGallery(id: galleryId)
                }
                .readingProgress($scrollProgress)
            }

            if viewModel.gallery != nil {
                ReadingProgressBar(progress: scrollProgress)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { LogoView() }

            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.gallery != nil {
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorited ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isFavorited ? Theme.Brand.primary : Theme.Colors.textPrimary)
                            .accessibilityLabel(isFavorited ? "Yer imini kaldır" : "Yer imine ekle")
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.gallery != nil {
                    Button(action: shareGallery) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .accessibilityLabel("Paylaş")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showPhotoViewer) {
            if let gallery = viewModel.gallery {
                PhotoGalleryViewer(
                    photos: gallery.photos.map { $0.img },
                    descriptions: gallery.photos.map { $0.description ?? "" },
                    currentIndex: $selectedPhotoIndex
                )
            }
        }
    }

    // MARK: - Content
    @ViewBuilder
    private func content(for gallery: GalleryDetail, width: CGFloat) -> some View {
        // Hero
        ZStack(alignment: .bottomTrailing) {
            DetailHeroImage(imageURL: gallery.image.cropped.large, width: width)

            // Photo count badge
            HStack(spacing: 6) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(gallery.photos.count) Fotoğraf")
                    .scaledFont(size: 12, weight: .bold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Capsule().fill(Color.black.opacity(0.7)))
            .padding(Theme.Spacing.lg)
        }

        // Galeri Detay - Hero Görsel Altı (#2020)
        AdPlacement(channel: AdChannel.galleryHero)

        // Title section (editorial)
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.sm) {
                PillTag(text: "GALERİ", icon: "photo.fill", color: Theme.Colors.info, style: .filled)
                if let category = gallery.categories.values.first {
                    EditorialEyebrow(text: category, showDot: false)
                }
            }

            Text(gallery.name)
                .scaledFont(size: 26, weight: .heavy, design: .serif)
                .foregroundColor(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(3)

            if let description = gallery.description, !description.isEmpty {
                Text(description)
                    .scaledFont(size: 16, weight: .regular, design: .serif)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .italic()
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            EditorialDivider(withGlyph: true)

            galleryMetaStrip(gallery: gallery)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xl)

        // Galeri Detay - Başlık Altı (#2021)
        AdPlacement(channel: AdChannel.galleryTitle)

        // Photos header
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.Brand.primary)
            Text("Galeri")
                .scaledFont(size: 18, weight: .bold)
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
            Text("\(gallery.photos.count)")
                .scaledFont(size: 12, weight: .bold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.Brand.primary))
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.md)

        // Photos list
        LazyVStack(spacing: Theme.Spacing.xl) {
            ForEach(Array(gallery.photos.enumerated()), id: \.element.id) { index, photo in
                photoCard(photo: photo, index: index, total: gallery.photos.count, width: width)

                // Galeri Detay - Fotoğraflar Arası (#2022) — her 3 fotoğraftan sonra
                if (index + 1) % 3 == 0 && index < gallery.photos.count - 1 {
                    AdPlacement(channel: AdChannel.galleryBetweenPhotos)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)

        // Galeri Detay - Yorumlar Öncesi (#2023)
        AdPlacement(channel: AdChannel.galleryBeforeComments)
            .padding(.top, Theme.Spacing.lg)

        // Comments
        CommentsView(referenceId: gallery.id, referenceType: ReferenceType.gallery.apiValue)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxxl)
    }

    @ViewBuilder
    private func photoCard(photo: GalleryPhoto, index: Int, total: Int, width: CGFloat) -> some View {
        Button(action: {
            selectedPhotoIndex = index
            showPhotoViewer = true
        }) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    AspectImage(url: photo.img, aspectRatio: 16/10)

                    // Photo number badge
                    Text("\(index + 1) / \(total)")
                        .scaledFont(size: 11, weight: .bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .padding(Theme.Spacing.md)

                    // Expand icon
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack {
                                Circle().fill(Color.black.opacity(0.55))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(Theme.Spacing.md)
                        }
                    }
                }

                if let description = photo.description, !description.isEmpty {
                    Text(description)
                        .scaledFont(size: 14)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Theme.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .fill(Theme.Colors.surface)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
            )
            .themedShadow(Theme.Shadow.small)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func galleryMetaStrip(gallery: GalleryDetail) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            if let author = gallery.author {
                HStack(spacing: Theme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.info.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Text(String(author.name.prefix(1)))
                            .scaledFont(size: 13, weight: .bold)
                            .foregroundColor(Theme.Colors.info)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(author.name)
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Text(String(gallery.createdAt.prefix(10)))
                            .scaledFont(size: 11)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            } else {
                Text(String(gallery.createdAt.prefix(10)))
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            Label {
                Text("\(gallery.hit)")
                    .scaledFont(size: 11, weight: .semibold)
            } icon: {
                Image(systemName: "eye").font(.system(size: 10))
            }
            .foregroundColor(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Actions
    private func toggleFavorite() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        guard let gallery = viewModel.gallery else { return }
        favorites.toggleGallery(
            id: gallery.id, title: gallery.name,
            imageURL: gallery.image.cropped.medium,
            category: gallery.categories.values.first,
            createdAt: gallery.createdAt
        )
    }

    private func shareGallery() {
        guard let gallery = viewModel.gallery else { return }
        ShareHelper.shareGallery(
            title: gallery.name,
            url: gallery.url,
            imageUrl: gallery.image.cropped.large
        ) { _ in }
    }
}


// MARK: - Gallery List View
struct GalleryListView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = GalleryListViewModel()

    var body: some View {
        NavigationView {
            ListScreen(
                title: "Foto Galeri",
                displayMode: .inline,
                showLogo: true,
                items: viewModel.galleries,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                emptyConfig: EmptyConfig(
                    icon: "photo.on.rectangle",
                    title: "Galeri Yok",
                    message: "Şu anda görüntülenecek foto galeri bulunmuyor."
                ),
                skeletonCount: 4,
                itemSpacing: Theme.Spacing.lg,
                onRefresh: { await viewModel.loadGalleries() },
                onLoadMore: { await viewModel.loadMore() },
                isLoadingMore: viewModel.pagination.isLoadingMore,
                onRetry: { await viewModel.loadGalleries() },
                showSideMenu: $showSideMenu
            ) { gallery in
                NavigationLink(destination: GalleryDetailView(galleryId: gallery.id)) {
                    GalleryListCard(gallery: gallery)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .task {
                if viewModel.galleries.isEmpty {
                    await viewModel.loadGalleries()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Gallery List Card
struct GalleryListCard: View {
    let gallery: Gallery

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                AspectImage(url: gallery.image.cropped.large, aspectRatio: 16/10)

                HStack(spacing: 4) {
                    Image(systemName: "photo.stack.fill").font(.system(size: 10, weight: .bold))
                    Text("GALERİ").scaledFont(size: 10, weight: .bold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 5)
                .background(Capsule().fill(Theme.Colors.info))
                .padding(Theme.Spacing.md)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let category = gallery.categories.values.first {
                    Text(category.uppercased())
                        .scaledFont(size: 10, weight: .bold)
                        .tracking(0.5)
                        .foregroundColor(Theme.Brand.primary)
                        .lineLimit(1)
                }

                Text(gallery.name)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = gallery.description, !description.isEmpty {
                    Text(description)
                        .scaledFont(size: 13)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: Theme.Spacing.md) {
                    if let author = gallery.author {
                        Label {
                            Text(author.name).scaledFont(size: 11, weight: .medium)
                        } icon: {
                            Image(systemName: "person.fill").font(.system(size: 9))
                        }
                        .foregroundColor(Theme.Colors.textTertiary)
                        .lineLimit(1)
                    }

                    Spacer()

                    Text(gallery.createdAt.prefix(10))
                        .scaledFont(size: 11)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .themedShadow(Theme.Shadow.small)
    }
}

