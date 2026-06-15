import SwiftUI
import Combine

// MARK: - View Model
@MainActor
final class AuthorsSectionViewModel: ObservableObject {
    @Published private(set) var authors: [AuthorDetail] = []
    @Published private(set) var isLoading = false

    private let limit: Int
    private let apiService = APIService.shared

    init(limit: Int = 8) {
        self.limit = limit
    }

    func load() async {
        guard authors.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        if let response = try? await apiService.fetchAuthors(perPage: limit) {
            authors = response.data
        }
    }
}

// MARK: - Section View
struct AuthorsSection: View {
    @StateObject private var viewModel: AuthorsSectionViewModel
    @Binding var showSideMenu: Bool

    init(limit: Int = 8, showSideMenu: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: AuthorsSectionViewModel(limit: limit))
        _showSideMenu = showSideMenu
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.authors.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    EditorialSectionHeader(
                        title: "Köşe Yazarları",
                        eyebrow: AppBranding.authorsEyebrow,
                        actionTitle: "TÜMÜ"
                    ) {
                        // tüm yazarlar listesine yönlendirme side menu'den yapılıyor
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.lg) {
                            ForEach(viewModel.authors) { author in
                                NavigationLink(destination: AuthorDetailView(authorId: author.id, showSideMenu: $showSideMenu)) {
                                    EditorialAuthorPortrait(author: author)
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
