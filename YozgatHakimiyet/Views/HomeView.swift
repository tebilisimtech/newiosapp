import SwiftUI
import Combine

struct HomeView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Manşet Slider
                    if !viewModel.headlines.isEmpty {
                        HeadlineSliderView(headlines: viewModel.headlines)
                            .frame(height: 300)
                            .padding(.bottom, 20)
                    }
                    
                    // Son Dakika
                    if !viewModel.breakingNews.isEmpty {
                        BreakingNewsSection(news: viewModel.breakingNews)
                            .padding(.bottom, 20)
                    }
                    
                    // Üst Manşetler
                    if !viewModel.topHeadlines.isEmpty {
                        TopHeadlinesSection(headlines: viewModel.topHeadlines, showSideMenu: $showSideMenu)
                            .padding(.bottom, 20)
                    }
                    
                    // Son Haberler
                    if !viewModel.latestPosts.isEmpty {
                        LatestPostsSection(posts: viewModel.latestPosts)
                            .padding(.bottom, 20)
                    }
                    
                    // Foto Galeri
                    if !viewModel.galleries.isEmpty {
                        GallerySection(galleries: viewModel.galleries, showSideMenu: $showSideMenu)
                            .padding(.bottom, 20)
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
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadData()
            }
        }
    }
}

// MARK: - View Model
@MainActor
class HomeViewModel: ObservableObject {
    @Published var headlines: [Post] = []
    @Published var topHeadlines: [Post] = []
    @Published var breakingNews: [Post] = []
    @Published var latestPosts: [Post] = []
    @Published var galleries: [Gallery] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        // Paralel yükleme - sonuçlar fonksiyonlar içinde state'e yazılıyor
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadHeadlines() }
            group.addTask { await self.loadTopHeadlines() }
            group.addTask { await self.loadBreakingNews() }
            group.addTask { await self.loadLatestPosts() }
            group.addTask { await self.loadGalleries() }
        }
        
        isLoading = false
    }
    
    private func loadHeadlines() async {
        do {
            let result = try await apiService.fetchHeadlines()
            headlines = result.data
        } catch {
            print("Error loading headlines: \(error)")
            // Başarısız olursa boş bırak
            headlines = []
        }
    }
    
    private func loadTopHeadlines() async {
        do {
            let result = try await apiService.fetchTopHeadlines()
            topHeadlines = result.data
        } catch {
            print("Error loading top headlines: \(error)")
            topHeadlines = []
        }
    }
    
    private func loadBreakingNews() async {
        do {
            let result = try await apiService.fetchBreakingNews()
            breakingNews = result.data
        } catch {
            print("Error loading breaking news: \(error)")
            breakingNews = []
        }
    }
    
    private func loadLatestPosts() async {
        do {
            let result = try await apiService.fetchLatestPosts(limit: 10)
            latestPosts = result.data
        } catch {
            print("Error loading latest posts: \(error)")
            latestPosts = []
        }
    }
    
    private func loadGalleries() async {
        do {
            let result = try await apiService.fetchLatestGalleries(limit: 6)
            galleries = result.data
        } catch {
            print("Error loading galleries: \(error)")
            galleries = []
        }
    }
    
    func refresh() async {
        await loadData()
    }
}

// MARK: - Headline Slider View
struct HeadlineSliderView: View {
    let headlines: [Post]
    @State private var currentIndex = 0
    @State private var timer: Timer?
    
    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(headlines.prefix(5).enumerated()), id: \.element.id) { index, headline in
                NavigationLink(destination: PostDetailView(postId: headline.id)) {
                    ZStack(alignment: .bottomLeading) {
                        AsyncImage(url: URL(string: headline.image.cropped.large)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(ProgressView())
                        }
                        .frame(height: 300)
                        .clipped()
                        
                        // Gradient overlay
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                        // Content
                        VStack(alignment: .leading, spacing: 8) {
                            Text(headline.name)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                            
                            if let description = headline.description, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(2)
                            }
                        }
                        .padding()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .tag(index)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation {
                currentIndex = (currentIndex + 1) % min(headlines.count, 5)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Breaking News Section
struct BreakingNewsSection: View {
    let news: [Post]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("SON DAKİKA")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(news.prefix(10)) { item in
                        NavigationLink(destination: PostDetailView(postId: item.id)) {
                            BreakingNewsCard(post: item)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct BreakingNewsCard: View {
    let post: Post
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: post.image.cropped.thumb)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 80, height: 80)
            .cornerRadius(8)
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(post.createdAt.prefix(10))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .frame(width: 320)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}


// MARK: - Latest Posts Section
struct LatestPostsSection: View {
    let posts: [Post]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SON HABERLER")
                .font(.headline)
                .fontWeight(.bold)
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

struct PostCard: View {
    let post: Post
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: post.image.cropped.medium)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(ProgressView())
            }
            .frame(width: 120, height: 100)
            .cornerRadius(10)
            .clipped()
            
            VStack(alignment: .leading, spacing: 6) {
                Text(post.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                
                if let description = post.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    if let author = post.author {
                        Text(author.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(post.createdAt.prefix(10))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Gallery Section
struct GallerySection: View {
    let galleries: [Gallery]
    @Binding var showSideMenu: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FOTO GALERİ")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                NavigationLink("Tümü") {
                    GalleryListView(showSideMenu: $showSideMenu)
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(galleries) { gallery in
                        NavigationLink(destination: GalleryDetailView(galleryId: gallery.id)) {
                            GalleryCard(gallery: gallery)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct GalleryCard: View {
    let gallery: Gallery
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: gallery.image.cropped.medium)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(ProgressView())
                }
                .frame(width: 200, height: 150)
                .cornerRadius(12)
                .clipped()
                
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                    Text("Galeri")
                }
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(6)
                .background(Color.black.opacity(0.6))
                .cornerRadius(6)
                .padding(8)
            }
            
            Text(gallery.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundColor(.primary)
        }
        .frame(width: 200)
    }
}

