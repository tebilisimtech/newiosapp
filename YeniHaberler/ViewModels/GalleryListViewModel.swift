import Foundation
import Combine

@MainActor
class GalleryListViewModel: ObservableObject {
    @Published var galleries: [Gallery] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pagination = PaginationState()

    private let apiService = APIService.shared
    private let perPage = 20

    func loadGalleries() async {
        pagination.reset()
        galleries = []
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiService.fetchGalleries(page: pagination.currentPage, perPage: perPage)
            galleries = response.data
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            errorMessage = "Galeriler yüklenemedi."
        }
        isLoading = false
    }

    func loadMore() async {
        guard pagination.hasMore, !pagination.isLoadingMore, !isLoading else { return }
        pagination.willLoadMore()
        do {
            let response = try await apiService.fetchGalleries(page: pagination.currentPage, perPage: perPage)
            let newItems = response.data.filter { item in !galleries.contains(where: { $0.id == item.id }) }
            galleries.append(contentsOf: newItems)
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            pagination.didFail()
        }
    }
}
