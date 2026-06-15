import Foundation
import Combine
import os

@MainActor
class AuthorsListViewModel: ObservableObject {
    @Published var authors: [AuthorDetail] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMorePages = true

    private let apiService = APIService.shared
    private var currentPage = 1
    private var isSearchMode = false
    private var currentSearchQuery: String?

    func loadAuthors() async {
        currentPage = 1
        hasMorePages = true
        isSearchMode = false
        currentSearchQuery = nil

        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.fetchAuthors(page: currentPage, perPage: 12)
            authors = response.data

            if response.data.isEmpty {
                hasMorePages = false
            }
        } catch {
            errorMessage = "Yazarlar yüklenirken bir hata oluştu: \(error.localizedDescription)"
            AppLogger.api.error("Authors load — \(error.localizedDescription, privacy: .public)")
            hasMorePages = false
        }

        isLoading = false
    }

    func loadMoreAuthors() async {
        guard hasMorePages && !isLoadingMore else { return }

        isLoadingMore = true
        currentPage += 1

        do {
            let response: AuthorResponse
            if isSearchMode, let query = currentSearchQuery {
                response = try await apiService.fetchAuthors(page: currentPage, perPage: 12, search: query)
            } else {
                response = try await apiService.fetchAuthors(page: currentPage, perPage: 12)
            }

            if !response.data.isEmpty {
                authors.append(contentsOf: response.data)
            } else {
                hasMorePages = false
            }

            if response.data.count < 12 {
                hasMorePages = false
            }
        } catch {
            AppLogger.api.error("Authors load more — \(error.localizedDescription, privacy: .public)")
            currentPage -= 1
            hasMorePages = false
        }

        isLoadingMore = false
    }

    func searchAuthors(query: String) async {
        currentPage = 1
        hasMorePages = true
        isSearchMode = true
        currentSearchQuery = query

        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.fetchAuthors(page: currentPage, perPage: 12, search: query)
            authors = response.data

            if response.data.isEmpty {
                hasMorePages = false
            }
        } catch {
            errorMessage = "Arama yapılırken bir hata oluştu: \(error.localizedDescription)"
            AppLogger.api.error("Authors search — \(error.localizedDescription, privacy: .public)")
            hasMorePages = false
        }

        isLoading = false
    }
}
