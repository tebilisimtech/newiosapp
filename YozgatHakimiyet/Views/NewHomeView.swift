import SwiftUI
import Combine
import GoogleMobileAds

struct NewHomeView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = NewHomeViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading && viewModel.headlines.isEmpty && viewModel.latestPosts.isEmpty {
                    // İlk yükleme ekranı
                    VStack(spacing: 16) {
                        // Loading Indicator
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.blue)
                        
                        // Loading Text
                        Text("Yükleniyor...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Normal içerik
                    ScrollView {
                        VStack(spacing: 20) {
                            // Logo altı reklam
                            AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                .frame(height: 50)
                                .padding(.top, 10)
                            
                            // Üst Manşetler (Top Headlines)
                            if !viewModel.topHeadlines.isEmpty {
                                TopHeadlinesSection(headlines: viewModel.topHeadlines, showSideMenu: $showSideMenu)
                                    .padding(.top, 10)
                                
                                // Widget altı reklam
                                AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                    .frame(height: 50)
                                    .padding(.vertical, 10)
                            }
                            
                            // Manşetler Slider
                            if !viewModel.headlines.isEmpty {
                                HeadlinesSliderView(headlines: viewModel.headlines, showSideMenu: $showSideMenu)
                                    .frame(height: 380)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .padding(.bottom, 10)
                                
                                // Widget altı reklam
                                AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                    .frame(height: 50)
                                    .padding(.vertical, 10)
                            }
                            
                            // Featured Post
                            if let featuredPost = viewModel.featuredPosts.first {
                                FeaturedPostSection(post: featuredPost)
                                
                                // Widget altı reklam
                                AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                    .frame(height: 50)
                                    .padding(.vertical, 10)
                            }
                            
                            // Latest Videos Carousel
                            if !viewModel.latestVideos.isEmpty {
                                VideoCarouselSection(videos: viewModel.latestVideos)
                                
                                // Widget altı reklam
                                AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                    .frame(height: 50)
                                    .padding(.vertical, 10)
                            }
                            
                            // Latest Galleries Carousel
                            if !viewModel.latestGalleries.isEmpty {
                                GalleryCarouselSection(galleries: viewModel.latestGalleries)
                                
                                // Widget altı reklam
                                AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                    .frame(height: 50)
                                    .padding(.vertical, 10)
                            }
                            
                            // Authors Section
                            if !viewModel.authors.isEmpty {
                                AuthorsSection(authors: viewModel.authors, showSideMenu: $showSideMenu)
                                
                                // Widget altı reklam
                                AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                    .frame(height: 50)
                                    .padding(.vertical, 10)
                            }
                            
                            // Quick Access Widgets
                            QuickAccessSection()
                            
                            // Widget altı reklam
                            AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                .frame(height: 50)
                                .padding(.vertical, 10)
                            
                            // Latest News
                            LatestNewsSection(posts: viewModel.latestPosts)
                            
                            // Widget altı reklam
                            AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                .frame(height: 50)
                                .padding(.vertical, 10)
                            
                            // Popular Posts (Çok Okunanlar)
                            if !viewModel.popularPosts.isEmpty {
                                PopularPostsSection(posts: viewModel.popularPosts)
                                
                                // Widget altı reklam
                                AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                    .frame(height: 50)
                                    .padding(.vertical, 10)
                            }
                            
                            // Footer
                            AppFooter()
                                .padding(.top, 20)
                        }
                    }
                    .refreshable {
                        print("🔄 Swipe to Refresh - Tüm içerikler yenileniyor...")
                        await viewModel.loadAllContent()
                        print("✅ Swipe to Refresh - Tüm içerikler başarıyla yenilendi!")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    LogoView()
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation {
                            showSideMenu.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
            }
            .task {
                await viewModel.loadAllContent()
            }
        }
    }
}

// MARK: - Headlines Slider View
struct HeadlinesSliderView: View {
    let headlines: [Post]
    @Binding var showSideMenu: Bool
    @State private var currentIndex = 0
    @State private var timer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            let sliderWidth = geometry.size.width
            let sliderHeight: CGFloat = 380
            
            ZStack(alignment: .bottom) {
                TabView(selection: $currentIndex) {
                    ForEach(Array(headlines.prefix(10).enumerated()), id: \.element.id) { index, headline in
                        // Type'a göre yönlendirme
                        Group {
                            if let type = headline.type?.lowercased() {
                                switch type {
                                case "video":
                                    NavigationLink(destination: VideoDetailView(videoId: headline.id)) {
                                        headlineContentView(headline: headline, geometry: geometry, sliderWidth: sliderWidth, sliderHeight: sliderHeight, currentIndex: currentIndex, totalCount: min(headlines.count, 10))
                                    }
                                case "gallery":
                                    NavigationLink(destination: GalleryDetailView(galleryId: headline.id)) {
                                        headlineContentView(headline: headline, geometry: geometry, sliderWidth: sliderWidth, sliderHeight: sliderHeight, currentIndex: currentIndex, totalCount: min(headlines.count, 10))
                                    }
                                case "article":
                                    NavigationLink(destination: ArticleDetailView(articleId: headline.id, showSideMenu: $showSideMenu)) {
                                        headlineContentView(headline: headline, geometry: geometry, sliderWidth: sliderWidth, sliderHeight: sliderHeight, currentIndex: currentIndex, totalCount: min(headlines.count, 10))
                                    }
                                default: // "post" veya diğerleri
                                    NavigationLink(destination: PostDetailView(postId: headline.id)) {
                                        headlineContentView(headline: headline, geometry: geometry, sliderWidth: sliderWidth, sliderHeight: sliderHeight, currentIndex: currentIndex, totalCount: min(headlines.count, 10))
                                    }
                                }
                            } else {
                                // Type yoksa varsayılan olarak PostDetailView
                                NavigationLink(destination: PostDetailView(postId: headline.id)) {
                                    headlineContentView(headline: headline, geometry: geometry, sliderWidth: sliderWidth, sliderHeight: sliderHeight, currentIndex: currentIndex, totalCount: min(headlines.count, 10))
                                }
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .never))
                .frame(width: sliderWidth, height: sliderHeight)
                .clipped()
                .onAppear {
                    startTimer()
                }
                .onDisappear {
                    stopTimer()
                }
                .onChange(of: currentIndex) { _ in
                    resetTimer()
                }
                
                // Custom Dashed Page Indicator - En altta
                VStack(spacing: 0) {
                    // Dashed Lines Indicator
                    HStack(spacing: 6) {
                        ForEach(0..<min(headlines.count, 10), id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(currentIndex == index ? Color.white : Color.white.opacity(0.4))
                                .frame(width: currentIndex == index ? 32 : 24, height: 3)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
                    )
                    .padding(.bottom, 20) // En alttan boşluk
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
                .padding(.bottom, 0)
            }
        }
    }
    
    // MARK: - Headline Content View (Yeniden kullanılabilir içerik)
    @ViewBuilder
    private func headlineContentView(headline: Post, geometry: GeometryProxy, sliderWidth: CGFloat, sliderHeight: CGFloat, currentIndex: Int, totalCount: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image - Görselin tamamı görünecek, manşet alanına sığacak
            let imageURL = headline.headline?.image?.postImage?.cropped.medium ?? headline.image.cropped.large
            
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(ProgressView().tint(.white))
                        .frame(width: sliderWidth, height: sliderHeight)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit() // Görselin tamamı görünsün
                        .frame(maxWidth: sliderWidth, maxHeight: sliderHeight)
                        .frame(width: sliderWidth, height: sliderHeight)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                        .frame(width: sliderWidth, height: sliderHeight)
                @unknown default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: sliderWidth, height: sliderHeight)
                }
            }
            .frame(width: sliderWidth, height: sliderHeight)
            .clipped()
            .contentShape(Rectangle())
            
            // Dramatic Gradient Overlay - Red to Black
            LinearGradient(
                colors: [
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Red tint overlay for dramatic effect
            LinearGradient(
                colors: [
                    Color.red.opacity(0.1),
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.3)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            
            // Content - Başlık ve meta bilgi (Slider dışarıda gösterilecek)
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                
                // Title - Large and Bold, maksimum 2 satır
                Text(headline.name)
                    .font(.system(size: 26, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                
                // Meta Info - Sadece yazar bilgisi
                if let author = headline.author {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text(author.name)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 70) // Slider için yeterli boşluk (indicator yüksekliği + padding)
                } else {
                    Spacer()
                        .frame(height: 70) // Slider için yeterli boşluk
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(width: sliderWidth, height: sliderHeight)
        .clipped()
        .contentShape(Rectangle())
        .buttonStyle(PlainButtonStyle())
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentIndex = (currentIndex + 1) % min(headlines.count, 10)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func resetTimer() {
        stopTimer()
        startTimer()
    }
}


// MARK: - Top Headlines Section
struct TopHeadlinesSection: View {
    let headlines: [Post]
    @Binding var showSideMenu: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                    Text("ÜST MANŞETLER")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(headlines.prefix(10)) { headline in
                        TopHeadlineCard(headline: headline, showSideMenu: $showSideMenu)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 8)
    }
}

struct TopHeadlineCard: View {
    let headline: Post
    @Binding var showSideMenu: Bool
    
    var body: some View {
        // Type'a göre yönlendirme
        Group {
            if let type = headline.type?.lowercased() {
                switch type {
                case "video":
                    NavigationLink(destination: VideoDetailView(videoId: headline.id)) {
                        cardContent
                    }
                case "gallery":
                    NavigationLink(destination: GalleryDetailView(galleryId: headline.id)) {
                        cardContent
                    }
                case "article":
                    NavigationLink(destination: ArticleDetailView(articleId: headline.id, showSideMenu: $showSideMenu)) {
                        cardContent
                    }
                default: // "post" veya diğerleri
                    NavigationLink(destination: PostDetailView(postId: headline.id)) {
                        cardContent
                    }
                }
            } else {
                // Type yoksa varsayılan olarak PostDetailView
                NavigationLink(destination: PostDetailView(postId: headline.id)) {
                    cardContent
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: headline.image.cropped.medium)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(ProgressView().tint(.white))
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
                .frame(width: 280, height: 180)
                .clipped()
                
                // Gradient Overlay
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Red accent overlay
                LinearGradient(
                    colors: [
                        Color.red.opacity(0.2),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(headline.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Meta Info - Sadece yazar
                if let author = headline.author {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10, weight: .medium))
                        Text(author.name)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .cornerRadius(12)
    }
}

// MARK: - Featured Post Section
struct FeaturedPostSection: View {
    let post: Post
    
    var body: some View {
        NavigationLink(destination: PostDetailView(postId: post.id)) {
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: post.image.cropped.large)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(ProgressView())
                    }
                    .frame(width: geometry.size.width, height: 250)
                    .clipped()
                    
                    // Gradient overlay
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ÖNE ÇIKANLAR")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(4)
                        
                        Text(post.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(3)
                    }
                    .padding()
                }
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            .frame(height: 250)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}

// MARK: - Video Carousel Section
struct VideoCarouselSection: View {
    let videos: [Video]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.red)
                Text("Videolar")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                NavigationLink(destination: VideoListView(showSideMenu: .constant(false))) {
                    Text("Tümü")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(videos.prefix(5)) { video in
                        NavigationLink(destination: VideoDetailView(videoId: video.id)) {
                            VideoCarouselCard(video: video)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct VideoCarouselCard: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                AsyncImage(url: URL(string: video.image.cropped.medium)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(ProgressView())
                }
                .frame(width: 200, height: 120)
                .cornerRadius(10)
                .clipped()
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 3)
            }
            
            Text(video.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(width: 200, alignment: .leading)
        }
    }
}

// MARK: - Gallery Carousel Section
struct GalleryCarouselSection: View {
    let galleries: [Gallery]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(.blue)
                Text("Foto Galeri")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                NavigationLink(destination: GalleryListView(showSideMenu: .constant(false))) {
                    Text("Tümü")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(galleries.prefix(5)) { gallery in
                        NavigationLink(destination: GalleryDetailView(galleryId: gallery.id)) {
                            GalleryCarouselCard(gallery: gallery)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct GalleryCarouselCard: View {
    let gallery: Gallery
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: gallery.image.cropped.medium)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(ProgressView())
            }
            .frame(width: 200, height: 120)
            .cornerRadius(10)
            .clipped()
            
            Text(gallery.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(width: 200, alignment: .leading)
        }
    }
}

// MARK: - Quick Access Section
struct QuickAccessSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                Text("Hızlı Erişim")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            HStack(spacing: 12) {
                NavigationLink(destination: WeatherDetailView(showSideMenu: .constant(false))) {
                    QuickAccessButtonContent(icon: "cloud.sun.fill", title: "Hava", color: .blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: PrayerTimesDetailView(showSideMenu: .constant(false))) {
                    QuickAccessButtonContent(icon: "moon.stars.fill", title: "Namaz", color: .purple)
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: CurrencyDetailView(showSideMenu: .constant(false))) {
                    QuickAccessButtonContent(icon: "dollarsign.circle.fill", title: "Döviz", color: .green)
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: PharmacyDetailView(showSideMenu: .constant(false))) {
                    QuickAccessButtonContent(icon: "cross.case.fill", title: "Eczane", color: .red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
        }
    }
}

struct QuickAccessButtonContent: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Latest News Section
struct LatestNewsSection: View {
    let posts: [Post]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "newspaper.fill")
                    .foregroundColor(.red)
                Text("Son Haberler")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            LazyVStack(spacing: 16) {
                ForEach(posts) { post in
                    NavigationLink(destination: PostDetailView(postId: post.id)) {
                        PostCard(post: post)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Authors Section
struct AuthorsSection: View {
    let authors: [AuthorDetail]
    @Binding var showSideMenu: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                Text("Yazarlar")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                NavigationLink(destination: AuthorsListView(showSideMenu: $showSideMenu)) {
                    Text("Tümü")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(authors.prefix(6)) { author in
                        NavigationLink(destination: AuthorDetailView(authorId: author.id, showSideMenu: $showSideMenu)) {
                            AuthorHomeCard(author: author)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct AuthorHomeCard: View {
    let author: AuthorDetail
    
    var body: some View {
        VStack(spacing: 8) {
            // Author Image
            AsyncImage(url: URL(string: author.imageURL)) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        Text(author.name.prefix(1))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                    }
                @unknown default:
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.purple.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            // Author Name
            Text(author.name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 100)
        }
    }
}

// MARK: - Popular Posts Section
struct PopularPostsSection: View {
    let posts: [Post]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Çok Okunanlar")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            LazyVStack(spacing: 16) {
                ForEach(posts) { post in
                    NavigationLink(destination: PostDetailView(postId: post.id)) {
                        PopularPostCard(post: post)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

struct PopularPostCard: View {
    let post: Post
    
    var body: some View {
        HStack(spacing: 12) {
            // Post Image
            AsyncImage(url: URL(string: post.image.cropped.medium)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
            }
            .frame(width: 120, height: 100)
            .cornerRadius(10)
            .clipped()
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(post.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Meta Info
                HStack(spacing: 12) {
                    if let author = post.author {
                        Label(author.name, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !post.createdAt.isEmpty {
                        Label(String(post.createdAt.prefix(10)), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - ViewModel
@MainActor
class NewHomeViewModel: ObservableObject {
    @Published var topHeadlines: [Post] = []
    @Published var headlines: [Post] = []
    @Published var featuredPosts: [Post] = []
    @Published var latestVideos: [Video] = []
    @Published var latestGalleries: [Gallery] = []
    @Published var latestPosts: [Post] = []
    @Published var popularPosts: [Post] = []
    @Published var authors: [AuthorDetail] = []
    @Published var isLoading = false
    @Published var appLogo: String?
    
    private let apiService = APIService.shared
    
    func loadAllContent() async {
        isLoading = true
        print("🔄 Ana Sayfa - Tüm içerikler yenileniyor...")
        
        // İlk yüklemede hızlı başarısızlık için timeout ile paralel yükleme
        async let topHeadlinesTask = withTimeout(seconds: 5) { try await self.apiService.fetchTopHeadlines() }
        async let headlinesTask = withTimeout(seconds: 5) { try await self.apiService.fetchHeadlines() }
        async let featured = withTimeout(seconds: 5) { try await self.apiService.fetchFeaturedPosts() }
        async let videos = withTimeout(seconds: 5) { try await self.apiService.fetchLatestVideos(limit: 5) }
        async let galleries = withTimeout(seconds: 5) { try await self.apiService.fetchLatestGalleries(limit: 5) }
        async let posts = withTimeout(seconds: 5) { try await self.apiService.fetchLatestPosts(limit: 10) }
        async let popularTask = withTimeout(seconds: 5) { try await self.apiService.fetchPopularPosts() }
        async let authorsTask = withTimeout(seconds: 5) { try await self.apiService.fetchAuthors(perPage: 6) }
        async let settings = withTimeout(seconds: 5) { try await self.apiService.fetchSettings() }
        
        let (topHeadlinesResult, headlinesResult, featuredResult, videosResult, galleriesResult, postsResult, popularResult, authorsResult, settingsResult) = await (topHeadlinesTask, headlinesTask, featured, videos, galleries, posts, popularTask, authorsTask, settings)
        
        var successCount = 0
        var failCount = 0
        
        if let topHeadlinesResult = topHeadlinesResult {
            topHeadlines = topHeadlinesResult.data
            successCount += 1
            print("✅ Üst Manşetler yüklendi: \(topHeadlinesResult.data.count) haber")
        } else {
            failCount += 1
            print("❌ Üst Manşetler yüklenemedi - Arka planda yeniden deneniyor...")
            // Arka planda retry
            Task {
                await retryLoadTopHeadlines()
            }
        }
        
        if let headlinesResult = headlinesResult {
            headlines = headlinesResult.data
            successCount += 1
            print("✅ Ana Manşetler yüklendi: \(headlinesResult.data.count) haber")
        } else {
            failCount += 1
            print("❌ Ana Manşetler yüklenemedi - Arka planda yeniden deneniyor...")
            Task {
                await retryLoadHeadlines()
            }
        }
        
        if let featuredResult = featuredResult {
            featuredPosts = featuredResult.data
            successCount += 1
            print("✅ Öne Çıkanlar yüklendi: \(featuredResult.data.count) haber")
        } else {
            failCount += 1
            print("❌ Öne Çıkanlar yüklenemedi - Arka planda yeniden deneniyor...")
            Task {
                await retryLoadFeaturedPosts()
            }
        }
        
        if let videosResult = videosResult {
            latestVideos = videosResult.data
            successCount += 1
            print("✅ Videolar yüklendi: \(videosResult.data.count) video")
        } else {
            failCount += 1
            print("❌ Videolar yüklenemedi - Arka planda yeniden deneniyor...")
            Task {
                await retryLoadVideos()
            }
        }
        
        if let galleriesResult = galleriesResult {
            latestGalleries = galleriesResult.data
            successCount += 1
            print("✅ Galeriler yüklendi: \(galleriesResult.data.count) galeri")
        } else {
            failCount += 1
            print("❌ Galeriler yüklenemedi - Arka planda yeniden deneniyor...")
            Task {
                await retryLoadGalleries()
            }
        }
        
        if let postsResult = postsResult {
            latestPosts = postsResult.data
            successCount += 1
            print("✅ Son Haberler yüklendi: \(postsResult.data.count) haber")
        } else {
            failCount += 1
            print("❌ Son Haberler yüklenemedi - Arka planda yeniden deneniyor...")
            Task {
                await retryLoadLatestPosts()
            }
        }
        
        if let popularResult = popularResult {
            popularPosts = popularResult.data
            successCount += 1
            print("✅ Popüler Haberler yüklendi: \(popularResult.data.count) haber")
        } else {
            failCount += 1
            print("❌ Popüler Haberler yüklenemedi - Arka planda yeniden deneniyor...")
            Task {
                await retryLoadPopularPosts()
            }
        }
        
        if let authorsResult = authorsResult {
            authors = authorsResult.data
            successCount += 1
            print("✅ Yazarlar yüklendi: \(authorsResult.data.count) yazar")
        } else {
            failCount += 1
            print("❌ Yazarlar yüklenemedi - Arka planda yeniden deneniyor...")
            Task {
                await retryLoadAuthors()
            }
        }
        
        if let settingsResult = settingsResult {
            appLogo = settingsResult.data.logoMobil
            successCount += 1
            print("✅ Ayarlar yüklendi")
        } else {
            failCount += 1
            print("❌ Ayarlar yüklenemedi - Arka planda yeniden deneniyor...")
            Task {
                await retryLoadSettings()
            }
        }
        
        isLoading = false
        print("✅ Ana Sayfa - İlk yükleme tamamlandı! Başarılı: \(successCount), Başarısız: \(failCount)")
        if failCount > 0 {
            print("🔄 \(failCount) widget arka planda yeniden yükleniyor...")
        }
    }
    
    // MARK: - Background Retry Functions
    
    private func retryLoadTopHeadlines() async {
        for attempt in 1...3 {
            do {
                try await Task.sleep(nanoseconds: UInt64(attempt * 2_000_000_000)) // 2s, 4s, 6s
                let result = try await self.apiService.fetchTopHeadlines()
                await MainActor.run {
                    topHeadlines = result.data
                    print("✅ [Arka Plan] Üst Manşetler yüklendi: \(result.data.count) haber")
                }
                return
            } catch {
                if attempt == 3 {
                    print("❌ [Arka Plan] Üst Manşetler yüklenemedi (3 deneme)")
                }
            }
        }
    }
    
    private func retryLoadHeadlines() async {
        for attempt in 1...3 {
            do {
                try await Task.sleep(nanoseconds: UInt64(attempt * 2_000_000_000))
                let result = try await self.apiService.fetchHeadlines()
                await MainActor.run {
                    headlines = result.data
                    print("✅ [Arka Plan] Ana Manşetler yüklendi: \(result.data.count) haber")
                }
                return
            } catch {
                if attempt == 3 {
                    print("❌ [Arka Plan] Ana Manşetler yüklenemedi (3 deneme)")
                }
            }
        }
    }
    
    private func retryLoadFeaturedPosts() async {
        for attempt in 1...3 {
            do {
                try await Task.sleep(nanoseconds: UInt64(attempt * 2_000_000_000))
                let result = try await self.apiService.fetchFeaturedPosts()
                await MainActor.run {
                    featuredPosts = result.data
                    print("✅ [Arka Plan] Öne Çıkanlar yüklendi: \(result.data.count) haber")
                }
                return
            } catch {
                if attempt == 3 {
                    print("❌ [Arka Plan] Öne Çıkanlar yüklenemedi (3 deneme)")
                }
            }
        }
    }
    
    private func retryLoadVideos() async {
        for attempt in 1...3 {
            do {
                try await Task.sleep(nanoseconds: UInt64(attempt * 2_000_000_000))
                let result = try await self.apiService.fetchLatestVideos(limit: 5)
                await MainActor.run {
                    latestVideos = result.data
                    print("✅ [Arka Plan] Videolar yüklendi: \(result.data.count) video")
                }
                return
            } catch {
                if attempt == 3 {
                    print("❌ [Arka Plan] Videolar yüklenemedi (3 deneme)")
                }
            }
        }
    }
    
    private func retryLoadGalleries() async {
        for attempt in 1...3 {
            do {
                try await Task.sleep(nanoseconds: UInt64(attempt * 2_000_000_000))
                let result = try await self.apiService.fetchLatestGalleries(limit: 5)
                await MainActor.run {
                    latestGalleries = result.data
                    print("✅ [Arka Plan] Galeriler yüklendi: \(result.data.count) galeri")
                }
                return
            } catch {
                if attempt == 3 {
                    print("❌ [Arka Plan] Galeriler yüklenemedi (3 deneme)")
                }
            }
        }
    }
    
    private func retryLoadLatestPosts() async {
        for attempt in 1...3 {
            do {
                try await Task.sleep(nanoseconds: UInt64(attempt * 2_000_000_000))
                let result = try await self.apiService.fetchLatestPosts(limit: 10)
                await MainActor.run {
                    latestPosts = result.data
                    print("✅ [Arka Plan] Son Haberler yüklendi: \(result.data.count) haber")
                }
                return
            } catch {
                if attempt == 3 {
                    print("❌ [Arka Plan] Son Haberler yüklenemedi (3 deneme)")
                }
            }
        }
    }
    
    private func retryLoadPopularPosts() async {
        for attempt in 1...3 {
            do {
                try await Task.sleep(nanoseconds: UInt64(attempt * 2_000_000_000))
                let result = try await self.apiService.fetchPopularPosts()
                await MainActor.run {
                    popularPosts = result.data
                    print("✅ [Arka Plan] Popüler Haberler yüklendi: \(result.data.count) haber")
                }
                return
            } catch {
                if attempt == 3 {
                    print("❌ [Arka Plan] Popüler Haberler yüklenemedi (3 deneme)")
                }
            }
        }
    }
    
    private func retryLoadAuthors() async {
        for attempt in 1...3 {
            do {
                try await Task.sleep(nanoseconds: UInt64(attempt * 2_000_000_000))
                let result = try await self.apiService.fetchAuthors(perPage: 6)
                await MainActor.run {
                    authors = result.data
                    print("✅ [Arka Plan] Yazarlar yüklendi: \(result.data.count) yazar")
                }
                return
            } catch {
                if attempt == 3 {
                    print("❌ [Arka Plan] Yazarlar yüklenemedi (3 deneme)")
                }
            }
        }
    }
    
    private func retryLoadSettings() async {
        for attempt in 1...3 {
            do {
                try await Task.sleep(nanoseconds: UInt64(attempt * 2_000_000_000))
                let result = try await self.apiService.fetchSettings()
                await MainActor.run {
                    appLogo = result.data.logoMobil
                    print("✅ [Arka Plan] Ayarlar yüklendi")
                }
                return
            } catch {
                if attempt == 3 {
                    print("❌ [Arka Plan] Ayarlar yüklenemedi (3 deneme)")
                }
            }
        }
    }
}

// MARK: - Timeout Helper
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async -> T? {
    return await withTaskGroup(of: T?.self) { group -> T? in
        // API çağrısı task'ı
        group.addTask {
            do {
                return try await operation()
            } catch {
                return nil
            }
        }
        
        // Timeout task'ı
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        
        // İlk tamamlanan task'ı al
        guard let result = await group.next() else {
            group.cancelAll()
            return nil
        }
        
        // Diğer task'ları iptal et
        group.cancelAll()
        
        return result
    }
}

// MARK: - App Footer
struct AppFooter: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top Divider
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            
            VStack(spacing: 16) {
                // Copyright Text
                VStack(spacing: 8) {
                    Text("© 2025 Yozgat Hakimiyet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Tüm hakları saklıdır. İçerikler kaynak gösterilme kopyalanamaz.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                // Developer Info
                HStack(spacing: 4) {
                    Text("Haber Yazılımı:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("TE Bilişim")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
}
