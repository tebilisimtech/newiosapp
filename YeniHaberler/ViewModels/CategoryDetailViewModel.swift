import Foundation
import Combine

@MainActor
final class CategoryDetailViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private let api = APIService.shared
    private var currentPage = 1
    private var hasMore = true

    func load(categoryId: Int) async {
        isLoading = true
        errorMessage = nil
        currentPage = 1
        hasMore = true
        do {
            let response = try await api.fetchPostsByCategory(categoryId: categoryId, page: 1, limit: 12)
            posts = response.data
            hasMore = response.data.count >= 12
        } catch {
            errorMessage = "Haberler yüklenemedi."
        }
        isLoading = false
    }

    func loadMore(categoryId: Int) async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1
        do {
            let response = try await api.fetchPostsByCategory(categoryId: categoryId, page: nextPage, limit: 12)
            if response.data.isEmpty {
                hasMore = false
            } else {
                let existingIDs = Set(posts.map(\.id))
                let newOnes = response.data.filter { !existingIDs.contains($0.id) }
                posts.append(contentsOf: newOnes)
                currentPage = nextPage
                hasMore = response.data.count >= 12
            }
        } catch {
            // sessizce yut — pagination başarısızlığı kritik değil
        }
        isLoadingMore = false
    }
}
