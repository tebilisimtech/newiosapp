import SwiftUI
import Combine
import WebKit

// MARK: - Article Detail View
struct ArticleDetailView: View {
    let articleId: Int
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = ArticleDetailViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let article = viewModel.article {
                        // Hero Image
                        AsyncImage(url: article.imageURL.flatMap { URL(string: $0) }) { phase in
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
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Image(systemName: "doc.text")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray)
                                    )
                            @unknown default:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.width * 9/16)
                        .clipped()
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Title
                            Text(article.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Meta Info
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    // Author
                                    if let author = article.author {
                                        Label(author.name, systemImage: "person.fill")
                                    }
                                    
                                    Spacer()
                                    
                                    // Views
                                    if let hit = article.hit {
                                        Label("\(hit) görüntülenme", systemImage: "eye")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                
                                // Date
                                HStack {
                                    Label(article.createdAt.prefix(10), systemImage: "calendar")
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            
                            // Categories
                            if let categories = article.categories, !categories.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(categories.values), id: \.self) { category in
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
                            
                            // Tags
                            if let tags = article.tags, !tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(tags, id: \.self) { tag in
                                            Text("#\(tag)")
                                                .font(.caption)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(Color.gray.opacity(0.1))
                                                .foregroundColor(.secondary)
                                                .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Description
                            if let description = article.description, !description.isEmpty {
                                Text(description)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Divider()
                            }
                            
                            // Content
                            if !article.content.isEmpty {
                                HTMLContentView(htmlContent: article.content, width: geometry.size.width)
                                    .frame(width: geometry.size.width)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Comments Section
                        CommentsView(referenceId: article.id, referenceType: "article")
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
                await viewModel.loadArticle(id: articleId)
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
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.article != nil {
                    Button(action: {
                        if let article = viewModel.article {
                            let articleURL = article.url ?? "\(Config.shared.baseURL)/articles/\(article.id)"
                            ShareHelper.sharePost(
                                title: article.name,
                                url: articleURL,
                                imageUrl: article.imageURL
                            ) { items in
                                print("📤 ArticleDetailView - Share completed with \(items.count) items")
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
            await viewModel.loadArticle(id: articleId)
        }
    }
}


// MARK: - Article Detail ViewModel
@MainActor
class ArticleDetailViewModel: ObservableObject {
    @Published var article: ArticleDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    func loadArticle(id: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.fetchArticleDetail(id: id)
            article = response.data
        } catch {
            errorMessage = "Makale yüklenirken bir hata oluştu: \(error.localizedDescription)"
            print("Error loading article: \(error)")
        }
        
        isLoading = false
    }
}
