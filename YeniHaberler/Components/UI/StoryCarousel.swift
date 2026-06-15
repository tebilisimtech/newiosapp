import SwiftUI
import Combine
import os

struct StoryCarousel: View {
    let groups: [StoryGroup]
    @State private var selectedGroup: StoryGroup?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Brand.primary)
                Text("HİKAYELER")
                    .scaledFont(size: 11, weight: .heavy)
                    .tracking(1.4)
                    .foregroundColor(Theme.Brand.primary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(groups) { group in
                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            selectedGroup = group
                            AnalyticsService.shared.logStoryGroupOpened(groupId: group.id)
                        } label: {
                            StoryBubble(group: group)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
        }
        .fullScreenCover(item: $selectedGroup) { group in
            StoryPlayerView(group: group)
        }
    }
}

// MARK: - Story Bubble (avatar)

struct StoryBubble: View {
    let group: StoryGroup

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Theme.Brand.primary, Theme.Brand.gold, Theme.Colors.categoryPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 74, height: 74)

                Group {
                    if let photo = group.photo, !photo.isEmpty {
                        ThemedAsyncImage(url: photo)
                    } else {
                        Circle()
                            .fill(Theme.Brand.primary.opacity(0.15))
                            .overlay(
                                Image(systemName: "newspaper.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Theme.Brand.primary)
                            )
                    }
                }
                .frame(width: 62, height: 62)
                .clipShape(Circle())
            }

            Text(group.name)
                .scaledFont(size: 10, weight: .medium)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
    }
}

// MARK: - Story Player (tam ekran swipe + auto-advance)

struct StoryPlayerView: View {
    let group: StoryGroup

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var progress: Double = 0
    @State private var timer: Timer?

    private var storyDuration: TimeInterval {
        guard let item = currentItem, let length = item.length, length > 0 else { return 5.0 }
        return TimeInterval(length)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let item = currentItem {
                // Görsel
                ThemedAsyncImage(url: item.src)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()

                // Tıklanabilir alanlar (sol = geri, sağ = ileri)
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { advance(forward: false) }
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { advance(forward: true) }
                }

                VStack {
                    // Progress bars
                    HStack(spacing: 4) {
                        ForEach(group.items.indices, id: \.self) { index in
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.35))
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: geo.size.width * progressForIndex(index))
                                }
                            }
                            .frame(height: 2)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)

                    // Başlık + kapat butonu
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.name.uppercased())
                                .scaledFont(size: 11, weight: .heavy)
                                .tracking(1.5)
                                .foregroundColor(.white)
                            if let time = item.time {
                                Text(relativeTime(from: time))
                                    .scaledFont(size: 10)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)

                    Spacer()

                    // Alt: başlık + CTA
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        if let linkText = item.linkText, !linkText.isEmpty {
                            Text(linkText)
                                .scaledFont(size: 22, weight: .heavy, design: .serif)
                                .foregroundColor(.white)
                                .lineLimit(4)
                                .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                        }

                        if let urlString = item.link, !urlString.isEmpty {
                            Button {
                                openInApp(urlString)
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Text("Habere Git")
                                        .scaledFont(size: 13, weight: .bold)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.white.opacity(0.18)))
                                .overlay(Capsule().stroke(Color.white, lineWidth: 1))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(Theme.Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                    )
                }
            }
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 80 { dismiss() }
                }
        )
    }

    private var currentItem: StoryItem? {
        guard currentIndex < group.items.count else { return nil }
        return group.items[currentIndex]
    }

    private func progressForIndex(_ index: Int) -> Double {
        if index < currentIndex { return 1.0 }
        if index == currentIndex { return progress }
        return 0
    }

    private func startTimer() {
        stopTimer()
        progress = 0
        let duration = storyDuration
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            progress += 0.05 / duration
            if progress >= 1.0 {
                advance(forward: true)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func advance(forward: Bool) {
        if forward {
            if currentIndex < group.items.count - 1 {
                currentIndex += 1
                startTimer()
            } else {
                dismiss()
            }
        } else {
            if currentIndex > 0 {
                currentIndex -= 1
                startTimer()
            }
        }
    }

    /// Story modal'ını kapatır ve verilen URL için uygulama-içi navigation tetikler.
    /// NavigationManager URL'i parse edip post/video/gallery'ye yönlendirir.
    private func openInApp(_ urlString: String) {
        stopTimer()
        dismiss()
        Task { @MainActor in
            // Dismiss animasyonu için kısa gecikme
            try? await Task.sleep(nanoseconds: 350_000_000)
            await NavigationManager.shared.handleURL(urlString)
        }
    }

    private func relativeTime(from unix: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
