import SwiftUI

// MARK: - Scroll Progress Tracking
//
// Detay sayfalarında ScrollView'in okuma ilerlemesini ölçmek için yeniden
// kullanılabilir altyapı.
//
// **Kullanım:** ScrollView'i `.readingProgress($progress)` modifier'ı ile sar:
//
// ```swift
// @State private var scrollProgress: CGFloat = 0
// ...
// ScrollView { content }
//     .readingProgress($scrollProgress)
// ```
//
// Tracker, ScrollView'in coordinateSpace'ini ve GeometryReader'ları kendi
// içinde yönetir; çağıran view sadece progress değerini overlay'de kullanır.

// MARK: - PreferenceKey'ler

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct VisibleHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Modifier

private struct ReadingProgressModifier: ViewModifier {
    @Binding var progress: CGFloat
    private let coordinateSpace = "readingScroll"

    @State private var contentHeight: CGFloat = 0
    @State private var visibleHeight: CGFloat = 0

    func body(content: Content) -> some View {
        GeometryReader { outer in
            content
                // Content'in offset ve toplam yüksekliğini ölç.
                .background(
                    GeometryReader { inner in
                        Color.clear
                            .preference(
                                key: ScrollOffsetKey.self,
                                value: inner.frame(in: .named(coordinateSpace)).minY
                            )
                            .preference(
                                key: ContentHeightKey.self,
                                value: inner.size.height
                            )
                    }
                )
                .coordinateSpace(name: coordinateSpace)
                // ScrollView'in görünen yüksekliği — content'in ScrollView'a
                // göre değil dış GeometryReader'a göre.
                .onAppear { visibleHeight = outer.size.height }
                .onChange(of: outer.size.height) { visibleHeight = $0 }
                .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    updateProgress(offset: offset)
                }
        }
    }

    private func updateProgress(offset: CGFloat) {
        let scrollable = max(contentHeight - visibleHeight, 1)
        let raw = -offset / scrollable
        let clamped = min(max(raw, 0), 1)
        withAnimation(.easeOut(duration: 0.1)) {
            progress = clamped
        }
    }
}

// MARK: - View Extension

extension View {
    /// ScrollView üzerinde scroll ilerlemesini 0...1 aralığında izler.
    /// Çağıran view bu progress değerini `ReadingProgressBar`'a verir.
    func readingProgress(_ progress: Binding<CGFloat>) -> some View {
        modifier(ReadingProgressModifier(progress: progress))
    }
}
