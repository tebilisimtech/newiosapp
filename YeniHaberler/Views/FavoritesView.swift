import SwiftUI

// MARK: - Favorites View
struct FavoritesView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var favorites = FavoritesService.shared
    @State private var selectedFilter: FavoriteFilter = .all

    enum FavoriteFilter: String, CaseIterable, Identifiable {
        case all, post, video, gallery
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .all:     return "Tümü"
            case .post:    return "Haberler"
            case .video:   return "Videolar"
            case .gallery: return "Galeriler"
            }
        }

        var icon: String {
            switch self {
            case .all:     return "square.grid.2x2.fill"
            case .post:    return "newspaper.fill"
            case .video:   return "play.rectangle.fill"
            case .gallery: return "photo.on.rectangle"
            }
        }
    }

    private var filteredItems: [FavoriteItem] {
        switch selectedFilter {
        case .all:     return favorites.items
        case .post:    return favorites.items(of: .post)
        case .video:   return favorites.items(of: .video)
        case .gallery: return favorites.items(of: .gallery)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.groupedBackground.ignoresSafeArea()

                if favorites.items.isEmpty {
                    EmptyStateView(
                        icon: "bookmark",
                        title: "Henüz favori yok",
                        message: "Beğendiğiniz haberleri yer imlerine ekleyerek daha sonra kolayca ulaşın."
                    )
                } else {
                    VStack(spacing: 0) {
                        filterBar
                        list
                    }
                }
            }
            .navigationTitle("Favorilerim")
            .navigationBarTitleDisplayMode(.large)
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
        }
        .navigationViewStyle(.stack)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(FavoriteFilter.allCases) { filter in
                    FilterChip(
                        title: filter.displayName,
                        icon: filter.icon,
                        count: count(for: filter),
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(Theme.Animations.snappy) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
        }
    }

    private func count(for filter: FavoriteFilter) -> Int {
        switch filter {
        case .all:     return favorites.items.count
        case .post:    return favorites.items(of: .post).count
        case .video:   return favorites.items(of: .video).count
        case .gallery: return favorites.items(of: .gallery).count
        }
    }

    private var list: some View {
        ScrollView {
            if filteredItems.isEmpty {
                EmptyStateView(
                    icon: selectedFilter.icon,
                    title: "Boş",
                    message: "\(selectedFilter.displayName.lowercased()) kategorisinde favori yok."
                )
                .frame(minHeight: 300)
            } else {
                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(filteredItems) { item in
                        FavoriteRow(item: item)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.md)
            }
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .scaledFont(size: 13, weight: .semibold)
                if count > 0 {
                    Text("\(count)")
                        .scaledFont(size: 11, weight: .bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(isSelected ? Color.white.opacity(0.25) : Theme.Brand.primary.opacity(0.15))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? Theme.Brand.primary : Theme.Colors.surface)
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? Color.clear : Theme.Colors.borderSubtle,
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Favorite Row
struct FavoriteRow: View {
    let item: FavoriteItem
    @StateObject private var favorites = FavoritesService.shared

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: Theme.Spacing.md) {
                ZStack(alignment: .topLeading) {
                    ThemedAsyncImage(url: item.imageURL)
                        .frame(width: 110, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

                    if let badge = typeBadge {
                        HStack(spacing: 3) {
                            Image(systemName: badge.icon).font(.system(size: 8, weight: .bold))
                            Text(badge.label).scaledFont(size: 8, weight: .bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(badge.color))
                        .padding(4)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let category = item.categoryName {
                        Text(category.uppercased())
                            .scaledFont(size: 10, weight: .bold)
                            .tracking(0.4)
                            .foregroundColor(Theme.Brand.primary)
                            .lineLimit(1)
                    }

                    Text(item.title)
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    Text(relativeDate(item.savedAt))
                        .scaledFont(size: 11)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 90)

                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    favorites.remove(id: item.id, type: item.type)
                } label: {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Brand.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
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
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var destination: some View {
        switch item.type {
        case .post:    PostDetailView(postId: item.id)
        case .video:   VideoDetailView(videoId: item.id)
        case .gallery: GalleryDetailView(galleryId: item.id)
        }
    }

    private var typeBadge: (label: String, icon: String, color: Color)? {
        switch item.type {
        case .post:    return nil
        case .video:   return ("VİDEO", "play.fill", Theme.Colors.danger)
        case .gallery: return ("GALERİ", "photo.fill", Theme.Colors.info)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
