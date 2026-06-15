import SwiftUI
import os

struct MainView: View {
    @State private var showSideMenu = false
    @State private var selectedTab = 0
    @State private var showSplash = true
    @StateObject private var navigationManager = NavigationManager.shared
    @StateObject private var userPrefs = UserPreferences.shared
    @StateObject private var userInterests = UserInterests.shared
    @StateObject private var remoteTheme = RemoteTheme.shared
    @StateObject private var advertManager = AdvertManager.shared

    var body: some View {
        ZStack {
            // Kalıcı siyah taban — splash kaybolurken/geçişlerde beyaz pencere
            // arka planının görünmesini engeller.
            Color.black.ignoresSafeArea()

            if showSplash {
                // Splash Screen
                SplashScreenView(
                    isPresented: $showSplash,
                    minimumDisplayTime: 2.5
                )
            } else if !userPrefs.hasCompletedOnboarding {
                // İlk açılış — Onboarding akışı
                OnboardingView(onFinished: {})
                    .transition(.opacity)
            } else if !userInterests.hasPrompted {
                // Onboarding sonrası — ilgi alanı seçimi (bir kez; Atla mümkün)
                InterestsView(onboarding: true)
                    .transition(.opacity)
            } else {
                // Panel'den yeni tema (renk/font) geldiğinde ana ağacı yeniden çiz.
                Group {
                    BottomTabView(showSideMenu: $showSideMenu, selectedTab: $selectedTab)

                    // Side Menu Overlay
                    SideMenuView(isShowing: $showSideMenu, selectedTab: $selectedTab)
                }
                .id(remoteTheme.version)
            }
        }
        .animation(Theme.Animations.smooth, value: userPrefs.hasCompletedOnboarding)
        .animation(Theme.Animations.smooth, value: userInterests.hasPrompted)
        .preferredColorScheme(userPrefs.themeMode.colorScheme)
        .tint(Theme.Brand.primary)
        .sheet(item: $navigationManager.destination) { destination in
            NavigationView {
                destinationView(for: destination)
            }
            .navigationViewStyle(.stack)
        }
        // Splash sonrası özel interstitial (#2025)
        .fullScreenCover(item: $advertManager.pendingInterstitial) { advert in
            AdvertInterstitialView(advert: advert) {
                advertManager.pendingInterstitial = nil
            }
        }
        .onAppear {
            // AppSettings'i yükle (logo için)
            Task {
                await AppSettings.shared.loadSettings()
            }
            // Bildirim kategorilerini yükle → OneSignal etiketlerini yaz.
            Task {
                await NotificationCategoryStore.shared.loadCategories()
            }
        }
        .onChange(of: navigationManager.shouldNavigate) { shouldNavigate in
            if shouldNavigate {
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
        case .author(let authorId):
            AuthorDetailView(authorId: authorId, showSideMenu: .constant(false))
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

