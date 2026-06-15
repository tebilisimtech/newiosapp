import Foundation
import Combine

@MainActor
class BiographyDetailViewModel: ObservableObject {
    @Published var biography: BiographyDetail?
    @Published var related: [Biography] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    func loadBiography(id: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiService.fetchBiographyDetail(id: id)
            biography = response.data
        } catch {
            errorMessage = "Biyografi yüklenemedi."
        }
        isLoading = false

        if let relatedResponse = try? await apiService.fetchBiographyRelated(id: id, limit: 6) {
            related = relatedResponse.data.filter { $0.id != id }
        }
    }
}
