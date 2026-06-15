import SwiftUI
import Combine

// MARK: - View Model
//
// Server-driven UI mimarisinin parçası. Her home section'ı kendi datasını
// fetch eder; merkezi bir ViewModel'a bağımlı değildir. İleride section
// sıralaması API'den gelecek (bkz: bottom_menu pattern'i).
@MainActor
final class VideosSectionViewModel: ObservableObject {
    @Published private(set) var videos: [Video] = []
    @Published private(set) var isLoading = false

    private let limit: Int
    private let apiService = APIService.shared

    init(limit: Int = 6) {
        self.limit = limit
    }

    func load() async {
        guard videos.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        if let response = try? await apiService.fetchLatestVideos(limit: limit) {
            videos = response.data
        }
    }
}

// MARK: - Section View
struct VideosSection: View {
    @StateObject private var viewModel: VideosSectionViewModel

    init(limit: Int = 6) {
        _viewModel = StateObject(wrappedValue: VideosSectionViewModel(limit: limit))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.videos.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    EditorialSectionHeader(title: "Videolar", eyebrow: "İzle")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                            ForEach(viewModel.videos) { video in
                                NavigationLink(destination: VideoDetailView(videoId: video.id)) {
                                    EditorialVideoCard(video: video)
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
