import Foundation
import Combine

@MainActor
class GalleryDetailViewModel: ObservableObject {
    @Published var gallery: GalleryDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    func loadGallery(id: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiService.fetchGalleryDetail(id: id)
            gallery = response.data
        } catch {
            errorMessage = "Galeri yüklenemedi."
        }
        isLoading = false
    }
}
