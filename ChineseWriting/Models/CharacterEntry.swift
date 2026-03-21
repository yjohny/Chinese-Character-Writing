import Foundation

/// A single character from the bundled JSON database. Not persisted — loaded at runtime.
struct CharacterEntry: Codable, Identifiable {
    var id: String { simplified }

    let simplified: String          // "游"
    let traditional: String         // "遊"
    let pinyin: String              // "yóu"
    let meaning: String             // "swim; travel"
    let gradeLevel: Int             // 1-6 for school grades, 7 for expansion (识字表-only)
    let orderInGrade: Int           // position within grade list (0-indexed)
    let exampleWords: [ExampleWord]

    struct ExampleWord: Codable {
        let word: String            // "旅游"
        let wordTraditional: String // "旅遊"
        let pinyin: String          // "lǚyóu"
        let meaning: String         // "travel"
        let ttsText: String         // "游，旅游的游"
    }

    /// Returns the display character based on the active character set.
    func displayCharacter(traditional: Bool) -> String {
        traditional ? self.traditional : simplified
    }

    /// Returns the primary TTS text for this character.
    var primaryTTSText: String {
        exampleWords.first?.ttsText ?? simplified
    }

    /// Display name for a grade level. Grades 1-6 map to "Grade N";
    /// grade 7 is the expansion tier (识字表 recognition-only characters).
    static func gradeName(for grade: Int) -> String {
        grade <= 6 ? "Grade \(grade)" : "Expansion"
    }

    /// Strip tone diacritics from pinyin, converting to ASCII-searchable form.
    /// E.g. "yóu" → "you", "lǚ" → "lv" (ü → v is standard keyboard input).
    /// Handles all standard pinyin vowels with tone marks and ü → v.
    static func stripTones(_ pinyin: String) -> String {
        let toneMap: [Character: Character] = [
            "ā": "a", "á": "a", "ǎ": "a", "à": "a",
            "ē": "e", "é": "e", "ě": "e", "è": "e",
            "ī": "i", "í": "i", "ǐ": "i", "ì": "i",
            "ō": "o", "ó": "o", "ǒ": "o", "ò": "o",
            "ū": "u", "ú": "u", "ǔ": "u", "ù": "u",
            "ǖ": "v", "ǘ": "v", "ǚ": "v", "ǜ": "v", "ü": "v",
        ]
        return String(pinyin.lowercased().map { toneMap[$0] ?? $0 })
    }
}
