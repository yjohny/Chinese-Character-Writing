import Foundation

/// A single character from the bundled JSON database. Not persisted — loaded at runtime.
struct CharacterEntry: Codable, Identifiable {
    var id: String { simplified }

    let simplified: String          // "游"
    let traditional: String         // "遊"
    let pinyin: String              // "yóu"
    let meaning: String             // "swim; travel"
    let gradeLevel: Int             // 1-6 for school grades
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
}
