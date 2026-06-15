import SwiftUI
import Combine
import os

// MARK: - App Tab
enum AppTab: Int, CaseIterable, Identifiable {
    case home = 0
    case breaking
    case videos
    case galleries
    case search

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .home:      return "house.fill"
        case .breaking:  return "bolt.fill"
        case .videos:    return "play.rectangle.fill"
        case .galleries: return "photo.on.rectangle.angled"
        case .search:    return "magnifyingglass"
        }
    }

    var title: String {
        switch self {
        case .home:      return "Ana Sayfa"
        case .breaking:  return "Son Dakika"
        case .videos:    return "Videolar"
        case .galleries: return "Galeri"
        case .search:    return "Ara"
        }
    }
}

// MARK: - Bottom Tab View
struct BottomTabView: View {
    @Binding var showSideMenu: Bool
    @Binding var selectedTab: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            // Ana içerik
            Group {
                switch selectedTab {
                case AppTab.home.rawValue:      NewHomeView(showSideMenu: $showSideMenu)
                case AppTab.breaking.rawValue:  BreakingNewsView(showSideMenu: $showSideMenu)
                case AppTab.videos.rawValue:    VideoFeedView(showSideMenu: $showSideMenu)
                case AppTab.galleries.rawValue: GalleryListView(showSideMenu: $showSideMenu)
                case AppTab.search.rawValue:    SearchView(showSideMenu: $showSideMenu)
                default:                         NewHomeView(showSideMenu: $showSideMenu)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating editorial tab bar
            ModernTabBar(selectedTab: $selectedTab)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .frame(height: 64)
        }
    }
}

// MARK: - Editorial Floating Tab Bar
/// Kenarlardan boşluklu, glassy, pill şeklinde modern tab bar.
struct ModernTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 2) {
                ForEach(AppTab.allCases) { tab in
                    ModernTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab.rawValue,
                        animation: animation,
                        reduceMotion: reduceMotion
                    ) {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        if reduceMotion {
                            selectedTab = tab.rawValue
                        } else {
                            withAnimation(Theme.Animations.snappy) {
                                selectedTab = tab.rawValue
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(tabBarBackground)
            .themedShadow(Theme.Shadow.floatingBar)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.sm)
        }
    }

    @ViewBuilder
    private var tabBarBackground: some View {
        if reduceTransparency {
            // Şeffaflık devre dışıyken solid surface
            ZStack {
                Capsule()
                    .fill(Theme.Colors.surface)
                Capsule()
                    .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
            }
        } else {
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(Theme.Colors.surface.opacity(0.7))
                Capsule()
                    .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Modern Tab Button
struct ModernTabButton: View {
    let tab: AppTab
    let isSelected: Bool
    var animation: Namespace.ID
    var reduceMotion: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(Theme.Brand.primary)
                        .matchedGeometryEffect(id: "tabSelector", in: animation)
                        .themedShadow(Theme.Shadow.small)
                }

                HStack(spacing: 6) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 15, weight: isSelected ? .bold : .semibold))
                        .foregroundColor(isSelected ? .white : Theme.Colors.textSecondary)
                        .accessibilityHidden(true)

                    if isSelected {
                        Text(tab.title)
                            .scaledFont(size: 12, weight: .bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .transition(reduceMotion
                                ? .identity
                                : .asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                    }
                }
                .padding(.horizontal, isSelected ? 14 : 10)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: isSelected ? .infinity : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Breaking News View
struct BreakingNewsView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = BreakingNewsViewModel()

    var body: some View {
        NavigationView {
            ListScreen(
                title: "Son Dakika",
                displayMode: .inline,
                showLogo: true,
                items: viewModel.breakingNews,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                emptyConfig: EmptyConfig(
                    icon: "bolt.slash",
                    title: "Henüz Haber Yok",
                    message: "Şu anda gösterilecek son dakika haberi bulunmuyor."
                ),
                onRefresh: { await viewModel.refresh() },
                onLoadMore: { await viewModel.loadMore() },
                isLoadingMore: viewModel.pagination.isLoadingMore,
                onRetry: { await viewModel.loadBreakingNews() },
                showSideMenu: $showSideMenu
            ) { news in
                NavigationLink(destination: PostDetailView(postId: news.id)) {
                    EditorialStoryCard(post: news)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .task {
                if viewModel.breakingNews.isEmpty {
                    await viewModel.loadBreakingNews()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}


// MARK: - Headlines View
struct HeadlinesView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = HeadlinesViewModel()

    var body: some View {
        ListScreen(
            title: "Manşetler",
            items: viewModel.headlines,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            emptyConfig: EmptyConfig(
                icon: "newspaper",
                title: "Manşet Yok",
                message: "Şu anda gösterilecek manşet haberi bulunmuyor."
            ),
            onRefresh: { await viewModel.refresh() },
            onLoadMore: { await viewModel.loadMore() },
            isLoadingMore: viewModel.pagination.isLoadingMore,
            onRetry: { await viewModel.loadHeadlines() }
        ) { headline in
            NavigationLink(destination: PostDetailView(postId: headline.id)) {
                EditorialStoryCard(post: headline)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .task {
            if viewModel.headlines.isEmpty {
                await viewModel.loadHeadlines()
            }
        }
    }
}


// MARK: - Search View
struct SearchView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar

                if viewModel.isLoading {
                    Spacer()
                    LoadingView(message: "Aranıyor...")
                    Spacer()
                } else if let error = viewModel.errorMessage, viewModel.searchResults.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.retryLastSearch() }
                    }
                } else if !viewModel.searchResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, post in
                                NavigationLink(destination: PostDetailView(postId: post.id)) {
                                    EditorialStoryCard(post: post)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onAppear {
                                    if post.id == viewModel.searchResults.last?.id {
                                        Task { await viewModel.loadMore() }
                                    }
                                }
                                if index < viewModel.searchResults.count - 1 {
                                    EditorialDivider()
                                }
                            }
                            if viewModel.pagination.isLoadingMore {
                                ProgressView().padding(.vertical, Theme.Spacing.lg)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.md)
                        .padding(.bottom, 100)
                    }
                } else if searchText.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Haber Ara",
                        message: "Aramak istediğiniz kelimeyi yukarıdaki alana yazın."
                    )
                } else {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "Sonuç Bulunamadı",
                        message: "'\(searchText)' için sonuç bulunamadı. Farklı kelimeler deneyin."
                    )
                }
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .navigationTitle("Ara")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { withAnimation { showSideMenu.toggle() } }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .accessibilityLabel("Menüyü aç")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var searchBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.Colors.textSecondary)

            TextField("Haber, galeri, video ara…", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onChange(of: searchText) { newValue in
                    viewModel.debounceSearch(query: newValue)
                }
                .onSubmit {
                    Task { await viewModel.search(query: searchText) }
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    viewModel.searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.Colors.surface)
        )
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
    }
}


