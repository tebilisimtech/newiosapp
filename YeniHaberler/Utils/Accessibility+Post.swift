import Foundation

extension Post {
    /// VoiceOver tek-okunuş etiketi: "Kategori: Başlık. Yazar. Tarih."
    var accessibilityLabel: String {
        var parts: [String] = []
        if let category = categories.values.first {
            parts.append("\(category):")
        }
        parts.append(name)
        if let author = author?.name, !author.isEmpty {
            parts.append(author)
        }
        if !createdAt.isEmpty {
            parts.append(String(createdAt.prefix(10)))
        }
        return parts.joined(separator: " ")
    }
}
