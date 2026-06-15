import Foundation
import Combine
import os

@MainActor
final class BreakingNewsViewModel: ObservableObject {
    @Published var breakingNews: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pagination = PaginationState()

    private let api = APIService.shared
    private let perPage = 20

    func loadBreakingNews() async {
        pagination.reset()
        breakingNews = []
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.fetchBreakingNews(page: pagination.currentPage, perPage: perPage)
            breakingNews = response.data
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            errorMessage = "Son dakika haberleri yüklenemedi."
        }
        isLoading = false
    }

    func loadMore() async {
        guard pagination.hasMore, !pagination.isLoadingMore, !isLoading else { return }
        pagination.willLoadMore()
        do {
            let response = try await api.fetchBreakingNews(page: pagination.currentPage, perPage: perPage)
            let newItems = response.data.filter { item in !breakingNews.contains(where: { $0.id == item.id }) }
            breakingNews.append(contentsOf: newItems)
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            pagination.didFail()
            AppLogger.api.warning("Breaking news loadMore — \(error.localizedDescription, privacy: .public)")
        }
    }

    func refresh() async {
        await loadBreakingNews()
    }
}
