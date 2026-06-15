import SwiftUI
import Combine

// MARK: - Categories View
struct CategoriesView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = CategoriesViewModel()
    @State private var searchText = ""

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md)
    ]

    private var filteredCategories: [Category] {
        guard !searchText.isEmpty else { return viewModel.categories }
        return viewModel.categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.groupedBackground.ignoresSafeArea()

                Group {
                    if viewModel.isLoading && viewModel.categories.isEmpty {
                        LoadingView(message: "Kategoriler yükleniyor...")
                    } else if let error = viewModel.errorMessage, viewModel.categories.isEmpty {
                        ErrorView(message: error) {
                            Task { await viewModel.load() }
                        }
                    } else if viewModel.categories.isEmpty {
                        EmptyStateView(
                            icon: "square.grid.2x2",
                            title: "Kategori Bulunamadı",
                            message: "Henüz görüntülenecek kategori yok."
                        )
                    } else {
                        content
                    }
                }
            }
            .navigationTitle("Kategoriler")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Kategori ara")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { withAnimation { showSideMenu.toggle() } }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .accessibilityLabel("Menüyü aç")
                    }
                }
            }
            .task {
                if viewModel.categories.isEmpty {
                    await viewModel.load()
                }
            }
            .refreshable {
                await viewModel.load()
            }
        }
        .navigationViewStyle(.stack)
    }

    private var content: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                ForEach(filteredCategories) { category in
                    NavigationLink(destination: CategoryDetailView(category: category)) {
                        CategoryCard(category: category)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: Category

    private var accentColor: Color {
        Theme.categoryColor(for: String(category.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ZStack(alignment: .topLeading) {
                if let imageURL = category.imageURL, !imageURL.isEmpty {
                    AspectImage(url: imageURL, aspectRatio: 16/10)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.85), accentColor.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(16/10, contentMode: .fit)
                        .overlay(
                            Image(systemName: iconForCategory(category.name))
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                        )
                }

                // Gradient
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

                // Badge on top
                Tag(category.name.prefix(1).uppercased() + " ", color: accentColor, style: .filled)
                    .padding(Theme.Spacing.sm)
            }
            .aspectRatio(16/10, contentMode: .fit)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .scaledFont(size: 14, weight: .bold)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let description = category.description, !description.isEmpty {
                    Text(description)
                        .scaledFont(size: 11)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    private func iconForCategory(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("spor") { return "sportscourt.fill" }
        if lower.contains("gündem") || lower.contains("gundem") { return "newspaper.fill" }
        if lower.contains("politik") || lower.contains("siyaset") { return "building.columns.fill" }
        if lower.contains("ekonom") { return "chart.line.uptrend.xyaxis" }
        if lower.contains("magazin") { return "sparkles" }
        if lower.contains("sağlık") || lower.contains("saglik") { return "heart.fill" }
        if lower.contains("eğitim") || lower.contains("egitim") { return "graduationcap.fill" }
        if lower.contains("kültür") || lower.contains("kultur") { return "theatermasks.fill" }
        if lower.contains("teknoloji") { return "laptopcomputer" }
        if lower.contains("dünya") || lower.contains("dunya") { return "globe.europe.africa.fill" }
        if lower.contains("yerel") || lower.contains("yozgat") { return "mappin.circle.fill" }
        return "tag.fill"
    }
}

// MARK: - Category Detail View
struct CategoryDetailView: View {
    let category: Category

    @StateObject private var viewModel = CategoryDetailViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.Colors.groupedBackground.ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    SkeletonList(count: 5)
                        .padding(.top, Theme.Spacing.lg)
                } else if let error = viewModel.errorMessage, viewModel.posts.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.load(categoryId: category.id) }
                    }
                } else if viewModel.posts.isEmpty {
                    EmptyStateView(
                        icon: "newspaper",
                        title: "Haber Bulunamadı",
                        message: "Bu kategoride henüz yayımlanmış bir haber yok."
                    )
                } else {
                    list
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.posts.isEmpty {
                await viewModel.load(categoryId: category.id)
            }
        }
        .refreshable {
            await viewModel.load(categoryId: category.id)
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                    NavigationLink(destination: PostDetailView(postId: post.id)) {
                        EditorialStoryCard(post: post)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onAppear {
                        if post.id == viewModel.posts.last?.id {
                            Task { await viewModel.loadMore(categoryId: category.id) }
                        }
                    }
                    if index < viewModel.posts.count - 1 {
                        EditorialDivider()
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(Theme.Brand.primary)
                        .padding()
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }
}

