import SwiftUI
import Combine

// MARK: - View Model
@MainActor
final class TopHeadlinesSectionViewModel: ObservableObject {
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

        if let response = try? await apiService.fetchTopHeadlines() {
            posts = Array(response.data.prefix(limit))
        }
    }
}

// MARK: - Section View
struct TopHeadlinesSection: View {
    @StateObject private var viewModel: TopHeadlinesSectionViewModel
    @Binding var showSideMenu: Bool

    init(limit: Int = 8, showSideMenu: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: TopHeadlinesSectionViewModel(limit: limit))
        _showSideMenu = showSideMenu
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.posts.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    EditorialSectionHeader(title: "Üst Manşetler", eyebrow: "Sıcak gündem")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                            ForEach(viewModel.posts) { post in
                                PostNavigationLink(post: post, showSideMenu: $showSideMenu) {
                                    EditorialLeadCardCompact(post: post)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.sm)
                    }
                }
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .task { await viewModel.load() }
    }
}
