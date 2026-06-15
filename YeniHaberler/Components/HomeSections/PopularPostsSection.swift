import SwiftUI
import Combine

// MARK: - View Model
@MainActor
final class PopularPostsSectionViewModel: ObservableObject {
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = false

    private let limit: Int
    private let apiService = APIService.shared

    init(limit: Int = 5) {
        self.limit = limit
    }

    func load() async {
        guard posts.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        if let response = try? await apiService.fetchPopularPosts() {
            posts = Array(response.data.prefix(limit))
        }
    }
}

// MARK: - Section View
struct PopularPostsSection: View {
    @StateObject private var viewModel: PopularPostsSectionViewModel
    @Binding var showSideMenu: Bool

    init(limit: Int = 5, showSideMenu: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: PopularPostsSectionViewModel(limit: limit))
        _showSideMenu = showSideMenu
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.posts.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    EditorialSectionHeader(title: "Çok Okunanlar", eyebrow: "Trend olanlar")

                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                            PostNavigationLink(post: post, showSideMenu: $showSideMenu) {
                                NumberedStoryRow(index: index + 1, post: post)
                            }
                            .padding(.horizontal, Theme.Spacing.xl)

                            if index < viewModel.posts.count - 1 {
                                EditorialDivider()
                                    .padding(.horizontal, Theme.Spacing.xl)
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
