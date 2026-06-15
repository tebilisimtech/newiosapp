import SwiftUI
import Combine

// MARK: - View Model
@MainActor
final class HeadlinesSliderSectionViewModel: ObservableObject {
    @Published private(set) var headlines: [Post] = []
    @Published private(set) var isLoading = false

    private let limit: Int
    private let apiService = APIService.shared

    init(limit: Int = 8) {
        self.limit = limit
    }

    func load() async {
        guard headlines.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        if let response = try? await apiService.fetchHeadlines() {
            headlines = Array(response.data.prefix(limit))
        }
    }
}

// MARK: - Section View
struct HeadlinesSliderSection: View {
    @StateObject private var viewModel: HeadlinesSliderSectionViewModel
    @Binding var showSideMenu: Bool

    init(limit: Int = 8, showSideMenu: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: HeadlinesSliderSectionViewModel(limit: limit))
        _showSideMenu = showSideMenu
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.headlines.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    EditorialSectionHeader(title: "Ana Manşetler")

                    EditorialHeadlinesSlider(headlines: viewModel.headlines) { post in
                        PostDestinationView(post: post, showSideMenu: $showSideMenu)
                    }
                }
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .task { await viewModel.load() }
    }
}
