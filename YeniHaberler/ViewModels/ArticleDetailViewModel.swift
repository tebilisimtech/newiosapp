import Foundation
import Combine

@MainActor
class ArticleDetailViewModel: ObservableObject {
    @Published var article: ArticleDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    func loadArticle(id: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiService.fetchArticleDetail(id: id)
            article = response.data
        } catch {
            errorMessage = "Makale yüklenemedi."
        }
        isLoading = false
    }
}
