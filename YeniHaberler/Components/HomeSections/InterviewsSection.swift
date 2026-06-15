import SwiftUI
import Combine

// MARK: - View Model
@MainActor
final class InterviewsSectionViewModel: ObservableObject {
    @Published private(set) var interviews: [Interview] = []
    @Published private(set) var isLoading = false

    private let limit: Int
    private let apiService = APIService.shared

    init(limit: Int = 5) {
        self.limit = limit
    }

    func load() async {
        guard interviews.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        if let response = try? await apiService.fetchLatestInterviews(limit: limit) {
            interviews = response.data
        }
    }
}

// MARK: - Section View
struct InterviewsSection: View {
    @StateObject private var viewModel: InterviewsSectionViewModel
    @Binding var showSideMenu: Bool

    init(limit: Int = 5, showSideMenu: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: InterviewsSectionViewModel(limit: limit))
        _showSideMenu = showSideMenu
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.interviews.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    EditorialSectionHeader(title: "Röportajlar", eyebrow: "Söyleşi")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                            ForEach(viewModel.interviews) { interview in
                                NavigationLink(destination: InterviewDetailView(interviewId: interview.id, showSideMenu: $showSideMenu)) {
                                    EditorialInterviewTile(interview: interview)
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
