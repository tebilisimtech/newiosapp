import SwiftUI
import WebKit
import AVKit
import SafariServices

// MARK: - VideoSource
//
// Haber API'sinden gelen `embed` (iframe HTML) veya `url` (site adresi) alanlarını
// analiz edip oynatma platformunu belirler. Her platform için inline (sayfa içi)
// oynatıcı kullanılır — kullanıcı browser/Safari'ye atılmaz.
enum VideoSource: Equatable {
    case youtube(id: String)
    case dailymotion(id: String)
    case vimeo(id: String)
    case directURL(URL)
    case unknown

    /// Önce `media_url`'i (genelde direkt MP4/HLS), sonra `embed`'i (iframe),
    /// en son fallback olarak `url`'i (site sayfası) tarar.
    static func detect(embed: String?, url: String?, mediaUrl: String? = nil) -> VideoSource {
        if let mediaUrl = mediaUrl, !mediaUrl.isEmpty {
            let result = parse(text: mediaUrl)
            if result != .unknown { return result }
        }
        if let embed = embed, !embed.isEmpty {
            let result = parse(text: embed)
            if result != .unknown { return result }
        }
        if let url = url, !url.isEmpty {
            return parse(text: url)
        }
        return .unknown
    }

    private static func parse(text: String) -> VideoSource {
        // YouTube — embed, watch, kısa link
        let ytPatterns = [
            #"youtube\.com/embed/([a-zA-Z0-9_-]+)"#,
            #"youtube\.com/watch\?v=([a-zA-Z0-9_-]+)"#,
            #"youtu\.be/([a-zA-Z0-9_-]+)"#
        ]
        for p in ytPatterns {
            if let id = firstMatch(p, in: text) { return .youtube(id: id) }
        }

        // Dailymotion — embed, video/, geo player, kısa link
        let dmPatterns = [
            #"dailymotion\.com/embed/video/([a-zA-Z0-9]+)"#,
            #"dailymotion\.com/video/([a-zA-Z0-9]+)"#,
            #"geo\.dailymotion\.com/player\.html\?video=([a-zA-Z0-9]+)"#,
            #"dai\.ly/([a-zA-Z0-9]+)"#
        ]
        for p in dmPatterns {
            if let id = firstMatch(p, in: text) { return .dailymotion(id: id) }
        }

        // Vimeo — player, ana adres
        let vmPatterns = [
            #"player\.vimeo\.com/video/(\d+)"#,
            #"vimeo\.com/(\d+)"#
        ]
        for p in vmPatterns {
            if let id = firstMatch(p, in: text) { return .vimeo(id: id) }
        }

        // Direkt video dosyası — uzantı tabanlı
        if let url = URL(string: text) {
            let ext = url.pathExtension.lowercased()
            if ["mp4", "m4v", "mov", "webm", "m3u8"].contains(ext) {
                return .directURL(url)
            }
        }

        return .unknown
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
            .components(separatedBy: CharacterSet(charactersIn: "?&#\"'"))
            .first
    }
}

// MARK: - InlineVideoPlayer
//
// Tek tip player çatısı. Source enum'a göre uygun backend'e route eder.
// 16:9 oran tutmak çağrı tarafının sorumluluğunda (frame modifier ile).
struct InlineVideoPlayer: View {
    let source: VideoSource
    let posterURL: String?
    /// .unknown durumunda kullanıcı poster'a tıklarsa fallback için site URL'i.
    let fallbackURL: URL?
    /// Mount olur olmaz otomatik oynat (ör. Keşfet feed'inde aktif sayfa).
    var autoplay: Bool = false

    var body: some View {
        // baseURL = yayıncı sitesi (Config.shared.baseURL). iframe player'lar bunu
        // "parent origin" + Referer olarak görür — yayıncının Dailymotion/YouTube/Vimeo
        // partner anlaşması varsa o domain'e tanınan reklamsız / kısıtsız oynatma
        // kuralları devreye girer. Boşsa veya yanlışsa standart "third-party embed"
        // reklam politikası uygulanır.
        let publisherOrigin = URL(string: Config.shared.baseURL)

        switch source {
        case .youtube(let id):
            EmbeddedWebPlayer(html: HTMLBuilder.youtube(id: id, autoplay: autoplay), baseURL: publisherOrigin)
        case .dailymotion(let id):
            EmbeddedWebPlayer(html: HTMLBuilder.dailymotion(id: id, autoplay: autoplay), baseURL: publisherOrigin)
        case .vimeo(let id):
            EmbeddedWebPlayer(html: HTMLBuilder.vimeo(id: id, autoplay: autoplay), baseURL: publisherOrigin)
        case .directURL(let url):
            NativeVideoPlayer(url: url, autoplay: autoplay)
        case .unknown:
            UnsupportedVideoFallback(posterURL: posterURL, fallbackURL: fallbackURL)
        }
    }
}

// MARK: - HTML Builders
//
// Her platform için minimal HTML wrapper. iframe ekranı dolduracak şekilde
// absolutely positioned; viewport ve scroll devre dışı — etrafta browser
// chrome'u görünmez, sadece player UI'si kalır.
private enum HTMLBuilder {
    static func youtube(id: String, autoplay: Bool = false) -> String {
        var src = "https://www.youtube.com/embed/\(id)?playsinline=1&rel=0&modestbranding=1&fs=1"
        if autoplay { src += "&autoplay=1" }
        return wrap(iframeSrc: src)
    }

    static func dailymotion(id: String, autoplay: Bool = false) -> String {
        // queue/sharing/info kapatılmış — sadece play kontrolleri. Reklam politikası
        // yayıncı domain'ine bağlı (bkz: InlineVideoPlayer.body publisherOrigin).
        var params = [
            "video=\(id)",
            "queue-enable=false",
            "sharing-enable=false",
            "ui-start-screen-info=false",
            "ui-logo=false"
        ]
        if autoplay { params.append("autoplay=true") }
        let src = "https://geo.dailymotion.com/player.html?" + params.joined(separator: "&")
        return wrap(iframeSrc: src)
    }

    static func vimeo(id: String, autoplay: Bool = false) -> String {
        var src = "https://player.vimeo.com/video/\(id)?title=0&byline=0&portrait=0&playsinline=1"
        if autoplay { src += "&autoplay=1" }
        return wrap(iframeSrc: src)
    }

    private static func wrap(iframeSrc: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
            html, body { margin: 0; padding: 0; background: #000; width: 100%; height: 100%; overflow: hidden; }
            .container { position: absolute; top: 0; left: 0; right: 0; bottom: 0; }
            iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
        </style>
        </head>
        <body>
        <div class="container">
            <iframe src="\(iframeSrc)"
                    allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
                    allowfullscreen
                    frameborder="0"></iframe>
        </div>
        </body>
        </html>
        """
    }
}

// MARK: - EmbeddedWebPlayer (WKWebView)
//
// iframe player'ı render eder. Inline media playback ve user-gesture-less
// playback açık — sayfa açılınca play butonu doğrudan görünür.
private struct EmbeddedWebPlayer: UIViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}

// MARK: - NativeVideoPlayer (AVPlayer)
//
// Direkt MP4/HLS URL'leri için. PiP açık, sistem kontrolleri ile native UX.
private struct NativeVideoPlayer: UIViewControllerRepresentable {
    let url: URL
    var autoplay: Bool = false

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.videoGravity = .resizeAspect
        if autoplay { player.play() }
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
}

// MARK: - Unsupported Fallback
//
// Video kaynağı tanınmadığında: poster + play butonu, tıklayınca Safari sheet.
private struct UnsupportedVideoFallback: View {
    let posterURL: String?
    let fallbackURL: URL?

    @State private var showSafari = false

    var body: some View {
        Button(action: {
            if fallbackURL != nil { showSafari = true }
        }) {
            ZStack {
                Color.black
                if let posterURL = posterURL, !posterURL.isEmpty {
                    AspectImage(url: posterURL, aspectRatio: 16/9)
                        .opacity(0.75)
                }
                LinearGradient(
                    colors: [.black.opacity(0.2), .black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: fallbackURL != nil ? "play.fill" : "play.slash")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                        .padding(22)
                        .background(Circle().fill(Theme.Brand.primary))
                        .themedShadow(Theme.Shadow.large)

                    Text(fallbackURL != nil ? "Sitede İzle" : "Video Oynatılamıyor")
                        .scaledFont(size: 12, weight: .heavy)
                        .tracking(1.0)
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(fallbackURL == nil)
        .sheet(isPresented: $showSafari) {
            if let url = fallbackURL {
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }
}
