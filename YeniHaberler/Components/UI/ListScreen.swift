import SwiftUI

// MARK: - Empty State Config
struct EmptyConfig {
    let icon: String
    let title: String
    let message: String
}

// MARK: - List Screen
//
// Tekrar eden liste ekranı pattern'ini (skeleton → error → empty → content)
// tek yerden yöneten generic component. Caller şunu sağlar:
//   - items + isLoading + errorMessage + emptyConfig
//   - onRefresh + onLoadMore (opsiyonel) + isLoadingMore + onRetry
//   - itemView (her satırı çizen ViewBuilder)
//   - skeleton (opsiyonel — varsayılan SkeletonList)
//
// **NavigationView içermez.** Caller tab kullanımında dış NavigationView ile
// sarmalı; SideMenu içinden çağrıldığında zaten fullScreenCover NavigationView
// sağladığı için sarılmaz.
struct ListScreen<Item: Identifiable, ItemView: View, SkeletonView: View>: View {
    let title: String
    let displayMode: NavigationBarItem.TitleDisplayMode
    let showLogo: Bool
    let items: [Item]
    let isLoading: Bool
    let errorMessage: String?
    let emptyConfig: EmptyConfig
    let itemSpacing: CGFloat
    let onRefresh: () async -> Void
    let onLoadMore: (() async -> Void)?
    let isLoadingMore: Bool
    let onRetry: () async -> Void
    let showSideMenu: Binding<Bool>?
    @ViewBuilder let skeleton: () -> SkeletonView
    @ViewBuilder let itemView: (Item) -> ItemView

    var body: some View {
        ZStack {
            Theme.Colors.groupedBackground.ignoresSafeArea()

            Group {
                if isLoading && items.isEmpty {
                    skeleton()
                } else if let error = errorMessage, items.isEmpty {
                    ErrorView(message: error) {
                        Task { await onRetry() }
                    }
                } else if items.isEmpty {
                    EmptyStateView(
                        icon: emptyConfig.icon,
                        title: emptyConfig.title,
                        message: emptyConfig.message
                    )
                } else {
                    list
                }
            }
        }
        .navigationTitle(showLogo ? "" : title)
        .navigationBarTitleDisplayMode(displayMode)
        .toolbar {
            if showLogo {
                ToolbarItem(placement: .principal) { LogoView() }
            }
            if let showSideMenu = showSideMenu {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { withAnimation { showSideMenu.wrappedValue.toggle() } }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .accessibilityLabel("Menüyü aç")
                    }
                }
            }
        }
        .refreshable {
            await onRefresh()
        }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: itemSpacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                    itemView(item)
                        .onAppear {
                            if let onLoadMore = onLoadMore,
                               item.id == items.last?.id {
                                Task { await onLoadMore() }
                            }
                        }
                }
                if isLoadingMore {
                    ProgressView().padding(.vertical, Theme.Spacing.lg)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Convenience initializer with default skeleton
extension ListScreen where SkeletonView == AnyView {
    /// Varsayılan skeleton `SkeletonList(count: ...)` kullanır.
    init(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .large,
        showLogo: Bool = false,
        items: [Item],
        isLoading: Bool,
        errorMessage: String?,
        emptyConfig: EmptyConfig,
        skeletonCount: Int = 5,
        itemSpacing: CGFloat = 0,
        onRefresh: @escaping () async -> Void,
        onLoadMore: (() async -> Void)? = nil,
        isLoadingMore: Bool = false,
        onRetry: @escaping () async -> Void,
        showSideMenu: Binding<Bool>? = nil,
        @ViewBuilder itemView: @escaping (Item) -> ItemView
    ) {
        self.title = title
        self.displayMode = displayMode
        self.showLogo = showLogo
        self.items = items
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.emptyConfig = emptyConfig
        self.itemSpacing = itemSpacing
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
        self.isLoadingMore = isLoadingMore
        self.onRetry = onRetry
        self.showSideMenu = showSideMenu
        self.skeleton = {
            AnyView(
                SkeletonList(count: skeletonCount)
                    .padding(.top, Theme.Spacing.lg)
            )
        }
        self.itemView = itemView
    }
}
