import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    let message: String

    init(message: String = "Yükleniyor...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(Theme.Brand.primary)

            Text(message)
                .scaledFont(size: 14, weight: .medium)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xxl)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let title: String
    let message: String
    let retry: (() -> Void)?

    init(
        title: String = "Bir şeyler ters gitti",
        message: String = "İçerik yüklenirken bir sorun oluştu. Lütfen tekrar deneyin.",
        retry: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retry = retry
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.danger.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(Theme.Colors.danger)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text(title)
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(message)
                    .scaledFont(size: 14)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxxl)
            }

            if let retry = retry {
                Button(action: retry) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "arrow.clockwise")
                        Text("Tekrar Dene")
                            .fontWeight(.semibold)
                    }
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        Capsule().fill(Theme.Brand.primary)
                    )
                }
                .padding(.top, Theme.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xxl)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String = "tray",
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.surface)
                    .frame(width: 90, height: 90)
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text(title)
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(message)
                    .scaledFont(size: 14)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxxl)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundColor(Theme.Brand.primary)
                        .padding(.horizontal, Theme.Spacing.xxl)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            Capsule().stroke(Theme.Brand.primary, lineWidth: 1.5)
                        )
                }
                .padding(.top, Theme.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xxl)
    }
}

// MARK: - Skeleton Block
struct SkeletonBlock: View {
    var height: CGFloat = 16
    var width: CGFloat? = nil
    var cornerRadius: CGFloat = Theme.Radius.sm

    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Theme.Colors.borderSubtle.opacity(0.5),
                        Theme.Colors.borderSubtle.opacity(0.9),
                        Theme.Colors.borderSubtle.opacity(0.5)
                    ],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Skeleton Post Card
struct SkeletonPostCard: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            SkeletonBlock(height: 90, width: 120, cornerRadius: Theme.Radius.md)
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SkeletonBlock(height: 14)
                SkeletonBlock(height: 14, width: 200)
                Spacer()
                SkeletonBlock(height: 10, width: 100)
            }
            .frame(height: 90)
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
    }
}

// MARK: - Skeleton List
struct SkeletonList: View {
    let count: Int

    init(count: Int = 5) { self.count = count }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonPostCard()
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}
