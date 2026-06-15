import Foundation
import Combine

@MainActor
final class CategoriesViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.fetchCategories(perPage: 100)
            categories = response.data
        } catch {
            errorMessage = "Kategoriler yüklenemedi."
        }
        isLoading = false
    }
}
