import SwiftUI
import Combine

// MARK: - View Model
//
// "Sana Özel" akışı: kullanıcının seçtiği ilgi alanı kategorilerinden haber toplar,
// popüler ile harmanlar; ilgi alanı yoksa popüler/son haberlere düşer.
// Android ForYouContent karşılığı.
@MainActor
final class ForYouSectionViewModel: ObservableObject {
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = false

    private let api = APIService.shared
    private var lastIds: [Int] = []

    func load(interests: [InterestCategory], force: Bool = false) async {
        let ids = interests.map { $0.id }
        if !force, !posts.isEmpty, ids == lastIds { return }
        lastIds = ids
        isLoading = true
        defer { isLoading = false }

        var seen = Set<Int>()
        var collected: [Post] = []

        // 1) İlgi alanı kategorilerinden (en fazla 6)
        for cat in interests.prefix(6) {
            if let resp = try? await api.fetchPostsByCategory(categoryId: cat.id, page: 1, limit: 8) {
                for p in resp.data where seen.insert(p.id).inserted { collected.append(p) }
            }
        }
        // 2) Popüler ile harmanla
        if let pop = try? await api.fetchPopularPosts() {
            for p in pop.data where seen.insert(p.id).inserted { collected.append(p) }
        }
        // 3) Hâlâ boşsa son haberler
        if collected.isEmpty, let latest = try? await api.fetchLatestPosts(limit: 12) {
            collected = latest.data
        }

        posts = Array(collected.prefix(12))
    }
}

// MARK: - Section View
struct ForYouSection: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = ForYouSectionViewModel()
    @StateObject private var interests = UserInterests.shared
    @State private var showInterests = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                EditorialSectionHeader(
                    title: interests.hasSelected ? "İlgi Alanların" : "Senin İçin",
                    eyebrow: "Kişiselleştirilmiş"
                )

                if interests.hasSelected {
                    // Seçili ilgi alanı chip'leri + düzenle
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(interests.categories) { c in
                                Text(c.name)
                                    .scaledFont(size: 12, weight: .bold)
                                    .foregroundColor(Theme.Brand.primary)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Theme.Brand.primary.opacity(0.12)))
                            }
                            Button { showInterests = true } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .padding(8)
                                    .background(Circle().fill(Theme.Colors.surfaceElevated))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                } else {
                    // İlgi alanı seçilmemiş — davet
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("İlgi alanı seçerek akışını kişiselleştir.")
                            .scaledFont(size: 13)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Button { showInterests = true } label: {
                            Text("İlgi Alanı Seç")
                                .scaledFont(size: 13, weight: .bold)
                                .foregroundColor(Theme.Colors.textOnBrand)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Capsule().fill(Theme.Brand.primary))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                // Kişiselleştirilmiş haber listesi
                if !viewModel.posts.isEmpty {
                    let shown = Array(viewModel.posts.prefix(6))
                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { index, post in
                            PostNavigationLink(post: post, showSideMenu: $showSideMenu) {
                                EditorialStoryCard(post: post)
                            }
                            .padding(.horizontal, Theme.Spacing.xl)

                            if index < shown.count - 1 {
                                EditorialDivider().padding(.horizontal, Theme.Spacing.xl)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .task { await viewModel.load(interests: interests.categories) }
        .onChange(of: interests.categories) { newValue in
            Task { await viewModel.load(interests: newValue, force: true) }
        }
        .sheet(isPresented: $showInterests) {
            InterestsView(onboarding: false)
        }
    }
}
