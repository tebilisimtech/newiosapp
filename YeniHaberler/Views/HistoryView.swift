import SwiftUI

// MARK: - Reading History View
struct HistoryView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var history = ReadingHistoryService.shared
    @State private var showClearAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.groupedBackground.ignoresSafeArea()

                if history.items.isEmpty {
                    EmptyStateView(
                        icon: "clock",
                        title: "Geçmiş Boş",
                        message: "Okuduğunuz haberler burada listelenir."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.lg, pinnedViews: [.sectionHeaders]) {
                            ForEach(groupedItems, id: \.title) { group in
                                Section {
                                    VStack(spacing: Theme.Spacing.md) {
                                        ForEach(group.items) { item in
                                            HistoryRow(item: item)
                                        }
                                    }
                                    .padding(.horizontal, Theme.Spacing.xl)
                                } header: {
                                    HistoryGroupHeader(title: group.title, count: group.items.count)
                                }
                            }
                        }
                        .padding(.bottom, Theme.Spacing.lg)
                    }
                }
            }
            .navigationTitle("Geçmiş")
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
                if !history.items.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showClearAlert = true }) {
                            Image(systemName: "trash")
                                .foregroundColor(Theme.Colors.danger)
                        }
                    }
                }
            }
            .alert("Geçmişi Temizle", isPresented: $showClearAlert) {
                Button("Vazgeç", role: .cancel) {}
                Button("Temizle", role: .destructive) {
                    history.clearAll()
                }
            } message: {
                Text("Tüm okuma geçmişi silinecek.")
            }
        }
        .navigationViewStyle(.stack)
    }

    private var groupedItems: [(title: String, items: [HistoryItem])] {
        let calendar = Calendar.current
        let now = Date()

        var today: [HistoryItem] = []
        var yesterday: [HistoryItem] = []
        var thisWeek: [HistoryItem] = []
        var older: [HistoryItem] = []

        for item in history.items {
            if calendar.isDateInToday(item.readAt) {
                today.append(item)
            } else if calendar.isDateInYesterday(item.readAt) {
                yesterday.append(item)
            } else if let days = calendar.dateComponents([.day], from: item.readAt, to: now).day, days < 7 {
                thisWeek.append(item)
            } else {
                older.append(item)
            }
        }

        var groups: [(title: String, items: [HistoryItem])] = []
        if !today.isEmpty     { groups.append(("Bugün", today)) }
        if !yesterday.isEmpty { groups.append(("Dün", yesterday)) }
        if !thisWeek.isEmpty  { groups.append(("Bu Hafta", thisWeek)) }
        if !older.isEmpty     { groups.append(("Daha Önce", older)) }
        return groups
    }
}

// MARK: - History Group Header
struct HistoryGroupHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title.uppercased())
                .scaledFont(size: 12, weight: .bold)
                .tracking(0.8)
                .foregroundColor(Theme.Colors.textSecondary)
            Text("(\(count))")
                .scaledFont(size: 11, weight: .medium)
                .foregroundColor(Theme.Colors.textTertiary)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.groupedBackground)
    }
}

// MARK: - History Row
struct HistoryRow: View {
    let item: HistoryItem
    @StateObject private var history = ReadingHistoryService.shared

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: Theme.Spacing.md) {
                ThemedAsyncImage(url: item.imageURL)
                    .frame(width: 80, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))

                VStack(alignment: .leading, spacing: 4) {
                    if let category = item.categoryName {
                        Text(category.uppercased())
                            .scaledFont(size: 10, weight: .bold)
                            .tracking(0.4)
                            .foregroundColor(Theme.Brand.primary)
                            .lineLimit(1)
                    }
                    Text(item.title)
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Image(systemName: typeIcon)
                            .font(.system(size: 9, weight: .semibold))
                        Text(timeString)
                            .scaledFont(size: 11)
                    }
                    .foregroundColor(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
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
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                history.remove(id: item.id, type: item.type)
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var destination: some View {
        switch item.type {
        case .post:      PostDetailView(postId: item.id)
        case .video:     VideoDetailView(videoId: item.id)
        case .gallery:   GalleryDetailView(galleryId: item.id)
        case .article:   ArticleDetailView(articleId: item.id, showSideMenu: .constant(false))
        case .biography: BiographyDetailView(biographyId: item.id, showSideMenu: .constant(false))
        case .interview: InterviewDetailView(interviewId: item.id, showSideMenu: .constant(false))
        }
    }

    private var typeIcon: String {
        switch item.type {
        case .post:      return "newspaper.fill"
        case .video:     return "play.rectangle.fill"
        case .gallery:   return "photo.on.rectangle"
        case .article:   return "pencil"
        case .biography: return "person.text.rectangle.fill"
        case .interview: return "mic.fill"
        }
    }

    private var timeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: item.readAt, relativeTo: Date())
    }
}
