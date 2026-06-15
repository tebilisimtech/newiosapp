import SwiftUI
import os
import UIKit

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Boş string'leri filtrele ("Yozgat Hakimiyet" gibi geçerli içerikleri koru)
        let validItems = items.filter { item in
            if let string = item as? String { return !string.isEmpty }
            if let url = item as? URL { return !url.absoluteString.isEmpty }
            return true
        }

        // Hiç geçerli item yoksa placeholder ile fallback
        guard !validItems.isEmpty else {
            AppLogger.ui.error("ShareSheet — no valid items, using placeholder")
            let appName = Config.shared.siteName.isEmpty ? "Haber" : Config.shared.siteName
            return UIActivityViewController(
                activityItems: [appName],
                applicationActivities: nil
            )
        }

        let controller = UIActivityViewController(
            activityItems: validItems,
            applicationActivities: nil
        )

        // iPad popover desteği
        if let popover = controller.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2,
                                            y: UIScreen.main.bounds.height / 2,
                                            width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }

        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                isPresented = false
            }
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Share Helper
struct ShareHelper {

    /// Haber paylaşma — iOS native share sheet'i doğrudan açar.
    static func sharePost(
        title: String,
        url: String,
        imageUrl: String?,
        onViewController: UIViewController? = nil,
        completion: @escaping ([Any]) -> Void
    ) {
        // URL'yi tam URL'ye çevir (relative ise base URL ile birleştir)
        let fullURL: String
        if url.hasPrefix("http://") || url.hasPrefix("https://") {
            fullURL = url
        } else {
            let baseURL = Config.shared.baseURL
            fullURL = url.hasPrefix("/") ? "\(baseURL)\(url)" : "\(baseURL)/\(url)"
        }

        // Görseli indir + paylaşıma ekle (varsa)
        if let imageUrl = imageUrl, !imageUrl.isEmpty, let imageURL = URL(string: imageUrl) {
            downloadImage(from: imageURL) { image in
                var itemsToShare: [Any] = []
                if let image = image {
                    itemsToShare.append(image)
                }

                // Başlık metin olarak; URL ayrı `URL` item'ı. (İkisine de URL koyarsak
                // paylaşımda link İKİ KEZ görünür — "çift URL" sorunu.)
                itemsToShare.append(title)
                if let shareURL = URL(string: fullURL) {
                    itemsToShare.append(shareURL)
                }

                DispatchQueue.main.async {
                    presentShareSheet(items: itemsToShare, onViewController: onViewController)
                }
                completion(itemsToShare)
            }
        } else {
            // Görsel yoksa: başlık (metin) + URL (ayrı item). URL'i metne KOYMA → çift URL olur.
            var itemsToShare: [Any] = []
            itemsToShare.append(title)
            if let shareURL = URL(string: fullURL) {
                itemsToShare.append(shareURL)
            }

            DispatchQueue.main.async {
                presentShareSheet(items: itemsToShare, onViewController: onViewController)
            }
            completion(itemsToShare)
        }
    }

    /// Paylaşım sheet'ini doğrudan present eder.
    private static func presentShareSheet(items: [Any], onViewController: UIViewController?) {
        guard !items.isEmpty else {
            AppLogger.ui.error("ShareHelper — cannot present: empty items")
            return
        }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // iPad popover
        if let popover = controller.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2,
                                            y: UIScreen.main.bounds.height / 2,
                                            width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }

        if let viewController = onViewController {
            viewController.present(controller, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController {
            var topViewController = rootViewController
            while let presented = topViewController.presentedViewController {
                topViewController = presented
            }
            topViewController.present(controller, animated: true)
        }
    }

    /// Galeri paylaşma — sharePost ile aynı yol.
    static func shareGallery(title: String, url: String, imageUrl: String?, completion: @escaping ([Any]) -> Void) {
        sharePost(title: title, url: url, imageUrl: imageUrl, completion: completion)
    }

    /// Görsel indir.
    private static func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let image = data.flatMap { UIImage(data: $0) }
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }
}
