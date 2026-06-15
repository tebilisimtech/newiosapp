import Foundation

/// Liste ekranlarında sayfalama (page-based) durumunu izleyen değer tipi.
/// ViewModel'ler bu struct'ı `@Published` bir property olarak tutar ve
/// `loadMore()` döngülerini buradan kontrol eder.
struct PaginationState: Equatable {
    /// Bir sonraki çağrılacak sayfa numarası. İlk yükleme `1`.
    var currentPage: Int = 1

    /// Sunucuda daha fazla içerik olabileceği bilgisi.
    /// `didLoadPage` sayfa beklenenden az ürün döndüğünde `false`'a çekilir.
    var hasMore: Bool = true

    /// Şu an arka planda yeni bir sayfa yükleniyor mu? UI bunu spinner için kullanır.
    var isLoadingMore: Bool = false

    /// İlk sayfaya dön; pull-to-refresh ve filtre değişikliğinde çağrılır.
    mutating func reset() {
        currentPage = 1
        hasMore = true
        isLoadingMore = false
    }

    /// Bir sayfa yüklendikten sonra durumu güncelle.
    /// - Parameters:
    ///   - itemsReceived: Bu sayfada API'den gelen item sayısı.
    ///   - expected: Talep edilen perPage. Sunucular bazen `per_page` parametresini
    ///     görmezden gelip kendi default sayfa boyutuyla cevap verir — bu yüzden
    ///     "bitti" kararı `itemsReceived == 0` üzerine veriliyor. `expected` bilgi
    ///     amaçlı, sıkı eşik değil.
    mutating func didLoadPage(itemsReceived: Int, expected: Int) {
        isLoadingMore = false
        if itemsReceived == 0 {
            hasMore = false
            return
        }
        currentPage += 1
    }

    /// Yeni sayfa yüklemesi başladığını işaretler.
    mutating func willLoadMore() {
        isLoadingMore = true
    }

    /// Hata sonrası — yükleme bayrağını kapat, currentPage'i artırma.
    mutating func didFail() {
        isLoadingMore = false
    }
}
