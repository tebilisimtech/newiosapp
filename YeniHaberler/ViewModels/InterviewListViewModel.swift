import Foundation
import Combine

@MainActor
class InterviewListViewModel: ObservableObject {
    @Published var interviews: [Interview] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pagination = PaginationState()

    private let apiService = APIService.shared
    private let perPage = 20

    func loadInterviews() async {
        pagination.reset()
        interviews = []
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiService.fetchInterviews(page: pagination.currentPage, perPage: perPage)
            interviews = response.data
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            errorMessage = "Röportajlar yüklenemedi."
        }
        isLoading = false
    }

    func loadMore() async {
        guard pagination.hasMore, !pagination.isLoadingMore, !isLoading else { return }
        pagination.willLoadMore()
        do {
            let response = try await apiService.fetchInterviews(page: pagination.currentPage, perPage: perPage)
            let newItems = response.data.filter { item in !interviews.contains(where: { $0.id == item.id }) }
            interviews.append(contentsOf: newItems)
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            pagination.didFail()
        }
    }
}
