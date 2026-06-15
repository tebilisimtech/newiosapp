import SwiftUI
import Combine

// MARK: - View Model
@MainActor
final class StoryCarouselSectionViewModel: ObservableObject {
    @Published private(set) var groups: [StoryGroup] = []
    @Published private(set) var isLoading = false

    private let apiService = APIService.shared

    func load() async {
        guard groups.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        if let response = try? await apiService.fetchStoryPosts() {
            groups = response.data
        }
    }
}

// MARK: - Section View
//
// Instagram-vari story carousel'ını fetch + render eden bağımsız section.
// Render'dan sonra StoryCarousel kendi internal full-screen viewer'ını yönetir.
struct StoryCarouselSection: View {
    @StateObject private var viewModel = StoryCarouselSectionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.groups.isEmpty {
                StoryCarousel(groups: viewModel.groups)
                    .padding(.vertical, Theme.Spacing.lg)
                Rectangle()
                    .fill(Theme.Colors.borderSubtle)
                    .frame(height: 0.5)
            }
        }
        .task { await viewModel.load() }
    }
}
