import SwiftUI
import Combine

// MARK: - View Model
@MainActor
final class LatestStoriesSectionViewModel: ObservableObject {
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = false

    private let limit: Int
    private let apiService = APIService.shared

    init(limit: Int = 8) {
        self.limit = limit
    }

    func load() async {
        guard posts.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        if let response = try? await apiService.fetchLatestPosts(limit: limit) {
            posts = response.data
        }
    }
}

// MARK: - Section View
//
// Son haberler: ilk haber EditorialLeadCard (büyük), sonrakiler
// EditorialStoryCard (kompakt). Aralarda EditorialDivider.
struct LatestStoriesSection: View {
    @StateObject private var viewModel: LatestStoriesSectionViewModel
    @Binding var showSideMenu: Bool

    init(limit: Int = 8, showSideMenu: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: LatestStoriesSectionViewModel(limit: limit))
        _showSideMenu = showSideMenu
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.posts.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    EditorialSectionHeader(title: "Son Haberler", eyebrow: "Az önce")

                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                            if index == 0 {
                                PostNavigationLink(post: post, showSideMenu: $showSideMenu) {
                                    EditorialLeadCard(post: post)
                                }
                                .padding(.horizontal, Theme.Spacing.xl)
                                .padding(.bottom, Theme.Spacing.lg)
                            } else {
                                PostNavigationLink(post: post, showSideMenu: $showSideMenu) {
                                    EditorialStoryCard(post: post)
                                }
                                .padding(.horizontal, Theme.Spacing.xl)

                                if index < viewModel.posts.count - 1 {
                                    EditorialDivider()
                                        .padding(.horizontal, Theme.Spacing.xl)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .task { await viewModel.load() }
    }
}
