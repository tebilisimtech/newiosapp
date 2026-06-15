import SwiftUI

/// 2-katmanlı `ImageCache` kullanan asenkron görsel.
/// Yükleme sırası: memory → disk → network. Aynı URL 2. açılışta network'e gitmez.
struct CachedAsyncImage: View {
    let url: String
    var aspect: ContentMode = .fill
    var placeholderIcon: String = "photo"

    @State private var phase: ImagePhase = .empty

    var body: some View {
        Group {
            switch phase {
            case .empty:
                ZStack {
                    Theme.Colors.surface
                    ProgressView()
                        .tint(Theme.Colors.textSecondary)
                }
            case .success(let uiImage):
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: aspect)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            case .failure:
                ZStack {
                    LinearGradient(
                        colors: [Theme.Colors.surface, Theme.Colors.surfaceElevated],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: placeholderIcon)
                        .font(.system(size: 32, weight: .regular))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard !url.isEmpty else {
            phase = .failure
            return
        }

        // 1. Memory cache (sync, nonisolated)
        if let image = ImageCache.shared.memoryImage(for: url) {
            phase = .success(image)
            return
        }

        // 2. Disk cache (actor)
        if let image = await ImageCache.shared.diskImage(for: url) {
            ImageCache.shared.storeInMemory(image, for: url)
            phase = .success(image)
            return
        }

        // 3. Network
        do {
            let image = try await ImageCache.shared.fetchAndStore(url: url)
            phase = .success(image)
        } catch {
            phase = .failure
        }
    }
}

enum ImagePhase {
    case empty
    case success(UIImage)
    case failure
}
