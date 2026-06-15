import SwiftUI
import Combine

// MARK: - View Model
@MainActor
final class BiographiesSectionViewModel: ObservableObject {
    @Published private(set) var biographies: [Biography] = []
    @Published private(set) var isLoading = false

    private let limit: Int
    private let apiService = APIService.shared

    init(limit: Int = 5) {
        self.limit = limit
    }

    func load() async {
        guard biographies.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        if let response = try? await apiService.fetchLatestBiographies(limit: limit) {
            biographies = response.data
        }
    }
}

// MARK: - Section View
struct BiographiesSection: View {
    @StateObject private var viewModel: BiographiesSectionViewModel
    @Binding var showSideMenu: Bool

    init(limit: Int = 5, showSideMenu: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: BiographiesSectionViewModel(limit: limit))
        _showSideMenu = showSideMenu
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.biographies.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    EditorialSectionHeader(title: "Biyografi", eyebrow: "Profil")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                            ForEach(viewModel.biographies) { bio in
                                NavigationLink(destination: BiographyDetailView(biographyId: bio.id, showSideMenu: $showSideMenu)) {
                                    EditorialBiographyTile(biography: bio)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                }
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .task { await viewModel.load() }
    }
}
