import Foundation
import Combine

@MainActor
class AuthorDetailViewModel: ObservableObject {
    @Published var author: AuthorDetail?
    @Published var articles: [AuthorArticle] = []
    @Published var isLoading = false
    @Published var isLoadingArticles = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    func loadAuthor(id: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiService.fetchAuthorDetail(id: id)
            author = response.data
        } catch {
            errorMessage = "Yazar bilgileri yüklenemedi."
        }
        isLoading = false
    }

    func loadAuthorArticles(authorId: Int) async {
        isLoadingArticles = true
        do {
            let response = try await apiService.fetchAuthorArticles(authorId: authorId, limit: 20)
            articles = response.data
        } catch {
            // sessizce yut
        }
        isLoadingArticles = false
    }
}
