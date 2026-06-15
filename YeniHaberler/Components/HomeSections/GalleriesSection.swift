import SwiftUI
import Combine

// MARK: - View Model
@MainActor
final class GalleriesSectionViewModel: ObservableObject {
    @Published private(set) var galleries: [Gallery] = []
    @Published private(set) var isLoading = false

    private let limit: Int
    private let apiService = APIService.shared

    init(limit: Int = 6) {
        self.limit = limit
    }

    func load() async {
        guard galleries.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        if let response = try? await apiService.fetchLatestGalleries(limit: limit) {
            galleries = response.data
        }
    }
}

// MARK: - Section View
struct GalleriesSection: View {
    @StateObject private var viewModel: GalleriesSectionViewModel

    init(limit: Int = 6) {
        _viewModel = StateObject(wrappedValue: GalleriesSectionViewModel(limit: limit))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.galleries.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    EditorialSectionHeader(title: "Foto Galeri", eyebrow: "Kareler")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                            ForEach(viewModel.galleries) { gallery in
                                NavigationLink(destination: GalleryDetailView(galleryId: gallery.id)) {
                                    EditorialGalleryCard(gallery: gallery)
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
