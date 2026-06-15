import SwiftUI
import Combine
import WebKit

// MARK: - Interview List View
struct InterviewListView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = InterviewListViewModel()

    var body: some View {
        ListScreen(
            title: "Röportajlar",
            items: viewModel.interviews,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            emptyConfig: EmptyConfig(
                icon: "mic.slash",
                title: "Röportaj Yok",
                message: "Şu anda görüntülenecek röportaj bulunmuyor."
            ),
            skeletonCount: 4,
            itemSpacing: Theme.Spacing.md,
            onRefresh: { await viewModel.loadInterviews() },
            onLoadMore: { await viewModel.loadMore() },
            isLoadingMore: viewModel.pagination.isLoadingMore,
            onRetry: { await viewModel.loadInterviews() }
        ) { interview in
            NavigationLink(destination: InterviewDetailView(interviewId: interview.id, showSideMenu: $showSideMenu)) {
                InterviewListCard(interview: interview)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .task {
            if viewModel.interviews.isEmpty {
                await viewModel.loadInterviews()
            }
        }
    }
}

// MARK: - Interview List Card
struct InterviewListCard: View {
    let interview: Interview

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let imageURL = interview.image?.cropped.medium, !imageURL.isEmpty {
                        ThemedAsyncImage(url: imageURL)
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Colors.warning.opacity(0.25), Theme.Colors.warning.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 110, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

                Tag("RÖPORTAJ", color: Theme.Colors.warning, style: .filled)
                    .scaleEffect(0.78)
                    .padding(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(interview.name)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = interview.description, !description.isEmpty {
                    Text(description)
                        .scaledFont(size: 12)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                HStack(spacing: Theme.Spacing.sm) {
                    if let author = interview.author {
                        Label {
                            Text(author.name).scaledFont(size: 11, weight: .medium)
                        } icon: {
                            Image(systemName: "person.fill").font(.system(size: 9))
                        }
                        .foregroundColor(Theme.Colors.textTertiary)
                        .lineLimit(1)
                    }
                    Spacer()
                    Text(interview.createdAt.prefix(10))
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

// MARK: - Interview Detail View
struct InterviewDetailView: View {
    let interviewId: Int
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = InterviewDetailViewModel()
    @StateObject private var userPrefs = UserPreferences.shared
    @State private var scrollProgress: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Colors.background.ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let interview = viewModel.interview {
                            content(for: interview, width: geometry.size.width)
                        } else if viewModel.isLoading {
                            PostDetailSkeleton().padding(.top, Theme.Spacing.lg)
                        } else if let error = viewModel.errorMessage {
                            ErrorView(message: error) {
                                Task { await viewModel.loadInterview(id: interviewId) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 400)
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadInterview(id: interviewId)
                }
                .readingProgress($scrollProgress)
            }

            if viewModel.interview != nil {
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
                if viewModel.interview != nil {
                    Button(action: shareInterview) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .accessibilityLabel("Paylaş")
                    }
                }
            }
        }
        .task {
            await viewModel.loadInterview(id: interviewId)
        }
    }

    @ViewBuilder
    private func content(for interview: InterviewDetail, width: CGFloat) -> some View {
        // Hero — doğal aspect ratio
        Group {
            if let imageURL = interview.imageURL, !imageURL.isEmpty {
                DetailHeroImage(imageURL: imageURL, width: width, placeholderIcon: "mic.fill")
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Theme.Colors.warning.opacity(0.7), Theme.Colors.warning.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "mic.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(width: width, height: width * 9 / 16)
            }
        }

        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.sm) {
                Tag("RÖPORTAJ", color: Theme.Colors.warning, style: .filled)
                if let categories = interview.categories, let first = categories.values.first {
                    Tag(first, color: Theme.Brand.primary, style: .soft)
                }
            }

            Text(interview.name)
                .scaledFont(size: 26, weight: .bold)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let description = interview.description, !description.isEmpty {
                Text(description)
                    .scaledFont(size: 16, weight: .medium)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            metaStrip(interview: interview)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xl)

        Divider().padding(.horizontal, Theme.Spacing.xl)

        if !interview.content.isEmpty {
            HTMLContentView(
                htmlContent: interview.content,
                width: width,
                scale: userPrefs.fontScale.multiplier
            )
            .frame(width: width)
            .padding(.vertical, Theme.Spacing.sm)
        }

        if let tags = interview.tags, !tags.isEmpty {
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
                SectionHeader(title: "İlgili Röportajlar", icon: "mic.fill")
                    .padding(.horizontal, Theme.Spacing.xl)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                        ForEach(viewModel.related) { item in
                            NavigationLink(destination: InterviewDetailView(interviewId: item.id, showSideMenu: $showSideMenu)) {
                                EditorialInterviewTile(interview: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }
            }
            .padding(.top, Theme.Spacing.xl)
        }

        CommentsView(referenceId: interview.id, referenceType: ReferenceType.interview.apiValue)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxxl)
    }

    @ViewBuilder
    private func metaStrip(interview: InterviewDetail) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            if let author = interview.author {
                HStack(spacing: Theme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.warning.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Text(String(author.name.prefix(1)))
                            .scaledFont(size: 13, weight: .bold)
                            .foregroundColor(Theme.Colors.warning)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(author.name)
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Text(interview.createdAt.prefix(10))
                            .scaledFont(size: 11)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            } else {
                Text(interview.createdAt.prefix(10))
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            if let hit = interview.hit {
                Label {
                    Text("\(hit)").scaledFont(size: 11, weight: .semibold)
                } icon: {
                    Image(systemName: "eye").font(.system(size: 10))
                }
                .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }

    private func shareInterview() {
        guard let interview = viewModel.interview else { return }
        let url = interview.url ?? "\(Config.shared.baseURL)/interviews/\(interview.id)"
        ShareHelper.sharePost(title: interview.name, url: url, imageUrl: interview.imageURL) { _ in }
    }
}

