import SwiftUI
import Combine
import os

// MARK: - Pages List View (Settings'ten erişilir)

struct PagesListView: View {
    @StateObject private var viewModel = PagesListViewModel()

    var body: some View {
        ZStack {
            Theme.Colors.groupedBackground.ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.pages.isEmpty {
                    SkeletonList(count: 4)
                        .padding(.top, Theme.Spacing.lg)
                } else if let error = viewModel.errorMessage, viewModel.pages.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.load() }
                    }
                } else if viewModel.pages.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "Sayfa Yok",
                        message: "Henüz görüntülenecek statik sayfa bulunmuyor."
                    )
                } else {
                    list
                }
            }
        }
        .navigationTitle("Yasal Bilgiler")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.pages.isEmpty {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(viewModel.pages) { page in
                    NavigationLink(destination: PageDetailView(pageId: page.id, fallbackName: page.name)) {
                        PageRow(page: page)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
        }
    }
}

// MARK: - Page Row

struct PageRow: View {
    let page: PageItem

    private var icon: String {
        let lower = page.name.lowercased()
        if lower.contains("kvkk") || lower.contains("kişisel") { return "person.text.rectangle" }
        if lower.contains("gizlilik") || lower.contains("privacy") { return "hand.raised.fill" }
        if lower.contains("hakkım") || lower.contains("about") { return "info.circle.fill" }
        if lower.contains("kullanım") || lower.contains("şart") || lower.contains("term") { return "doc.text.fill" }
        if lower.contains("çerez") || lower.contains("cookie") { return "circle.dotted" }
        return "doc.text"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Colors.info)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.Colors.info.opacity(0.12)))

            Text(page.name)
                .scaledFont(size: 15, weight: .medium)
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
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
}

// MARK: - Page Detail View

struct PageDetailView: View {
    let pageId: Int
    let fallbackName: String

    @StateObject private var viewModel = PageDetailViewModel()
    @StateObject private var userPrefs = UserPreferences.shared

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let page = viewModel.page {
                            // Başlık
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                EditorialEyebrow(text: "Yasal Belge")
                                Text(page.name)
                                    .scaledFont(size: 26, weight: .heavy, design: .serif)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let updated = page.updatedAt {
                                    Text("Son güncelleme: \(updated.prefix(10))")
                                        .scaledFont(size: 12)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                                EditorialDivider(withGlyph: true)
                            }
                            .padding(.horizontal, Theme.Spacing.xl)
                            .padding(.vertical, Theme.Spacing.xl)

                            // İçerik (HTML)
                            if let content = page.content, !content.isEmpty {
                                HTMLContentView(
                                    htmlContent: content,
                                    width: geometry.size.width,
                                    scale: userPrefs.fontScale.multiplier
                                )
                                .frame(width: geometry.size.width)
                                .padding(.vertical, Theme.Spacing.sm)
                                .padding(.bottom, Theme.Spacing.xxxl)
                            } else {
                                EmptyStateView(
                                    icon: "doc.text",
                                    title: "İçerik Yok",
                                    message: "Bu sayfada henüz içerik bulunmuyor."
                                )
                                .frame(minHeight: 300)
                            }
                        } else if viewModel.isLoading {
                            PostDetailSkeleton()
                                .padding(.top, Theme.Spacing.lg)
                        } else if let error = viewModel.errorMessage {
                            ErrorView(message: error) {
                                Task { await viewModel.load(id: pageId) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 400)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.page?.name ?? fallbackName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.page == nil {
                await viewModel.load(id: pageId)
            }
        }
    }
}

// MARK: - ViewModels

@MainActor
final class PagesListViewModel: ObservableObject {
    @Published var pages: [PageItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.fetchPages()
            pages = response.data
        } catch {
            errorMessage = "Sayfalar yüklenemedi."
            AppLogger.api.error("Pages list — \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}

@MainActor
final class PageDetailViewModel: ObservableObject {
    @Published var page: PageItem?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    func load(id: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.fetchPage(id: id)
            page = response.data
        } catch {
            errorMessage = "Sayfa yüklenemedi."
            AppLogger.api.error("Page detail — \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}
