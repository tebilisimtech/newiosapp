import SwiftUI
import Combine
import UIKit
import AVFoundation

// MARK: - Video Feed (Keşfet)
//
// Dikey, sayfalanan (snap) video akışı — TikTok/Reels mantığı. Aşağı kaydırdıkça
// sıradaki video aktifleşip otomatik oynar; yalnızca aktif sayfanın oynatıcısı
// mount edilir (diğerleri poster), böylece aynı anda tek video oynar.
//
// Dikey sayfalama UIPageViewController (.vertical) ile yapılır (iOS 16 uyumlu,
// döndürme hilesi yok). Sayfalar `viewModel.activeIndex`'i izlediği için, page
// controller'lar cache'lense de aktiflik doğru takip edilir.

// MARK: - View Model
@MainActor
final class VideoFeedViewModel: ObservableObject {
    @Published private(set) var videos: [Video] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var details: [Int: VideoDetail] = [:]
    /// Şu an ekranda olan (oynayan) sayfanın index'i.
    @Published var activeIndex: Int = 0

    private let api = APIService.shared
    private let perPage = 10
    private var page = 1
    private var canLoadMore = true
    private var isLoadingMore = false

    func loadInitial() async {
        guard videos.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.fetchVideos(page: 1, perPage: perPage)
            videos = response.data
            page = 1
            canLoadMore = !response.data.isEmpty
        } catch {
            errorMessage = "Videolar yüklenemedi. Lütfen tekrar deneyin."
        }
        isLoading = false
    }

    func retry() async {
        videos = []
        activeIndex = 0
        await loadInitial()
    }

    /// Sona yaklaşıldıkça yeni sayfa getirir (reklam sayfaları dahil entry index'i).
    func loadMoreIfNeeded(activeIndex: Int, total: Int) async {
        guard activeIndex >= total - 3 else { return }
        await loadMore()
    }

    private func loadMore() async {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let next = page + 1
            let response = try await api.fetchVideos(page: next, perPage: perPage)
            if response.data.isEmpty {
                canLoadMore = false
            } else {
                let existing = Set(videos.map { $0.id })
                let fresh = response.data.filter { !existing.contains($0.id) }
                videos.append(contentsOf: fresh)
                page = next
                if fresh.isEmpty { canLoadMore = false }
            }
        } catch {
            // sessizce yut — kullanıcı tekrar kaydırınca yeniden denenir
        }
    }

    /// Embed/url için detayı döndürür (cache'li).
    func detail(for id: Int) async -> VideoDetail? {
        if let cached = details[id] { return cached }
        do {
            let response = try await api.fetchVideoDetail(id: id)
            details[id] = response.data
            return response.data
        } catch {
            return nil
        }
    }
}

// MARK: - Feed View
struct VideoFeedView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = VideoFeedViewModel()
    @ObservedObject private var adManager = AdvertManager.shared

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading && viewModel.videos.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage, viewModel.videos.isEmpty {
                errorState(error)
            } else if viewModel.videos.isEmpty {
                emptyState
            } else {
                let entries = feedEntries
                VerticalPageView(pageCount: entries.count,
                                 currentIndex: $viewModel.activeIndex) { index in
                    pageView(for: entries[min(index, entries.count - 1)], index: index)
                }
                .ignoresSafeArea()
                .onChange(of: viewModel.activeIndex) { newIndex in
                    Task { await viewModel.loadMoreIfNeeded(activeIndex: newIndex, total: entries.count) }
                }
            }

            topBar
        }
        .task {
            // Video sesi sessiz (silent) modda da duyulsun.
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            AdvertManager.shared.loadIfNeeded()
            await viewModel.loadInitial()
        }
    }

    // MARK: Feed entries (videolar + araya serpiştirilen reklam — #2024)
    private var feedEntries: [VideoFeedEntry] {
        let hasAd = AdvertManager.shared.advert(forChannel: AdChannel.videoListInline) != nil
        guard hasAd else { return viewModel.videos.map { .video($0) } }
        var out: [VideoFeedEntry] = []
        var adIndex = 0
        for (i, video) in viewModel.videos.enumerated() {
            out.append(.video(video))
            // Her 4 videodan sonra (son hariç) bir reklam sayfası.
            if (i + 1) % 4 == 0 && i < viewModel.videos.count - 1 {
                out.append(.ad(adIndex))
                adIndex += 1
            }
        }
        return out
    }

    @ViewBuilder
    private func pageView(for entry: VideoFeedEntry, index: Int) -> some View {
        switch entry {
        case .video(let video):
            VideoFeedPage(video: video, index: index, viewModel: viewModel)
        case .ad:
            AdvertFeedPage(channel: AdChannel.videoListInline)
        }
    }

    // MARK: Top bar (menü + Keşfet)
    private var topBar: some View {
        HStack {
            Button(action: { withAnimation { showSideMenu.toggle() } }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.15)))
                    .accessibilityLabel("Menüyü aç")
            }
            Spacer()
            Text("Keşfet")
                .scaledFont(size: 16, weight: .heavy, design: .serif)
                .foregroundColor(.white)
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "play.slash")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.white.opacity(0.6))
            Text("Video Yok")
                .scaledFont(size: 18, weight: .bold)
                .foregroundColor(.white)
            Text("Şu anda görüntülenecek video bulunmuyor.")
                .scaledFont(size: 14)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text(message)
                .scaledFont(size: 15)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Button("Tekrar Dene") { Task { await viewModel.retry() } }
                .scaledFont(size: 14, weight: .bold)
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.md)
                .background(Capsule().fill(Theme.Brand.primary))
        }
        .padding(Theme.Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Single Page
struct VideoFeedPage: View {
    let video: Video
    let index: Int
    @ObservedObject var viewModel: VideoFeedViewModel

    @State private var detail: VideoDetail?

    private var isActive: Bool { viewModel.activeIndex == index }

    /// image boşsa headline_image'a düş.
    private var posterURL: String {
        let main = video.image.cropped.large
        if !main.isEmpty { return main }
        switch video.headlineImage {
        case .string(let s): return s
        case .object(let img):
            return img.cropped.large.isEmpty ? img.original : img.cropped.large
        case .none: return ""
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer(minLength: 0)

                // Üstte haber başlığı (ortalı, beyaz)
                Text(video.name)
                    .scaledFont(size: 23, weight: .heavy, design: .serif)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.xl)

                // Altında video
                videoArea

                Spacer(minLength: 0)

                // Kaydırma ipucu
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .accessibilityLabel("Sonraki video için kaydır")
            }
            .padding(.top, 72)
            .padding(.bottom, 96)
        }
        .task(id: isActive) {
            if isActive && detail == nil {
                detail = await viewModel.detail(for: video.id)
            }
        }
    }

    @ViewBuilder
    private var videoArea: some View {
        let w = UIScreen.main.bounds.width - Theme.Spacing.lg * 2
        let h = w * 9 / 16
        ZStack {
            Color.black

            if isActive, let detail {
                InlineVideoPlayer(
                    source: VideoSource.detect(embed: detail.embed, url: detail.url, mediaUrl: detail.mediaUrl),
                    posterURL: posterURL,
                    fallbackURL: URL(string: detail.url),
                    autoplay: true
                )
            } else {
                posterOverlay
            }
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var posterOverlay: some View {
        ZStack {
            if !posterURL.isEmpty {
                ThemedAsyncImage(url: posterURL, aspect: .fill)
            }
            LinearGradient(
                colors: [.black.opacity(0.1), .black.opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
            if isActive {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                    .padding(18)
                    .background(Circle().fill(Theme.Brand.primary.opacity(0.92)))
            }
        }
    }
}

// MARK: - Feed Entry (video veya reklam)
enum VideoFeedEntry: Identifiable {
    case video(Video)
    case ad(Int)

    var id: String {
        switch self {
        case .video(let v): return "v\(v.id)"
        case .ad(let n):    return "ad\(n)"
        }
    }
}

// MARK: - Reklam Sayfası (feed içi, #2024)
struct AdvertFeedPage: View {
    let channel: Int

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: 0)

                Text("SPONSORLU")
                    .scaledFont(size: 10, weight: .heavy)
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.55))

                AdvertBannerView(channel: channel, maxHeight: 420)

                Spacer(minLength: 0)

                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .accessibilityLabel("Sonraki için kaydır")
            }
            .padding(.top, 72)
            .padding(.bottom, 96)
        }
    }
}

// MARK: - Vertical Pager (UIPageViewController .vertical)
//
// SwiftUI'da iOS 16 uyumlu, gerçek snap'leyen dikey sayfalama. Her sayfa bir
// UIHostingController. Sayfa değişince `currentIndex` güncellenir.
struct VerticalPageView<Content: View>: UIViewControllerRepresentable {
    let pageCount: Int
    @Binding var currentIndex: Int
    @ViewBuilder var content: (Int) -> Content

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(transitionStyle: .scroll,
                                      navigationOrientation: .vertical)
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        pvc.view.backgroundColor = .black
        if pageCount > 0 {
            let start = min(max(currentIndex, 0), pageCount - 1)
            pvc.setViewControllers([context.coordinator.host(for: start)],
                                   direction: .forward, animated: false)
        }
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        let shown = (pvc.viewControllers?.first as? IndexedHostingController)
        if shown == nil, pageCount > 0 {
            let start = min(max(currentIndex, 0), pageCount - 1)
            pvc.setViewControllers([context.coordinator.host(for: start)],
                                   direction: .forward, animated: false)
        } else if let shown, shown.index != currentIndex,
                  currentIndex >= 0, currentIndex < pageCount {
            let dir: UIPageViewController.NavigationDirection = currentIndex > shown.index ? .forward : .reverse
            pvc.setViewControllers([context.coordinator.host(for: currentIndex)],
                                   direction: dir, animated: true)
        }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: VerticalPageView
        init(_ parent: VerticalPageView) { self.parent = parent }

        func host(for index: Int) -> IndexedHostingController {
            let vc = IndexedHostingController(index: index,
                                              rootView: AnyView(parent.content(index)))
            vc.view.backgroundColor = .black
            return vc
        }

        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerBefore vc: UIViewController) -> UIViewController? {
            guard let i = (vc as? IndexedHostingController)?.index, i > 0 else { return nil }
            return host(for: i - 1)
        }

        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerAfter vc: UIViewController) -> UIViewController? {
            guard let i = (vc as? IndexedHostingController)?.index,
                  i < parent.pageCount - 1 else { return nil }
            return host(for: i + 1)
        }

        func pageViewController(_ pvc: UIPageViewController,
                                didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController],
                                transitionCompleted completed: Bool) {
            guard completed,
                  let i = (pvc.viewControllers?.first as? IndexedHostingController)?.index else { return }
            parent.currentIndex = i
        }
    }
}

/// Index taşıyan hosting controller — pager komşu sayfaları bununla bulur.
final class IndexedHostingController: UIHostingController<AnyView> {
    let index: Int
    init(index: Int, rootView: AnyView) {
        self.index = index
        super.init(rootView: rootView)
    }
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) yok") }
}
