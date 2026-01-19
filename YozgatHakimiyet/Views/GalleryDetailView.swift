import SwiftUI
import Combine
import GoogleMobileAds

struct GalleryDetailView: View {
    let galleryId: Int
    @StateObject private var viewModel = GalleryDetailViewModel()
    @State private var selectedPhotoIndex: Int = 0
    @State private var showPhotoViewer = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let gallery = viewModel.gallery {
                        // Hero Image
                        AsyncImage(url: URL(string: gallery.image.cropped.large)) { image in
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
                            Text(gallery.name)
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
                                if let author = gallery.author {
                                    Label(author.name, systemImage: "person.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Label(gallery.createdAt.prefix(10), systemImage: "calendar")
                                    Spacer()
                                    Label("\(gallery.photos.count) Fotoğraf", systemImage: "photo.on.rectangle")
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            // Description
                            if let description = gallery.description, !description.isEmpty {
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            Divider()
                            
                            // Photos Section Header
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Photos List (Alt Alta)
                        LazyVStack(spacing: 24) {
                            ForEach(Array(gallery.photos.enumerated()), id: \.element.id) { index, photo in
                                Button(action: {
                                    selectedPhotoIndex = index
                                    showPhotoViewer = true
                                }) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        AsyncImage(url: URL(string: photo.img)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                                .overlay(ProgressView())
                                        }
                                        .frame(width: geometry.size.width)
                                        .frame(height: 250)
                                        .clipped()
                                        
                                        if let description = photo.description, !description.isEmpty {
                                            Text(description)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                                .multilineTextAlignment(.leading)
                                                .padding(.horizontal)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Her 3 fotoğraftan sonra reklam (opsiyonel)
                                if (index + 1) % 3 == 0 {
                                    AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                        .frame(height: 50)
                                        .padding(.vertical, 10)
                                }
                            }
                            
                            // Yorumlar öncesi reklam
                            AdBannerView(adUnitID: Config.shared.adMobBannerUnitID)
                                .frame(height: 50)
                                .padding(.vertical, 20)
                            
                            // Comments Section
                            if let gallery = viewModel.gallery {
                                CommentsView(referenceId: gallery.id, referenceType: "gallery")
                                    .padding(.top, 20)
                            }
                        }
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
                await viewModel.loadGallery(id: galleryId)
            }
        }
        .navigationTitle("Foto Galeri")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                LogoView()
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.gallery != nil {
                    Button(action: {
                        if let gallery = viewModel.gallery {
                            ShareHelper.shareGallery(
                                title: gallery.name,
                                url: gallery.url,
                                imageUrl: gallery.image.cropped.large
                            ) { items in
                                // Items'ın boş olmadığından emin ol
                                if !items.isEmpty {
                                    shareItems = items
                                    showShareSheet = true
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
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems, isPresented: $showShareSheet)
        }
        .fullScreenCover(isPresented: $showPhotoViewer) {
            if let gallery = viewModel.gallery {
                PhotoGalleryViewer(
                    photos: gallery.photos.map { $0.img },
                    descriptions: gallery.photos.map { $0.description ?? "" },
                    currentIndex: $selectedPhotoIndex
                )
            }
        }
        .task {
            await viewModel.loadGallery(id: galleryId)
        }
    }
}

@MainActor
class GalleryDetailViewModel: ObservableObject {
    @Published var gallery: GalleryDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    func loadGallery(id: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.fetchGalleryDetail(id: id)
            gallery = response.data
        } catch {
            errorMessage = "Galeri yüklenirken bir hata oluştu: \(error.localizedDescription)"
            print("Error loading gallery: \(error)")
        }
        
        isLoading = false
    }
}

struct GalleryListView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = GalleryListViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.galleries) { gallery in
                        NavigationLink(destination: GalleryDetailView(galleryId: gallery.id)) {
                            GalleryListCard(gallery: gallery)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
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
                await viewModel.loadGalleries()
            }
            .task {
                await viewModel.loadGalleries()
            }
        }
    }
}

struct GalleryListCard: View {
    let gallery: Gallery
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: gallery.image.cropped.medium)) { image in
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
                Text(gallery.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                
                if let description = gallery.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    if let author = gallery.author {
                        Text(author.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(gallery.createdAt.prefix(10))
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

@MainActor
class GalleryListViewModel: ObservableObject {
    @Published var galleries: [Gallery] = []
    @Published var isLoading = false
    
    private let apiService = APIService.shared
    
    func loadGalleries() async {
        isLoading = true
        do {
            let response = try await apiService.fetchLatestGalleries()
            galleries = response.data
        } catch {
            print("Error loading galleries: \(error)")
        }
        isLoading = false
    }
}

