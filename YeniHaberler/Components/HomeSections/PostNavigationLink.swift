import SwiftUI
import Combine

// MARK: - Post Destination View
//
// Post.type alanına göre uygun detay view'unu döndürür. Doğrudan
// NavigationLink destination'ı veya benzer closure'larda kullanılabilir.
struct PostDestinationView: View {
    let post: Post
    @Binding var showSideMenu: Bool

    var body: some View {
        if let type = post.type?.lowercased() {
            switch type {
            case "video":   VideoDetailView(videoId: post.id)
            case "gallery": GalleryDetailView(galleryId: post.id)
            case "article": ArticleDetailView(articleId: post.id, showSideMenu: $showSideMenu)
            default:        PostDetailView(postId: post.id)
            }
        } else {
            PostDetailView(postId: post.id)
        }
    }
}

// MARK: - Post Navigation Link
//
// Home section'larında haber kartlarının ortak NavigationLink sarmalayıcısı.
// PostDestinationView'ı uygun detay sayfasına yönlendirir.
struct PostNavigationLink<Label: View>: View {
    let post: Post
    @Binding var showSideMenu: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        NavigationLink(destination: PostDestinationView(post: post, showSideMenu: $showSideMenu)) {
            label()
        }
        .buttonStyle(PlainButtonStyle())
    }
}
