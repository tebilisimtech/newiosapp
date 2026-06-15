import SwiftUI

// MARK: - Photo Viewer (Tek Fotoğraf - Tam Ekran)
struct PhotoViewerView: View {
    let imageUrl: String
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Siyah arka plan
            Color.black
                .ignoresSafeArea()
            
            // Fotoğraf
            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale * magnifyBy)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .updating($magnifyBy) { value, state, _ in
                                    state = value
                                }
                                .onEnded { value in
                                    scale *= value
                                    // Min/max scale sınırları
                                    scale = min(max(scale, 1.0), 4.0)
                                    
                                    // Eğer 1.0'a yakınsa resetle
                                    if scale < 1.1 {
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1.0 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            // Çift tıklama ile zoom
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                case .failure:
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                        Text("Fotoğraf yüklenemedi")
                            .foregroundColor(.white)
                    }
                @unknown default:
                    EmptyView()
                }
            }
            
            // Kapat butonu
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    }
                    .padding()
                }
                Spacer()
            }
            
            // Alt bilgi (zoom seviyesi)
            if scale > 1.1 {
                VStack {
                    Spacer()
                    Text("Yakınlaştırma: \(Int(scale * 100))%")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(.bottom, 32)
                }
            }
        }
        .statusBar(hidden: true)
    }
}

// MARK: - Photo Gallery Viewer (Çoklu Fotoğraf)
struct PhotoGalleryViewer: View {
    let photos: [String]
    let descriptions: [String]
    @Binding var currentIndex: Int
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photoUrl in
                    GeometryReader { geometry in
                        ZStack {
                            AsyncImage(url: URL(string: photoUrl)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .scaleEffect(scale * magnifyBy)
                                        .offset(offset)
                                        .gesture(
                                            MagnificationGesture()
                                                .updating($magnifyBy) { value, state, _ in
                                                    state = value
                                                }
                                                .onEnded { value in
                                                    scale *= value
                                                    scale = min(max(scale, 1.0), 4.0)
                                                    
                                                    if scale < 1.1 {
                                                        withAnimation(.spring()) {
                                                            scale = 1.0
                                                            offset = .zero
                                                        }
                                                    }
                                                }
                                        )
                                        .gesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    if scale > 1.0 {
                                                        offset = CGSize(
                                                            width: lastOffset.width + value.translation.width,
                                                            height: lastOffset.height + value.translation.height
                                                        )
                                                    }
                                                }
                                                .onEnded { value in
                                                    if scale > 1.0 {
                                                        lastOffset = offset
                                                    } else if value.translation.height > 100,
                                                              abs(value.translation.width) < 80 {
                                                        // Zoom yokken aşağı sürükle → kapat
                                                        dismiss()
                                                    }
                                                }
                                        )
                                        .onTapGesture(count: 2) {
                                            withAnimation(.spring()) {
                                                if scale > 1.0 {
                                                    scale = 1.0
                                                    offset = .zero
                                                    lastOffset = .zero
                                                } else {
                                                    scale = 2.0
                                                }
                                            }
                                        }
                                case .failure:
                                    VStack(spacing: 16) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(.white)
                                        Text("Fotoğraf yüklenemedi")
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            
                            // Açıklama (varsa)
                            if index < descriptions.count && !descriptions[index].isEmpty {
                                VStack {
                                    Spacer()
                                    Text(descriptions[index])
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(8)
                                        .padding()
                                }
                            }
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { _ in
                // Sayfa değiştiğinde zoom'u resetle
                withAnimation {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
            
            // Üst bar
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    }
                    
                    Spacer()
                    
                    Text("\(currentIndex + 1) / \(photos.count)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                }
                .padding()
                
                Spacer()
            }
        }
        .statusBar(hidden: true)
    }
}

// MARK: - Gallery Carousel View
struct GalleryCarouselView: View {
    let gallery: Gallery
    @State private var selectedImageIndex = 0
    @State private var showFullScreen = false
    
    // Not: Şu anda Gallery modeli tek resim içeriyor
    // Eğer API birden fazla fotoğraf desteklerse, burada dizi kullanılabilir
    var images: [String] {
        [gallery.image.cropped.large]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Ana fotoğraf alanı
            TabView(selection: $selectedImageIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                    ZStack {
                        AsyncImage(url: URL(string: imageUrl)) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(ProgressView())
                                    .shimmer()
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.fill")
                                                .font(.largeTitle)
                                                .foregroundColor(.gray)
                                            Text("Yüklenemedi")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(height: 400)
                        .clipped()
                        .onTapGesture {
                            showFullScreen = true
                        }
                        
                        // Büyütme işareti
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                                    .padding()
                            }
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(height: 400)
            
            // Fotoğraf sayacı (eğer birden fazla fotoğraf varsa)
            if images.count > 1 {
                Text("\(selectedImageIndex + 1) / \(images.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            PhotoViewerView(
                imageUrl: images[selectedImageIndex],
                isPresented: $showFullScreen
            )
        }
    }
}

// MARK: - Empty State View
struct GalleryEmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Henüz Galeri Yok")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Yeni galeriler eklendiğinde burada görünecektir")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
