import SwiftUI

// MARK: - İlgi Alanları Ekranı
//
// Android InterestsScreen karşılığı. Sunucu kategorilerini chip olarak gösterir,
// kullanıcı ilgilendiği konuları seçer → UserInterests kalıcı saklar.
// onboarding=true: açılış akışında, "Atla" var, geri yok.
struct InterestsView: View {
    var onboarding: Bool = false
    var onDone: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var interests = UserInterests.shared
    @State private var categories: [Category] = []
    @State private var selected: [InterestCategory] = []
    @State private var isLoading = true

    private let api = APIService.shared

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.Brand.primary)
                } else {
                    content
                }
            }
            .navigationTitle("İlgi Alanların")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if onboarding {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Atla") { finish() }
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                } else {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Kapat") { dismiss() }
                            .foregroundColor(Theme.Brand.primary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .task { await load() }
        }
        .navigationViewStyle(.stack)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Seni ne ilgilendiriyor?")
                    .scaledFont(size: 22, weight: .heavy, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("Akışını kişiselleştirmek için ilgilendiğin konuları seç.")
                    .scaledFont(size: 13)
                    .foregroundColor(Theme.Colors.textSecondary)

                FlowLayout(spacing: Theme.Spacing.sm) {
                    ForEach(categories) { c in chip(c) }
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.xl)
            .padding(.bottom, 110)
        }
    }

    private func chip(_ c: Category) -> some View {
        let isSel = selected.contains { $0.id == c.id }
        return Button {
            withAnimation(Theme.Animations.snappy) {
                if isSel {
                    selected.removeAll { $0.id == c.id }
                } else {
                    selected.append(InterestCategory(id: c.id, name: c.name, slug: c.slug ?? ""))
                }
            }
        } label: {
            HStack(spacing: 4) {
                if isSel {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(c.name)
                    .scaledFont(size: 13, weight: .semibold)
            }
            .foregroundColor(isSel ? Theme.Colors.textOnBrand : Theme.Colors.textPrimary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Capsule().fill(isSel ? Theme.Brand.primary : Theme.Colors.surfaceElevated))
            .overlay(Capsule().stroke(Theme.Colors.borderSubtle, lineWidth: isSel ? 0 : 0.5))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.Colors.borderSubtle).frame(height: 0.5)
            Button { finish() } label: {
                Text(selected.isEmpty ? "En az 1 konu seç" : "Devam (\(selected.count))")
                    .scaledFont(size: 16, weight: .bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .fill(selected.isEmpty ? Theme.Colors.textTertiary : Theme.Brand.primary)
                    )
            }
            .disabled(selected.isEmpty)
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.surface.ignoresSafeArea(edges: .bottom))
    }

    private func load() async {
        if let resp = try? await api.fetchCategories() {
            // Temiz seçim için yalnızca üst kategoriler; yoksa hepsi.
            let parents = resp.data.filter { $0.parentId == nil }
            categories = parents.isEmpty ? resp.data : parents
        }
        selected = interests.categories
        isLoading = false
    }

    private func finish() {
        interests.set(selected)
        interests.markPrompted()
        onDone?()
        if !onboarding { dismiss() }
    }
}

// MARK: - FlowLayout (chip wrapping, iOS 16+)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
