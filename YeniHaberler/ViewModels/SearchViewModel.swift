import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var searchResults: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pagination = PaginationState()

    private let api = APIService.shared
    private var searchTask: Task<Void, Never>?
    private var currentQuery: String = ""
    private let perPage = 20

    /// Son arananı tekrar denemek için (ErrorView retry).
    func retryLastSearch() async {
        guard !currentQuery.isEmpty else { return }
        await search(query: currentQuery)
    }

    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            currentQuery = ""
            errorMessage = nil
            pagination.reset()
            return
        }

        searchTask?.cancel()
        currentQuery = query
        pagination.reset()
        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.searchPosts(query: query, page: pagination.currentPage, perPage: perPage)
            if !Task.isCancelled {
                searchResults = response.data
                pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
                AnalyticsService.shared.logSearch(
                    queryLength: query.count,
                    resultCount: response.data.count
                )
            }
        } catch is CancellationError {
            // İptal — sessiz geç
        } catch {
            if !Task.isCancelled {
                searchResults = []
                errorMessage = "Arama yapılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin."
            }
        }

        isLoading = false
    }

    func loadMore() async {
        guard !currentQuery.isEmpty,
              pagination.hasMore,
              !pagination.isLoadingMore,
              !isLoading else { return }
        pagination.willLoadMore()
        do {
            let response = try await api.searchPosts(query: currentQuery, page: pagination.currentPage, perPage: perPage)
            let newItems = response.data.filter { item in !searchResults.contains(where: { $0.id == item.id }) }
            searchResults.append(contentsOf: newItems)
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            pagination.didFail()
        }
    }

    func debounceSearch(query: String) {
        searchTask?.cancel()

        guard !query.isEmpty else {
            searchResults = []
            currentQuery = ""
            pagination.reset()
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !Task.isCancelled {
                await search(query: query)
            }
        }
    }
}
