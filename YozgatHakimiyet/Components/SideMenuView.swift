import SwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @Binding var selectedTab: Int
    @State private var selectedMenu: MenuItem = .home
    
    var body: some View {
        ZStack {
            if isShowing {
                // Background overlay with blur
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .background(.ultraThinMaterial)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                    }
                
                // Side menu
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Modern Header
                        VStack(alignment: .leading, spacing: 0) {
                            // Header Background
                            ZStack(alignment: .topLeading) {
                                // Subtle gradient background
                                LinearGradient(
                                    colors: [
                                        Color(.systemGray6),
                                        Color(.systemBackground)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                
                                // Content
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(spacing: 16) {
                                        // Logo Container
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.1))
                                                .frame(width: 60, height: 60)
                                            
                                            Image(systemName: "newspaper.fill")
                                                .font(.system(size: 28, weight: .bold))
                                                .foregroundColor(.blue)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Yozgat Hakimiyet")
                                                .font(.system(size: 22, weight: .bold))
                                                .foregroundColor(.primary)
                                            
                                            Text("Haber Portalı")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    // Close button
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            isShowing = false
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 14, weight: .semibold))
                                            Text("Kapat")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(24)
                            }
                            .frame(height: 160)
                            
                            // Divider
                            Divider()
                                .background(Color(.systemGray4))
                        }
                        
                        // Menu Items
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                // Ana Menü
                                MenuSection(title: "Ana Menü") {
                                    MenuRow(
                                        item: .home,
                                        isSelected: selectedMenu == .home
                                    ) {
                                        handleMenuSelection(.home, tab: 0)
                                    }
                                    
                                    MenuRow(
                                        item: .breaking,
                                        isSelected: selectedMenu == .breaking
                                    ) {
                                        handleMenuSelection(.breaking, tab: 1)
                                    }
                                    
                                    MenuRow(
                                        item: .headlines,
                                        isSelected: selectedMenu == .headlines
                                    ) {
                                        handleMenuSelection(.headlines, tab: 2)
                                    }
                                }
                                
                                // Medya
                                MenuSection(title: "Medya") {
                                    MenuRow(
                                        item: .videos,
                                        isSelected: selectedMenu == .videos
                                    ) {
                                        handleMenuSelection(.videos, tab: 3)
                                    }
                                    
                                    MenuRow(
                                        item: .galleries,
                                        isSelected: selectedMenu == .galleries
                                    ) {
                                        handleMenuSelection(.galleries, tab: 4)
                                    }
                                }
                                
                                // Diğer
                                MenuSection(title: "Diğer") {
                                    MenuRow(
                                        item: .search,
                                        isSelected: selectedMenu == .search
                                    ) {
                                        handleMenuSelection(.search, tab: 5)
                                    }
                                    
                                    MenuRow(
                                        item: .standings,
                                        isSelected: selectedMenu == .standings
                                    ) {
                                        handleMenuSelection(.standings, tab: 6)
                                    }
                                    
                                    MenuRow(
                                        item: .authors,
                                        isSelected: selectedMenu == .authors
                                    ) {
                                        handleMenuSelection(.authors, tab: 7)
                                    }
                                    
                                    MenuRow(
                                        item: .categories,
                                        isSelected: selectedMenu == .categories
                                    ) {
                                        selectedMenu = .categories
                                        // TODO: Categories view eklenince tab ekle
                                    }
                                    
                                    MenuRow(
                                        item: .settings,
                                        isSelected: selectedMenu == .settings
                                    ) {
                                        selectedMenu = .settings
                                        // TODO: Settings view eklenince tab ekle
                                    }
                                }
                            }
                            .padding(.vertical, 16)
                        }
                        
                        Spacer()
                        
                        // Modern Footer
                        VStack(spacing: 0) {
                            Divider()
                                .background(Color(.systemGray4))
                            
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Versiyon 1.0.0")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text("© 2026 Yozgat Hakimiyet")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6).opacity(0.5))
                        }
                    }
                    .frame(width: 320)
                    .background(
                        ZStack {
                            // Base background
                            Color(.systemBackground)
                            
                            // Subtle gradient overlay
                            LinearGradient(
                                colors: [
                                    Color(.systemBackground),
                                    Color(.systemGray6).opacity(0.2)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 30, x: 5, y: 0)
                    
                    Spacer()
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowing)
    }
    
    private func handleMenuSelection(_ item: MenuItem, tab: Int) {
        selectedMenu = item
        selectedTab = tab
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isShowing = false
        }
    }
}

// MARK: - Menu Section
struct MenuSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)
            
            content
        }
    }
}

// MARK: - Menu Row
struct MenuRow: View {
    let item: MenuItem
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            action()
        }) {
            HStack(spacing: 16) {
                // Icon with animated background
                ZStack {
                    // Background circle
                    Circle()
                        .fill(
                            isSelected
                            ? Color.blue.opacity(0.15)
                            : Color(.systemGray5)
                        )
                        .frame(width: 44, height: 44)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                    
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(
                            isSelected
                            ? .blue
                            : Color(.systemGray)
                        )
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                
                // Text
                Text(item.rawValue)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 12)
                    }
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Menu Item Enum
enum MenuItem: String, CaseIterable {
    case home = "Ana Sayfa"
    case breaking = "Son Dakika"
    case headlines = "Manşetler"
    case galleries = "Foto Galeri"
    case videos = "Videolar"
    case search = "Ara"
    case standings = "Puan Durumu"
    case categories = "Kategoriler"
    case authors = "Yazarlar"
    case settings = "Ayarlar"
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .breaking: return "bolt.fill"
        case .headlines: return "newspaper.fill"
        case .galleries: return "photo.on.rectangle"
        case .videos: return "play.rectangle.fill"
        case .search: return "magnifyingglass"
        case .standings: return "sportscourt.fill"
        case .categories: return "square.grid.2x2"
        case .authors: return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
