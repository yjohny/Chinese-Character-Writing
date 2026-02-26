import Foundation

/// Loads and provides access to bundled character and stroke data.
/// All data is loaded once at init and cached in memory.
@MainActor
final class CharacterDataService: ObservableObject {
    private(set) var characters: [CharacterEntry] = []
    private var strokeDataMap: StrokeDataMap = [:]
    private var characterIndex: [String: CharacterEntry] = [:]      // keyed by simplified
    private var traditionalIndex: [String: CharacterEntry] = [:]    // keyed by traditional

    init() {
        loadCharacters()
        loadStrokes()
    }

    // MARK: - Queries

    /// All characters for a given grade level, ordered by orderInGrade.
    func characters(forGrade grade: Int) -> [CharacterEntry] {
        characters
            .filter { $0.gradeLevel == grade }
            .sorted { $0.orderInGrade < $1.orderInGrade }
    }

    /// Total character count for a grade.
    func totalCharacters(forGrade grade: Int) -> Int {
        characters.count(where: { $0.gradeLevel == grade })
    }

    /// Look up a character by its simplified form.
    func character(forSimplified char: String) -> CharacterEntry? {
        characterIndex[char]
    }

    /// Look up a character by its traditional form.
    func character(forTraditional char: String) -> CharacterEntry? {
        traditionalIndex[char]
    }

    /// Look up a character by either simplified or traditional.
    func character(for char: String, traditional: Bool) -> CharacterEntry? {
        traditional ? character(forTraditional: char) : character(forSimplified: char)
    }

    /// Get stroke order data for a character (by simplified form).
    func strokeData(for character: String) -> StrokeData? {
        strokeDataMap[character]
    }

    /// All available grade levels, sorted.
    var gradeLevels: [Int] {
        Array(Set(characters.map(\.gradeLevel))).sorted()
    }

    // MARK: - Loading

    private func loadCharacters() {
        guard let url = Bundle.main.url(forResource: "characters", withExtension: "json") else {
            print("⚠️ characters.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            characters = try JSONDecoder().decode([CharacterEntry].self, from: data)
            buildIndices()
        } catch {
            print("⚠️ Failed to decode characters.json: \(error)")
        }
    }

    private func loadStrokes() {
        guard let url = Bundle.main.url(forResource: "strokes", withExtension: "json") else {
            print("⚠️ strokes.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            strokeDataMap = try JSONDecoder().decode(StrokeDataMap.self, from: data)
        } catch {
            print("⚠️ Failed to decode strokes.json: \(error)")
        }
    }

    private func buildIndices() {
        characterIndex = Dictionary(uniqueKeysWithValues: characters.map { ($0.simplified, $0) })
        // Traditional index: some traditional forms may collide, use first occurrence
        for entry in characters {
            if traditionalIndex[entry.traditional] == nil {
                traditionalIndex[entry.traditional] = entry
            }
        }
    }
}
