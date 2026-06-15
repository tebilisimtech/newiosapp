import SwiftUI
import Combine
import WebKit

// MARK: - Article Detail View
struct ArticleDetailView: View {
    let articleId: Int
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = ArticleDetailViewModel()
    @StateObject private var userPrefs = UserPreferences.shared
    @State private var scrollProgress: CGFloat = 0

    var body: some View {
        Group {
            if Config.shared.articleOpenMode == .web {
                webBody
            } else {
                nativeBody
            }
        }
        .task {
            await viewModel.loadArticle(id: articleId)
        }
    }

    @ViewBuilder
    private var webBody: some View {
        if let article = viewModel.article,
           let target = ContentURLBuilder.url(rawURL: article.url, slug: article.slug,
                                              medium: "app", campaign: "article") {
            SafariWebView(url: target)
                .ignoresSafeArea()
                .navigationBarHidden(true)
        } else if let error = viewModel.errorMessage {
            ErrorView(message: error) {
                Task { await viewModel.loadArticle(id: articleId) }
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
                        if let article = viewModel.article {
                            content(for: article, width: geometry.size.width)
                        } else if viewModel.isLoading {
                            PostDetailSkeleton()
                                .padding(.top, Theme.Spacing.lg)
                        } else if let error = viewModel.errorMessage {
                            ErrorView(message: error) {
                                Task { await viewModel.loadArticle(id: articleId) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 400)
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadArticle(id: articleId)
                }
                .readingProgress($scrollProgress)
            }

            if viewModel.article != nil {
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
                if viewModel.article != nil {
                    Button(action: shareArticle) {
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
    private func content(for article: ArticleDetail, width: CGFloat) -> some View {
        // Hero — doğal aspect ratio (tam görsel görünür)
        Group {
            if let imageURL = article.imageURL, !imageURL.isEmpty {
                DetailHeroImage(imageURL: imageURL, width: width, placeholderIcon: "pencil.and.outline")
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Theme.Colors.categoryPurple.opacity(0.7), Theme.Brand.primary.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(width: width, height: width * 9 / 16)
            }
        }

        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            // Article tag
            HStack(spacing: Theme.Spacing.sm) {
                Tag("KÖŞE YAZISI", color: Theme.Colors.categoryPurple, style: .filled)
                if let categories = article.categories, let firstCategory = categories.values.first {
                    Tag(firstCategory, color: Theme.Brand.primary, style: .soft)
                }
            }

            // Title (editorial style)
            Text(article.name)
                .scaledFont(size: 28, weight: .bold, design: .serif)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Description / lead
            if let description = article.description, !description.isEmpty {
                Text(description)
                    .scaledFont(size: 17, weight: .medium, design: .serif)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .italic()
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Author byline (editorial)
            if let author = article.author {
                HStack(spacing: Theme.Spacing.md) {
                    Rectangle()
                        .fill(Theme.Brand.primary)
                        .frame(width: 4, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(author.name.uppercased())
                            .scaledFont(size: 13, weight: .bold)
                            .tracking(1.2)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(formattedDate(article.createdAt))
                            .scaledFont(size: 11)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }

                    Spacer()

                    if let hit = article.hit {
                        Label {
                            Text("\(hit)")
                                .scaledFont(size: 11, weight: .semibold)
                        } icon: {
                            Image(systemName: "eye").font(.system(size: 10))
                        }
                        .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            } else {
                HStack {
                    Text(formattedDate(article.createdAt))
                        .scaledFont(size: 12, weight: .medium)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    if let hit = article.hit {
                        Label {
                            Text("\(hit)")
                                .scaledFont(size: 11, weight: .semibold)
                        } icon: {
                            Image(systemName: "eye").font(.system(size: 10))
                        }
                        .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xxl)

        Divider().padding(.horizontal, Theme.Spacing.xl)

        // Content
        if !article.content.isEmpty {
            HTMLContentView(
                htmlContent: article.content,
                width: width,
                scale: userPrefs.fontScale.multiplier
            )
            .frame(width: width)
            .padding(.vertical, Theme.Spacing.sm)
        }

        // Tags
        if let tags = article.tags, !tags.isEmpty {
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

        // Comments
        CommentsView(referenceId: article.id, referenceType: ReferenceType.article.apiValue)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxxl)
    }

    // MARK: - Helpers
    private func formattedDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFormatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
        guard let date = date else { return String(dateString.prefix(10)) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM yyyy · HH:mm"
        return formatter.string(from: date)
    }

    private func shareArticle() {
        guard let article = viewModel.article else { return }
        let articleURL = article.url ?? "\(Config.shared.baseURL)/articles/\(article.id)"
        ShareHelper.sharePost(
            title: article.name,
            url: articleURL,
            imageUrl: article.imageURL
        ) { _ in }
    }
}

