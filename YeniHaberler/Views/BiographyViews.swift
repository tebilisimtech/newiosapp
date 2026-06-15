import SwiftUI
import Combine
import WebKit

// MARK: - Biography List View
struct BiographyListView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = BiographyListViewModel()

    var body: some View {
        ListScreen(
            title: "Biyografiler",
            items: viewModel.biographies,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            emptyConfig: EmptyConfig(
                icon: "person.text.rectangle",
                title: "Biyografi Yok",
                message: "Şu anda görüntülenecek biyografi bulunmuyor."
            ),
            skeletonCount: 4,
            itemSpacing: Theme.Spacing.md,
            onRefresh: { await viewModel.loadBiographies() },
            onLoadMore: { await viewModel.loadMore() },
            isLoadingMore: viewModel.pagination.isLoadingMore,
            onRetry: { await viewModel.loadBiographies() }
        ) { biography in
            NavigationLink(destination: BiographyDetailView(biographyId: biography.id, showSideMenu: $showSideMenu)) {
                BiographyListCard(biography: biography)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .task {
            if viewModel.biographies.isEmpty {
                await viewModel.loadBiographies()
            }
        }
    }
}

// MARK: - Biography List Card
struct BiographyListCard: View {
    let biography: Biography

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let imageURL = biography.image?.cropped.medium, !imageURL.isEmpty {
                        ThemedAsyncImage(url: imageURL)
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Colors.categoryPurple.opacity(0.25), Theme.Colors.categoryPurple.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: "person.text.rectangle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 110, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

                Tag("BİYOGRAFİ", color: Theme.Colors.categoryPurple, style: .filled)
                    .scaleEffect(0.78)
                    .padding(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(biography.name)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = biography.description, !description.isEmpty {
                    Text(description)
                        .scaledFont(size: 12)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                HStack(spacing: Theme.Spacing.sm) {
                    if let author = biography.author {
                        Label {
                            Text(author.name).scaledFont(size: 11, weight: .medium)
                        } icon: {
                            Image(systemName: "person.fill").font(.system(size: 9))
                        }
                        .foregroundColor(Theme.Colors.textTertiary)
                        .lineLimit(1)
                    }
                    Spacer()
                    Text(biography.createdAt.prefix(10))
                        .scaledFont(size: 11)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 100)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - Biography Detail View
struct BiographyDetailView: View {
    let biographyId: Int
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = BiographyDetailViewModel()
    @StateObject private var userPrefs = UserPreferences.shared
    @State private var scrollProgress: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Colors.background.ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let biography = viewModel.biography {
                            content(for: biography, width: geometry.size.width)
                        } else if viewModel.isLoading {
                            PostDetailSkeleton().padding(.top, Theme.Spacing.lg)
                        } else if let error = viewModel.errorMessage {
                            ErrorView(message: error) {
                                Task { await viewModel.loadBiography(id: biographyId) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 400)
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadBiography(id: biographyId)
                }
                .readingProgress($scrollProgress)
            }

            if viewModel.biography != nil {
                ReadingProgressBar(progress: scrollProgress)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { LogoView() }

            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { withAnimation { showSideMenu.toggle() } }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title3)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .accessibilityLabel("Menüyü aç")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.biography != nil {
                    Button(action: shareBiography) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .accessibilityLabel("Paylaş")
                    }
                }
            }
        }
        .task {
            await viewModel.loadBiography(id: biographyId)
        }
    }

    @ViewBuilder
    private func content(for biography: BiographyDetail, width: CGFloat) -> some View {
        // Hero — doğal aspect ratio
        Group {
            if let imageURL = biography.imageURL, !imageURL.isEmpty {
                DetailHeroImage(imageURL: imageURL, width: width, placeholderIcon: "person.text.rectangle.fill")
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Theme.Colors.categoryPurple.opacity(0.65), Theme.Colors.categoryPurple.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(width: width, height: width * 9 / 16)
            }
        }

        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.sm) {
                Tag("BİYOGRAFİ", color: Theme.Colors.categoryPurple, style: .filled)
                if let categories = biography.categories, let first = categories.values.first {
                    Tag(first, color: Theme.Brand.primary, style: .soft)
                }
            }

            Text(biography.name)
                .scaledFont(size: 26, weight: .bold)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let description = biography.description, !description.isEmpty {
                Text(description)
                    .scaledFont(size: 16, weight: .medium)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            metaStrip(biography: biography)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xl)

        Divider().padding(.horizontal, Theme.Spacing.xl)

        if !biography.content.isEmpty {
            HTMLContentView(
                htmlContent: biography.content,
                width: width,
                scale: userPrefs.fontScale.multiplier
            )
            .frame(width: width)
            .padding(.vertical, Theme.Spacing.sm)
        }

        if let tags = biography.tags, !tags.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Etiketler", icon: "tag.fill")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(tags, id: \.self) { tag in
                            Tag("#\(tag)", color: Theme.Colors.textSecondary, style: .soft)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }
            }
            .padding(.top, Theme.Spacing.xl)
        }

        if !viewModel.related.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(title: "İlgili Biyografiler", icon: "person.2.fill")
                    .padding(.horizontal, Theme.Spacing.xl)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                        ForEach(viewModel.related) { bio in
                            NavigationLink(destination: BiographyDetailView(biographyId: bio.id, showSideMenu: $showSideMenu)) {
                                EditorialBiographyTile(biography: bio)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }
            }
            .padding(.top, Theme.Spacing.xl)
        }

        CommentsView(referenceId: biography.id, referenceType: ReferenceType.biography.apiValue)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxxl)
    }

    @ViewBuilder
    private func metaStrip(biography: BiographyDetail) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            if let author = biography.author {
                HStack(spacing: Theme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.categoryPurple.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Text(String(author.name.prefix(1)))
                            .scaledFont(size: 13, weight: .bold)
                            .foregroundColor(Theme.Colors.categoryPurple)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(author.name)
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Text(biography.createdAt.prefix(10))
                            .scaledFont(size: 11)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            } else {
                Text(biography.createdAt.prefix(10))
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            if let hit = biography.hit {
                Label {
                    Text("\(hit)").scaledFont(size: 11, weight: .semibold)
                } icon: {
                    Image(systemName: "eye").font(.system(size: 10))
                }
                .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }

    private func shareBiography() {
        guard let biography = viewModel.biography else { return }
        let url = biography.url ?? "\(Config.shared.baseURL)/biographies/\(biography.id)"
        ShareHelper.sharePost(title: biography.name, url: url, imageUrl: biography.imageURL) { _ in }
    }
}

