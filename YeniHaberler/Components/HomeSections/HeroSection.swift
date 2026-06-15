import SwiftUI
import Combine

// MARK: - View Model
//
// Hero için öncelik sırası: featured.first → headlines.first → latestPosts.first.
// Üç endpoint paralel fetch edilir, ilk dolu olan kullanılır.
@MainActor
final class HeroSectionViewModel: ObservableObject {
    @Published private(set) var hero: Post?
    @Published private(set) var isLoading = false

    private let apiService = APIService.shared

    func load() async {
        guard hero == nil else { return }
        isLoading = true
        defer { isLoading = false }

        async let featured = try? apiService.fetchFeaturedPosts()
        async let headlines = try? apiService.fetchHeadlines()
        async let latest = try? apiService.fetchLatestPosts(limit: 1)

        let (f, h, l) = await (featured, headlines, latest)

        if let post = f?.data.first {
            hero = post
        } else if let post = h?.data.first {
            hero = post
        } else if let post = l?.data.first {
            hero = post
        }
    }
}

// MARK: - Section View
struct HeroSection: View {
    @StateObject private var viewModel = HeroSectionViewModel()
    @Binding var showSideMenu: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let hero = viewModel.hero {
                PostNavigationLink(post: hero, showSideMenu: $showSideMenu) {
                    EditorialHeroCard(post: hero)
                }
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .task { await viewModel.load() }
    }
}
