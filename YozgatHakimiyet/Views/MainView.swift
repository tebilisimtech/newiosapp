import SwiftUI

struct MainView: View {
    @State private var showSideMenu = false
    @State private var selectedTab = 0
    @State private var showSplash = true
    @StateObject private var navigationManager = NavigationManager.shared
    
    var body: some View {
        ZStack {
            if !showSplash {
                BottomTabView(showSideMenu: $showSideMenu, selectedTab: $selectedTab)
                
                // Side Menu Overlay
                SideMenuView(isShowing: $showSideMenu, selectedTab: $selectedTab)
            } else {
                // Splash Screen
                SplashScreenView(
                    isPresented: $showSplash,
                    minimumDisplayTime: 2.5
                )
            }
        }
        .sheet(item: $navigationManager.destination) { destination in
            NavigationView {
                destinationView(for: destination)
            }
        }
        .onAppear {
            // AppSettings'i yükle (logo için)
            Task {
                await AppSettings.shared.loadSettings()
            }
        }
        .onChange(of: navigationManager.shouldNavigate) { shouldNavigate in
            if shouldNavigate {
                // Navigation tetiklendi, sheet zaten açılacak
                print("✅ MainView - Navigation triggered")
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .post(let postId):
            PostDetailView(postId: postId)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Kapat") {
                            navigationManager.clearNavigation()
                        }
                    }
                }
        case .video(let videoId):
            VideoDetailView(videoId: videoId)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Kapat") {
                            navigationManager.clearNavigation()
                        }
                    }
                }
        case .gallery(let galleryId):
            GalleryDetailView(galleryId: galleryId)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Kapat") {
                            navigationManager.clearNavigation()
                        }
                    }
                }
        }
    }
}

