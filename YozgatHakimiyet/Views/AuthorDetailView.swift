import SwiftUI
import Combine

// MARK: - Author Detail View
struct AuthorDetailView: View {
    let authorId: Int
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = AuthorDetailViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let author = viewModel.author {
                    // Author Header
                    VStack(spacing: 16) {
                        // Author Image
                        AsyncImage(url: URL(string: author.imageURL)) { phase in
                            switch phase {
                            case .empty:
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 120, height: 120)
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
                                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 120, height: 120)
                                    Text(author.name.prefix(1))
                                        .font(.system(size: 50, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                            @unknown default:
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 120, height: 120)
                            }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        // Author Name
                        Text(author.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        // Author Bio/Description
                        if let bio = author.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else if let description = author.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    Divider()
                    
                    // Articles Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.blue)
                            Text("Makaleler")
                                .font(.title3)
                                .fontWeight(.bold)
                            Spacer()
                            if viewModel.isLoadingArticles {
                                ProgressView()
                            }
                        }
                        .padding(.horizontal)
                        
                        if viewModel.articles.isEmpty && !viewModel.isLoadingArticles {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("Henüz makale bulunmuyor")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.articles) { article in
                                    NavigationLink(destination: ArticleDetailView(articleId: article.id, showSideMenu: $showSideMenu)) {
                                        ArticleCard(article: article)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("Hata: \(error)")
                            .font(.headline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await viewModel.loadAuthor(id: authorId)
            await viewModel.loadAuthorArticles(authorId: authorId)
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
            await viewModel.loadAuthor(id: authorId)
            await viewModel.loadAuthorArticles(authorId: authorId)
        }
    }
}

// MARK: - Article Card (for Author Detail)
struct ArticleCard: View {
    let article: AuthorArticle
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Article Image or Placeholder
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
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
                        // Görsel yüklenemezse placeholder göster
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray.opacity(0.5))
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(height: 180)
                .clipped()
            } else {
                // Görsel yoksa - placeholder
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray.opacity(0.5))
                    )
                    .frame(height: 180)
            }
            
            // Gradient Overlay - her zaman göster (görsel olsun ya da olmasın)
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
            
            // Article Title - her zaman görselin/placeholder'ın üzerine, alt kısımda
            Text(article.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .shadow(color: Color.black.opacity(0.6), radius: 3, x: 0, y: 1)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .cornerRadius(12)
        .clipped()
    }
}

// MARK: - Author Detail ViewModel
@MainActor
class AuthorDetailViewModel: ObservableObject {
    @Published var author: AuthorDetail?
    @Published var articles: [AuthorArticle] = []
    @Published var isLoading = false
    @Published var isLoadingArticles = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    func loadAuthor(id: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.fetchAuthorDetail(id: id)
            author = response.data
        } catch {
            errorMessage = "Yazar bilgileri yüklenirken bir hata oluştu: \(error.localizedDescription)"
            print("Error loading author: \(error)")
        }
        
        isLoading = false
    }
    
    func loadAuthorArticles(authorId: Int) async {
        isLoadingArticles = true
        
        do {
            let response = try await apiService.fetchAuthorArticles(authorId: authorId, limit: 20)
            articles = response.data
        } catch {
            print("Error loading author articles: \(error)")
        }
        
        isLoadingArticles = false
    }
}
