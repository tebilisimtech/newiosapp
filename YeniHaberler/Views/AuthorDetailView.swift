import SwiftUI
import Combine

// MARK: - Author Detail View
struct AuthorDetailView: View {
    let authorId: Int
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = AuthorDetailViewModel()

    var body: some View {
        ZStack {
            Theme.Colors.groupedBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    if let author = viewModel.author {
                        authorHeader(author: author)
                        articlesSection
                    } else if viewModel.isLoading {
                        AuthorDetailSkeleton()
                    } else if let error = viewModel.errorMessage {
                        ErrorView(message: error) {
                            Task {
                                await viewModel.loadAuthor(id: authorId)
                                await viewModel.loadAuthorArticles(authorId: authorId)
                            }
                        }
                        .frame(minHeight: 400)
                    }
                }
                .padding(.bottom, Theme.Spacing.xxxl)
            }
            .refreshable {
                await viewModel.loadAuthor(id: authorId)
                await viewModel.loadAuthorArticles(authorId: authorId)
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
        }
        .task {
            await viewModel.loadAuthor(id: authorId)
            await viewModel.loadAuthorArticles(authorId: authorId)
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func authorHeader(author: AuthorDetail) -> some View {
        ZStack(alignment: .bottom) {
            // Background gradient banner
            LinearGradient(
                colors: [
                    Theme.Brand.primary.opacity(0.85),
                    Theme.Colors.categoryPurple.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)
            .ignoresSafeArea(edges: .top)

            // Avatar overlapping
            VStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.background)
                        .frame(width: 132, height: 132)

                    AsyncImage(url: URL(string: author.avatarURL)) { phase in
                        switch phase {
                        case .empty:
                            Circle()
                                .fill(Theme.Colors.surface)
                                .overlay(ProgressView().tint(Theme.Colors.textSecondary))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Theme.Brand.primary.opacity(0.6), Theme.Colors.categoryPurple.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text(author.name.prefix(1))
                                    .scaledFont(size: 48, weight: .bold)
                                    .foregroundColor(.white)
                            }
                        @unknown default:
                            Circle().fill(Theme.Colors.surface)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                }
                .themedShadow(Theme.Shadow.medium)
                .offset(y: 60)
            }
        }

        VStack(spacing: Theme.Spacing.lg) {
            Spacer().frame(height: 70)

            Text(author.name)
                .scaledFont(size: 24, weight: .bold)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Tag("YAZAR", color: Theme.Brand.primary, style: .filled)

            if let bio = author.bio ?? author.description, !bio.isEmpty {
                Text(bio)
                    .scaledFont(size: 14)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            // Socials
            if let socials = author.socials, hasAnySocial(socials) {
                HStack(spacing: Theme.Spacing.md) {
                    if let fb = socials.facebook, !fb.isEmpty, let url = URL(string: fb) {
                        SocialIconLink(icon: "f.circle.fill", color: Color(hex: "#1877F2"), url: url)
                    }
                    if let tw = socials.twitter, !tw.isEmpty, let url = URL(string: tw) {
                        SocialIconLink(icon: "x.circle.fill", color: Color.black, url: url)
                    }
                    if let ig = socials.instagram, !ig.isEmpty, let url = URL(string: ig) {
                        SocialIconLink(icon: "camera.circle.fill", color: Color(hex: "#E4405F"), url: url)
                    }
                }
            }

            // Stats
            HStack(spacing: 0) {
                AuthorStatCell(value: "\(viewModel.articles.count)", label: "Makale", icon: "doc.text.fill", color: Theme.Brand.primary)
                Divider().frame(height: 40)
                AuthorStatCell(
                    value: lastArticleRelativeDate(author),
                    label: "Son Yazı",
                    icon: "clock.fill",
                    color: Theme.Colors.info
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .fill(Theme.Colors.surface)
            )
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }

    private func hasAnySocial(_ s: AuthorSocials) -> Bool {
        !(s.facebook ?? "").isEmpty || !(s.twitter ?? "").isEmpty || !(s.instagram ?? "").isEmpty
    }

    private func lastArticleRelativeDate(_ author: AuthorDetail) -> String {
        guard let dateString = author.lastArticle?.createdAt else { return "—" }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFormatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
        guard let date = date else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Articles
    private var articlesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.Brand.primary)
                Text("Makaleler")
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundColor(Theme.Colors.textPrimary)
                if viewModel.isLoadingArticles {
                    ProgressView().scaleEffect(0.8)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.xl)

            if viewModel.articles.isEmpty && !viewModel.isLoadingArticles {
                EmptyStateView(
                    icon: "doc.text",
                    title: "Henüz Makale Yok",
                    message: "Bu yazarın henüz yayımlanmış makalesi bulunmuyor."
                )
                .frame(minHeight: 240)
            } else {
                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(viewModel.articles) { article in
                        NavigationLink(destination: ArticleDetailView(articleId: article.id, showSideMenu: $showSideMenu)) {
                            ArticleCard(article: article)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
        }
    }
}

// MARK: - Social Icon Link
struct SocialIconLink: View {
    let icon: String
    let color: Color
    let url: URL

    var body: some View {
        Link(destination: url) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
        }
    }
}

// MARK: - Author Stat Cell
struct AuthorStatCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Text(value)
                    .scaledFont(size: 14, weight: .bold)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            Text(label)
                .scaledFont(size: 11, weight: .medium)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Article Card (modern)
struct ArticleCard: View {
    let article: AuthorArticle

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Image
            Group {
                if let imageURL = article.imageURL, !imageURL.isEmpty {
                    ThemedAsyncImage(url: imageURL)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Brand.primary.opacity(0.18), Theme.Colors.categoryPurple.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.Brand.primary.opacity(0.5))
                    }
                }
            }
            .frame(width: 110, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

            // Text
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Tag("MAKALE", color: Theme.Colors.categoryPurple, style: .soft)
                Text(article.name)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.textTertiary)
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

// MARK: - Author Detail Skeleton
struct AuthorDetailSkeleton: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            SkeletonBlock(height: 180, cornerRadius: 0)
            VStack(spacing: Theme.Spacing.md) {
                Circle()
                    .fill(Theme.Colors.borderSubtle)
                    .frame(width: 120, height: 120)
                    .offset(y: -60)
                    .padding(.bottom, -60)
                SkeletonBlock(height: 22, width: 200)
                SkeletonBlock(height: 12, width: 280)
                SkeletonBlock(height: 12, width: 240)
            }
            ForEach(0..<3, id: \.self) { _ in
                HStack {
                    SkeletonBlock(height: 90, width: 110, cornerRadius: Theme.Radius.md)
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        SkeletonBlock(height: 12, width: 80)
                        SkeletonBlock(height: 14)
                        SkeletonBlock(height: 14, width: 200)
                    }
                }
                .padding()
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }
}

