import Foundation
import Combine
import os

@MainActor
final class HeadlinesViewModel: ObservableObject {
    @Published var headlines: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pagination = PaginationState()

    private let api = APIService.shared
    private let perPage = 20

    func loadHeadlines() async {
        pagination.reset()
        headlines = []
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.fetchHeadlines(page: pagination.currentPage, perPage: perPage)
            headlines = response.data
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            errorMessage = "Manşetler yüklenemedi."
        }
        isLoading = false
    }

    func loadMore() async {
        guard pagination.hasMore, !pagination.isLoadingMore, !isLoading else { return }
        pagination.willLoadMore()
        do {
            let response = try await api.fetchHeadlines(page: pagination.currentPage, perPage: perPage)
            let newItems = response.data.filter { item in !headlines.contains(where: { $0.id == item.id }) }
            headlines.append(contentsOf: newItems)
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            pagination.didFail()
            AppLogger.api.warning("Headlines loadMore — \(error.localizedDescription, privacy: .public)")
        }
    }

    func refresh() async {
        await loadHeadlines()
    }
}
