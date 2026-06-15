import Foundation
import Combine

@MainActor
class VideoDetailViewModel: ObservableObject {
    @Published var video: VideoDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    func loadVideo(id: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiService.fetchVideoDetail(id: id)
            video = response.data
        } catch {
            errorMessage = "Video yüklenemedi. Lütfen tekrar deneyin."
        }
        isLoading = false
    }
}
