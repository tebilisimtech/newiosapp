import Foundation
import Combine

@MainActor
class InterviewDetailViewModel: ObservableObject {
    @Published var interview: InterviewDetail?
    @Published var related: [Interview] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    func loadInterview(id: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiService.fetchInterviewDetail(id: id)
            interview = response.data
        } catch {
            errorMessage = "Röportaj yüklenemedi."
        }
        isLoading = false

        if let relatedResponse = try? await apiService.fetchInterviewRelated(id: id, limit: 6) {
            related = relatedResponse.data.filter { $0.id != id }
        }
    }
}
