import Foundation
import Combine

@MainActor
class VideoListViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pagination = PaginationState()

    private let apiService = APIService.shared
    private let perPage = 20

    func loadVideos() async {
        pagination.reset()
        videos = []
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiService.fetchVideos(page: pagination.currentPage, perPage: perPage)
            videos = response.data
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            errorMessage = "Videolar yüklenemedi."
        }
        isLoading = false
    }

    func loadMore() async {
        guard pagination.hasMore, !pagination.isLoadingMore, !isLoading else { return }
        pagination.willLoadMore()
        do {
            let response = try await apiService.fetchVideos(page: pagination.currentPage, perPage: perPage)
            let newItems = response.data.filter { item in !videos.contains(where: { $0.id == item.id }) }
            videos.append(contentsOf: newItems)
            pagination.didLoadPage(itemsReceived: response.data.count, expected: perPage)
        } catch {
            pagination.didFail()
        }
    }
}
