import Foundation
import Combine

@MainActor
class BiographyListViewModel: ObservableObject {
    @Published var biographies: [Biography] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pagination = PaginationState()

    private let apiService = APIService.shared
    private let perPage = 20

    func loadBiographies() async {
        pagination.reset()
        biographies = []
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiService.fetchBiographies(page: pagination.currentPage, perPage: perPage)
            biographies = response.data
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            errorMessage = "Biyografiler yüklenemedi."
        }
        isLoading = false
    }

    func loadMore() async {
        guard pagination.hasMore, !pagination.isLoadingMore, !isLoading else { return }
        pagination.willLoadMore()
        do {
            let response = try await apiService.fetchBiographies(page: pagination.currentPage, perPage: perPage)
            let newItems = response.data.filter { item in !biographies.contains(where: { $0.id == item.id }) }
            biographies.append(contentsOf: newItems)
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            pagination.didFail()
        }
    }
}
