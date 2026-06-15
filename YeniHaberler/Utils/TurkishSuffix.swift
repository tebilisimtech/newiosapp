import Foundation

/// Özel isimlere Türkçe ek getirir — apostrof + ünlü uyumu + kaynaştırma harfi.
///
/// White-label haber sitelerinde city/site adı değişkendir (Yozgat, Amasya,
/// İstanbul…). Sabit "'ın" eki yazmak yanlış sonuç verir (Amasya'ın → ✗).
/// Bu helper son hece ünlüsüne göre doğru eki seçer ve gerekirse kaynaştırma
/// ünsüzü ekler.
///
/// Kurallar:
/// - **Büyük ünlü uyumu**: a/ı → ı, o/u → u, e/i → i, ö/ü → ü
/// - **Kaynaştırma**: kelime sesli ile biterse iyelik öncesi 'n', yönelme/yükleme
///   öncesi 'y' eklenir.
enum TurkishSuffix {

    /// İyelik eki (3. tekil) — "Yozgat'ın", "Amasya'nın", "Ordu'nun".
    static func possessive(_ word: String) -> String {
        guard let last = lastVowel(in: word) else { return word + "'ı" }
        let buffer = endsWithVowel(word) ? "n" : ""
        return "\(word)'\(buffer)\(highVowel(matching: last))n"
    }

    /// Yükleme (belirtme) hâli eki — "Yozgat'ı", "Amasya'yı", "Ordu'yu".
    static func accusative(_ word: String) -> String {
        guard let last = lastVowel(in: word) else { return word + "'ı" }
        let buffer = endsWithVowel(word) ? "y" : ""
        return "\(word)'\(buffer)\(highVowel(matching: last))"
    }

    /// Yönelme hâli eki — "Yozgat'a", "Amasya'ya", "İzmir'e", "Antalya'ya".
    static func dative(_ word: String) -> String {
        guard let last = lastVowel(in: word) else { return word + "'a" }
        let buffer = endsWithVowel(word) ? "y" : ""
        return "\(word)'\(buffer)\(lowVowel(matching: last))"
    }

    // MARK: - Private

    private static let backUnrounded: Set<Character>  = ["a", "ı", "A", "I"]
    private static let backRounded:   Set<Character>  = ["o", "u", "O", "U"]
    private static let frontUnrounded: Set<Character> = ["e", "i", "E", "İ"]
    private static let frontRounded:   Set<Character> = ["ö", "ü", "Ö", "Ü"]

    private static var allVowels: Set<Character> {
        backUnrounded.union(backRounded).union(frontUnrounded).union(frontRounded)
    }

    private static func lastVowel(in word: String) -> Character? {
        word.reversed().first { allVowels.contains($0) }
    }

    private static func endsWithVowel(_ word: String) -> Bool {
        guard let last = word.last else { return false }
        return allVowels.contains(last)
    }

    /// Dar ünlü (ı/i/u/ü) — iyelik ve yükleme için.
    private static func highVowel(matching vowel: Character) -> String {
        if backUnrounded.contains(vowel) { return "ı" }
        if backRounded.contains(vowel)   { return "u" }
        if frontRounded.contains(vowel)  { return "ü" }
        return "i"   // frontUnrounded
    }

    /// Geniş ünlü (a/e) — yönelme için.
    private static func lowVowel(matching vowel: Character) -> String {
        if backUnrounded.contains(vowel) || backRounded.contains(vowel) { return "a" }
        return "e"
    }
}
