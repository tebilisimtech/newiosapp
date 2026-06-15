import SwiftUI
import Combine

// MARK: - View Model
//
// "Günün Manşeti" (daily_headline). v2'de karşılığı olmadığı için eski `/_api/?daily_headline`
// (v1, token'sız) ucundan beslenir. settings.modules["daily_headline"] aktifken çizilir.
@MainActor
final class DailyHeadlineSectionViewModel: ObservableObject {
    @Published private(set) var items: [DailyHeadlineItem] = []
    @Published private(set) var isLoading = false

    private let apiService = APIService.shared

    func load() async {
        guard items.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        if let result = try? await apiService.fetchDailyHeadline() {
            items = result
        }
    }
}

// MARK: - Section View
struct DailyHeadlineSection: View {
    @StateObject private var viewModel = DailyHeadlineSectionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.items.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    EditorialSectionHeader(title: "Günün Manşeti", eyebrow: "Editör seçimi")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                            ForEach(viewModel.items) { item in
                                NavigationLink(destination: PostDetailView(postId: item.id)) {
                                    DailyHeadlineCard(item: item)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.sm)
                    }
                }
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .task { await viewModel.load() }
    }
}

private struct DailyHeadlineCard: View {
    let item: DailyHeadlineItem

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ThemedAsyncImage(url: item.imageURL, aspect: .fill)
                .frame(width: 260, height: 150)
                .background(Theme.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(alignment: .topLeading) {
                    PillTag(text: "MANŞET", color: Theme.Brand.primary, style: .filled)
                        .padding(Theme.Spacing.sm)
                }

            Text(item.title)
                .scaledFont(size: 16, weight: .bold, design: .serif)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(3)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260, alignment: .leading)
        }
        .frame(width: 260)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Günün manşeti: \(item.title)")
        .accessibilityHint("Habere git")
        .accessibilityAddTraits(.isLink)
    }
}
