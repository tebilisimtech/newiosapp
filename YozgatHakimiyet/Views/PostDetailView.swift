import SwiftUI
import Combine
import WebKit
import UIKit
import GoogleMobileAds

struct PostDetailView: View {
    let postId: Int
    @StateObject private var viewModel = PostDetailViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let post = viewModel.post {
                        // Hero Image
                        AsyncImage(url: URL(string: post.image.cropped.large)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(ProgressView())
                        }
                        .frame(width: geometry.size.width)
                        .frame(height: 300)
                        .clipped()
                        
                        // Görsel altı reklam
                        AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                            .frame(height: 50)
                            .padding(.vertical, 10)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Title
                            Text(post.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Başlık altı reklam
                            AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                .frame(height: 50)
                                .padding(.vertical, 10)
                            
                            // Meta Info
                            VStack(alignment: .leading, spacing: 8) {
                                if let author = post.author {
                                    Label(author.name, systemImage: "person.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Label(post.createdAt.prefix(10), systemImage: "calendar")
                                    Spacer()
                                    Label("\(post.hit) görüntülenme", systemImage: "eye")
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            
                            // Categories
                            if !post.categories.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(post.categories.values), id: \.self) { category in
                                            Text(category)
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.1))
                                                .foregroundColor(.blue)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Description
                            if let description = post.description, !description.isEmpty {
                                Text(description)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Divider()
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // HTML Content - İlk Yarı
                        if !viewModel.htmlContentParts.first.isEmpty {
                            HTMLContentView(htmlContent: viewModel.htmlContentParts.first, width: geometry.size.width)
                                .frame(width: geometry.size.width)
                            
                            // İçerik altı reklam (ilk yarıdan sonra)
                            AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                .frame(height: 50)
                                .padding(.vertical, 10)
                        } else {
                            // Eğer bölünmemişse, içeriğin yarısını göster
                            HTMLContentView(htmlContent: post.content, width: geometry.size.width)
                                .frame(width: geometry.size.width)
                            
                            // İçerik altı reklam
                            AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                .frame(height: 50)
                                .padding(.vertical, 10)
                        }
                        
                        // Related Post Section - HTML içeriğinin ortasında
                        if let relatedPost = viewModel.relatedPost {
                            RelatedPostSection(relatedPost: relatedPost)
                                .padding(.top, 30)
                                .padding(.bottom, 30)
                                .padding(.horizontal)
                        }
                        
                        // HTML Content - İkinci Yarı
                        if !viewModel.htmlContentParts.second.isEmpty {
                            HTMLContentView(htmlContent: viewModel.htmlContentParts.second, width: geometry.size.width)
                                .frame(width: geometry.size.width)
                        }
                        
                        // Yorumlar öncesi reklam
                        AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                            .frame(height: 50)
                            .padding(.vertical, 20)
                        
                        // Comments Section
                        CommentsView(referenceId: post.id, referenceType: "post")
                            .padding(.top, 20)
                        
                    } else if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.errorMessage {
                        Text("Hata: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
            }
            .refreshable {
                await viewModel.loadPost(id: postId)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                LogoView()
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.post != nil {
                    Button(action: {
                        if let post = viewModel.post {
                            print("📤 PostDetailView - Sharing post: \(post.name)")
                            print("📤 PostDetailView - Post URL: \(post.url)")
                            print("📤 PostDetailView - Post Slug: \(post.slug)")
                            print("📤 PostDetailView - Image URL: \(post.image.cropped.large)")
                            
                            // URL boşsa slug'dan URL oluştur
                            let postURL: String
                            if post.url.isEmpty {
                                // Slug'dan URL oluştur
                                let baseURL = Config.shared.baseURL
                                postURL = "\(baseURL)/\(post.slug)"
                                print("📤 PostDetailView - URL was empty, created from slug: \(postURL)")
                            } else {
                                postURL = post.url
                            }
                            
                            // ViewController'ı bul
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first,
                               let rootViewController = window.rootViewController {
                                var topViewController = rootViewController
                                while let presented = topViewController.presentedViewController {
                                    topViewController = presented
                                }
                                
                                ShareHelper.sharePost(
                                    title: post.name,
                                    url: postURL,
                                    imageUrl: post.image.cropped.large,
                                    onViewController: topViewController
                                ) { items in
                                    print("📤 PostDetailView - Share completed with \(items.count) items")
                                }
                            } else {
                                // Fallback - eski yöntem
                                ShareHelper.sharePost(
                                    title: post.name,
                                    url: postURL,
                                    imageUrl: post.image.cropped.large
                                ) { items in
                                    print("📤 PostDetailView - Share completed with \(items.count) items (fallback)")
                                }
                            }
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                    }
                }
            }
        }
        .task {
            await viewModel.loadPost(id: postId)
        }
    }
}

@MainActor
class PostDetailViewModel: ObservableObject {
    @Published var post: PostDetail?
    @Published var relatedPost: Post?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var htmlContentParts: (first: String, second: String) = ("", "")
    
    private let apiService = APIService.shared
    
    func loadPost(id: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.fetchPostDetail(id: id)
            post = response.data
            
            // HTML içeriğini ikiye böl (ortasına ilgili haber yerleştirmek için)
            splitHTMLContent(response.data.content)
            
            // İlgili haberleri yükle
            await loadRelatedPost(post: response.data)
        } catch {
            errorMessage = "Haber yüklenirken bir hata oluştu: \(error.localizedDescription)"
            print("Error loading post: \(error)")
        }
        
        isLoading = false
    }
    
    private func splitHTMLContent(_ content: String) {
        // HTML içeriğini paragraflara ayır
        let paragraphs = content.components(separatedBy: "</p>")
        
        // Eğer yeterli paragraf yoksa, tüm içeriği ilk kısma koy
        guard paragraphs.count > 2 else {
            htmlContentParts = (content, "")
            return
        }
        
        // Ortadaki paragraftan sonra böl
        let midPoint = paragraphs.count / 2
        let firstPart = paragraphs[0..<midPoint].joined(separator: "</p>") + "</p>"
        let secondPart = paragraphs[midPoint..<paragraphs.count].joined(separator: "</p>")
        
        htmlContentParts = (firstPart, secondPart)
    }
    
    private func loadRelatedPost(post: PostDetail) async {
        // Categories'den rastgele bir category_id al
        guard !post.categories.isEmpty else {
            return
        }
        
        // Category ID'lerini al
        let categoryIds = Array(post.categories.keys)
        
        // Rastgele bir category ID seç
        guard let randomCategoryId = categoryIds.randomElement() else {
            return
        }
        
        do {
            let response = try await apiService.fetchRelatedPosts(postId: post.id, categoryId: randomCategoryId)
            
            // Mevcut post'u filtrele ve rastgele bir haber seç
            let filteredPosts = response.data.filter { $0.id != post.id }
            
            if let randomPost = filteredPosts.randomElement() {
                relatedPost = randomPost
            } else if let firstPost = filteredPosts.first {
                relatedPost = firstPost
            }
        } catch {
            // İlgili haber yüklenemezse sessizce devam et
            print("⚠️ Error loading related post: \(error.localizedDescription)")
        }
    }
}

// MARK: - Related Post Section
struct RelatedPostSection: View {
    let relatedPost: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let type = relatedPost.type?.lowercased() {
                    switch type {
                    case "video":
                        NavigationLink(destination: VideoDetailView(videoId: relatedPost.id)) {
                            relatedPostCardContent
                        }
                    case "gallery":
                        NavigationLink(destination: GalleryDetailView(galleryId: relatedPost.id)) {
                            relatedPostCardContent
                        }
                    case "article":
                        NavigationLink(destination: ArticleDetailView(articleId: relatedPost.id, showSideMenu: .constant(false))) {
                            relatedPostCardContent
                        }
                    default: // "post" veya diğerleri
                        NavigationLink(destination: PostDetailView(postId: relatedPost.id)) {
                            relatedPostCardContent
                        }
                    }
                } else {
                    // Type yoksa varsayılan olarak PostDetailView
                    NavigationLink(destination: PostDetailView(postId: relatedPost.id)) {
                        relatedPostCardContent
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var relatedPostCardContent: some View {
        ZStack(alignment: .leading) {
            // Red Background
            Color.red
                .frame(height: 140)
            
            HStack(spacing: 0) {
                // Image Section (Left)
                AsyncImage(url: URL(string: relatedPost.image.cropped.medium)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 140, height: 140)
                .clipped()
                
                // Text Section (Right)
                VStack(alignment: .leading, spacing: 8) {
                    Text(relatedPost.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 140)
            }
            
            // Gradient Overlay on Image
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.3)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 140, height: 140)
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - HTML Content View
struct HTMLContentView: UIViewRepresentable {
    let htmlContent: String
    let width: CGFloat
    let hideFirstHeading: Bool
    @State private var contentHeight: CGFloat = 400
    
    init(htmlContent: String, width: CGFloat, hideFirstHeading: Bool = false) {
        self.htmlContent = htmlContent
        self.width = width
        self.hideFirstHeading = hideFirstHeading
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "heightChanged")
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // HTML içeriğinden ilk başlığı kaldır (eğer hideFirstHeading true ise)
        var processedContent = htmlContent
        if hideFirstHeading {
            // İlk h1, h2, h3 etiketini kaldır
            let patterns = [
                #"<h1[^>]*>.*?</h1>"#,
                #"<h2[^>]*>.*?</h2>"#,
                #"<h3[^>]*>.*?</h3>"#
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                    let range = NSRange(processedContent.startIndex..., in: processedContent)
                    if let match = regex.firstMatch(in: processedContent, range: range) {
                        if let swiftRange = Range(match.range, in: processedContent) {
                            processedContent.removeSubrange(swiftRange)
                            break // İlk eşleşmeyi bulduk, çık
                        }
                    }
                }
            }
        }
        
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    -webkit-user-select: text;
                    -webkit-touch-callout: default;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    padding: 16px;
                    margin: 0;
                    font-size: 16px;
                    line-height: 1.6;
                    color: #000;
                    background: transparent;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    display: block;
                    margin: 16px 0;
                    border-radius: 8px;
                }
                p {
                    margin: 12px 0;
                }
                h1, h2, h3, h4, h5, h6 {
                    margin: 20px 0 12px 0;
                    font-weight: 600;
                }
                \(hideFirstHeading ? """
                /* İlk başlık etiketlerini gizle */
                body > h1:first-of-type,
                body > h2:first-of-type,
                body > h3:first-of-type,
                body > h4:first-of-type,
                body > h5:first-of-type,
                body > h6:first-of-type,
                body > *:first-child h1:first-of-type,
                body > *:first-child h2:first-of-type,
                body > *:first-child h3:first-of-type,
                body > div:first-child h1,
                body > div:first-child h2,
                body > div:first-child h3,
                body > p:first-child strong,
                body > p:first-child b {
                    display: none !important;
                }
                """ : "")
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #FFF;
                    }
                }
            </style>
            <script>
                window.addEventListener('load', function() {
                    \(hideFirstHeading ? """
                    // İlk başlığı gizle (h1, h2, h3) - daha agresif yaklaşım
                    function hideFirstHeading() {
                        // Önce h1, h2, h3 etiketlerini kontrol et
                        var headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
                        if (headings.length > 0) {
                            headings[0].style.display = 'none';
                        }
                        // Ayrıca div içindeki ilk başlık benzeri içeriği de kontrol et
                        var firstDiv = document.querySelector('body > div:first-child, body > p:first-child');
                        if (firstDiv) {
                            var text = firstDiv.textContent.trim();
                            // Eğer ilk div/p içeriği başlık gibi görünüyorsa (büyük harfler, kısa metin) gizle
                            if (text.length < 200 && (text === text.toUpperCase() || firstDiv.querySelector('strong, b'))) {
                                firstDiv.style.display = 'none';
                            }
                        }
                    }
                    hideFirstHeading();
                    // DOM değişikliklerini izle
                    setTimeout(hideFirstHeading, 100);
                    setTimeout(hideFirstHeading, 500);
                    """ : "")
                    setTimeout(function() {
                        var height = document.body.scrollHeight;
                        window.webkit.messageHandlers.heightChanged.postMessage(height);
                    }, 100);
                });
            </script>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: HTMLContentView
        
        init(parent: HTMLContentView) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightChanged", let height = message.body as? Double {
                DispatchQueue.main.async {
                    self.parent.contentHeight = CGFloat(height)
                }
            }
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: WKWebView, context: Context) -> CGSize? {
        return CGSize(width: width, height: contentHeight)
    }
}

