import Foundation

/// Backend PHP class FQCN'leri ile native UI alias'ları arasındaki köprü.
///
/// Sunucudaki Comments API'si yorumları DB'ye `reference_type` kolonuyla
/// kaydediyor ve panel tarafında Eloquent `morphTo()` ilişkisiyle çözüyor.
/// `morphTo()` kolondaki değeri **PHP class adı (FQCN)** olarak yorumladığı
/// için API'ye `"gallery"` gibi kısa alias gönderirsek panel `\gallery not found`
/// hatası alır. Bu yüzden API'ye giden tüm `reference_type` değerleri FQCN
/// olmak zorundadır.
///
/// App içinde UI/navigation için kısa alias kullanmaya devam ediyoruz
/// (switch case'ler, deep link parse, kategori chip'leri vs.); bu enum iki
/// dünya arasındaki çeviriyi tek noktada yapar.
enum ReferenceType: String, CaseIterable {
    case post
    case gallery
    case video
    case article
    case biography
    case interview

    /// API isteklerinde `reference_type` parametresinde gönderilmesi gereken FQCN.
    /// `\\` Swift kaynağında tek `\` karakterine karşılık gelir; JSON/URL
    /// encoding sonrası PHP tarafında doğru class adı olarak çözülür.
    var apiValue: String {
        switch self {
        case .post:      return "TE\\Blog\\Models\\Post"
        case .gallery:   return "TE\\Gallery\\Models\\Gallery"
        case .video:     return "TE\\Video\\Models\\Video"
        case .article:   return "TE\\Authors\\Models\\Article"
        case .biography: return "TE\\Biography\\Models\\Biography"
        case .interview: return "TE\\Interview\\Models\\Interview"
        }
    }

    /// Sunucudan gelen bir değeri (FQCN veya alias) enum'a çözer.
    /// CommentResource yıllar içinde her iki formu da döndürmüş olabilir; bu
    /// metod ikisini de tolere ederek UI tarafına temiz bir tip verir.
    static func resolve(_ value: String) -> ReferenceType? {
        for type in allCases where type.apiValue == value {
            return type
        }
        return ReferenceType(rawValue: value.lowercased())
    }
}
