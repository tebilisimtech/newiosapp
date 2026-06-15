import SwiftUI
import Combine

// MARK: - View Model
//
// "Son Dakika" ana sayfa widget'ı. Diğer section'lar gibi kendi data fetch'ini
// yapar; görünürlüğü NewHomeView'da settings.modules["son_dakika"] toggle'ına
// göre belirlenir.
@MainActor
final class SonDakikaSectionViewModel: ObservableObject {
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = false

    private let limit: Int
    private let apiService = APIService.shared

    init(limit: Int = 10) {
        self.limit = limit
    }

    func load() async {
        guard posts.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        if let response = try? await apiService.fetchBreakingNews(page: 1, perPage: limit) {
            posts = Array(response.data.prefix(limit))
        }
    }
}

// MARK: - Section View
struct SonDakikaSection: View {
    @StateObject private var viewModel: SonDakikaSectionViewModel
    @Binding var showSideMenu: Bool

    init(limit: Int = 10, showSideMenu: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: SonDakikaSectionViewModel(limit: limit))
        _showSideMenu = showSideMenu
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.posts.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    header

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            ForEach(viewModel.posts) { post in
                                PostNavigationLink(post: post, showSideMenu: $showSideMenu) {
                                    SonDakikaCard(post: post)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.sm)
                    }
                }
                .padding(.vertical, Theme.Spacing.lg)
                .background(Theme.Brand.primary.opacity(0.04))
            }
        }
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            PulsingLiveDot()
            Text("SON DAKİKA")
                .scaledFont(size: 15, weight: .heavy, design: .serif)
                .tracking(0.5)
                .foregroundColor(Theme.Brand.primary)
            Spacer()
            Text("CANLI")
                .scaledFont(size: 10, weight: .heavy)
                .tracking(1.2)
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.Brand.primary))
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

// MARK: - Pulsing Live Dot
struct PulsingLiveDot: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.Brand.primary.opacity(0.35))
                .frame(width: 16, height: 16)
                .scaleEffect(animate ? 1.6 : 0.8)
                .opacity(animate ? 0 : 0.8)
            Circle()
                .fill(Theme.Brand.primary)
                .frame(width: 9, height: 9)
        }
        .frame(width: 16, height: 16)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Son Dakika Card
struct SonDakikaCard: View {
    let post: Post

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Theme.Colors.surfaceElevated
                ThemedAsyncImage(url: post.image.cropped.medium, aspect: .fill)
            }
            .frame(width: 78, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 6) {
                if let category = post.categories.values.first {
                    Text(category.uppercased())
                        .scaledFont(size: 9, weight: .heavy)
                        .tracking(0.8)
                        .foregroundColor(Theme.Brand.primary)
                        .lineLimit(1)
                }

                Text(post.name)
                    .scaledFont(size: 14, weight: .bold, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(3)
                    .lineSpacing(1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.md)
        .frame(width: 300, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
        .overlay(alignment: .leading) {
            // Sol kırmızı vurgu şeridi
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.Brand.primary)
                .frame(width: 3)
                .padding(.vertical, Theme.Spacing.sm)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Son dakika. \(post.categories.values.first ?? ""): \(post.name)")
        .accessibilityHint("Habere git")
        .accessibilityAddTraits(.isLink)
    }
}
