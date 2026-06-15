import SwiftUI
import Combine

// MARK: - View Model
@MainActor
final class ArticleFivesSectionViewModel: ObservableObject {
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading = false

    private let limit: Int
    private let apiService = APIService.shared

    init(limit: Int = 5) {
        self.limit = limit
    }

    func load() async {
        guard articles.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        if let response = try? await apiService.fetchArticlesFives(limit: limit) {
            articles = response.data
        }
    }
}

// MARK: - Section View
struct ArticleFivesSection: View {
    @StateObject private var viewModel: ArticleFivesSectionViewModel
    @Binding var showSideMenu: Bool

    init(limit: Int = 5, showSideMenu: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: ArticleFivesSectionViewModel(limit: limit))
        _showSideMenu = showSideMenu
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.articles.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    EditorialSectionHeader(title: "Köşeden Seçmeler", eyebrow: "Yazarlardan")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                            ForEach(viewModel.articles) { article in
                                NavigationLink(destination: ArticleDetailView(articleId: article.id, showSideMenu: $showSideMenu)) {
                                    EditorialArticleFiveCard(article: article)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                }
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .task { await viewModel.load() }
    }
}
