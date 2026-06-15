import SwiftUI

// MARK: - Enhanced Gallery Card (Minimal & Modern)
struct EnhancedGalleryCard: View {
    let gallery: Gallery
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Resim alanı
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: gallery.image.cropped.medium)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.gray.opacity(0.5))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 280, height: 200)
                .clipped()
                
                // Galeri badge
                HStack(spacing: 4) {
                    Image(systemName: "photo.stack")
                        .font(.caption2)
                    Text("GALERİ")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7))
                .cornerRadius(6)
                .padding(10)
            }
            .frame(width: 280, height: 200)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            
            // Başlık ve bilgiler
            VStack(alignment: .leading, spacing: 6) {
                Text(gallery.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 8) {
                    Text(formatDate(gallery.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let author = gallery.author {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(author.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.top, 10)
        }
        .frame(width: 280)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let prefix = dateString.prefix(10)
        let components = prefix.split(separator: "-")
        if components.count == 3 {
            return "\(components[2]).\(components[1]).\(components[0])"
        }
        return String(prefix)
    }
}

// MARK: - Compact Gallery Card (Grid için)
struct CompactGalleryCard: View {
    let gallery: Gallery
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Resim
            AsyncImage(url: URL(string: gallery.image.cropped.medium)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray.opacity(0.5))
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 140)
            .clipped()
            
            // Başlık
            Text(gallery.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Loading Skeleton
struct GalleryCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 140)
                .shimmer()
            
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 12)
                    .shimmer()
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 80, height: 10)
                    .shimmer()
            }
            .padding(8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
