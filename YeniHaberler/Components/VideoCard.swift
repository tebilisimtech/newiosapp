import SwiftUI

// MARK: - Modern Video Card
struct VideoCard: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                AspectImage(url: video.image.cropped.medium, aspectRatio: 16/9)

                // Play overlay
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 56, height: 56)
                    Circle()
                        .fill(Theme.Brand.primary.opacity(0.9))
                        .frame(width: 48, height: 48)
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 2)
                }
                .padding(Theme.Spacing.md)
            }

            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let category = video.categories.values.first {
                    Text(category.uppercased())
                        .scaledFont(size: 10, weight: .bold)
                        .tracking(0.5)
                        .foregroundColor(Theme.Brand.primary)
                        .lineLimit(1)
                }

                Text(video.name)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = video.description, !description.isEmpty {
                    Text(description)
                        .scaledFont(size: 13)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: Theme.Spacing.md) {
                    Label {
                        Text(video.createdAt.prefix(10))
                            .scaledFont(size: 11)
                    } icon: {
                        Image(systemName: "calendar").font(.system(size: 10))
                    }
                    .foregroundColor(Theme.Colors.textTertiary)

                    Spacer()
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .themedShadow(Theme.Shadow.small)
    }
}
