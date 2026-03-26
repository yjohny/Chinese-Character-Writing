import Foundation
import os.log

private let logger = Logger(subsystem: "com.chinesewriting.app", category: "CharacterData")

/// Loads and provides access to bundled character and stroke data.
/// Character data is loaded at init; stroke data is lazily decoded per character
/// to avoid holding the entire strokes.json (~7MB) in memory as decoded objects.
@MainActor
final class CharacterDataService: ObservableObject {
    private(set) var characters: [CharacterEntry] = []
    private var characterIndex: [String: CharacterEntry] = [:]      // keyed by simplified
    private var traditionalIndex: [String: CharacterEntry] = [:]    // keyed by traditional
    /// Pre-computed characters grouped by grade, sorted by orderInGrade.
    private var charactersByGrade: [Int: [CharacterEntry]] = [:]
    /// Pre-computed sorted grade levels.
    private var sortedGradeLevels: [Int] = []
    /// Pre-computed tone-stripped pinyin for each character (keyed by simplified).
    /// Allows search by ASCII pinyin without tone marks (e.g. "you" matches "yóu").
    private(set) var pinyinNormalized: [String: String] = [:]

    /// Raw JSON objects keyed by character — decoded lazily into StrokeData on demand.
    private var rawStrokeEntries: [String: Any] = [:]
    /// Cache of already-decoded StrokeData to avoid re-decoding.
    private var strokeDataCache: [String: StrokeData] = [:]

    init() {
        loadCharacters()
        startStrokeLoading()
    }

    // MARK: - Queries

    /// All characters for a given grade level, ordered by orderInGrade.
    func characters(forGrade grade: Int) -> [CharacterEntry] {
        charactersByGrade[grade] ?? []
    }

    /// Total character count for a grade.
    func totalCharacters(forGrade grade: Int) -> Int {
        charactersByGrade[grade]?.count ?? 0
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
    /// Lazily decodes from the raw JSON on first access, then caches.
    func strokeData(for character: String) -> StrokeData? {
        if let cached = strokeDataCache[character] {
            return cached
        }
        guard let rawEntry = rawStrokeEntries[character] else { return nil }
        do {
            let entryData = try JSONSerialization.data(withJSONObject: rawEntry)
            let strokeData = try JSONDecoder().decode(StrokeData.self, from: entryData)
            strokeDataCache[character] = strokeData
            rawStrokeEntries.removeValue(forKey: character) // Free raw JSON now that decoded copy is cached
            return strokeData
        } catch {
            logger.error("Failed to decode stroke data for \(character): \(error)")
            return nil
        }
    }

    /// All available grade levels, sorted.
    var gradeLevels: [Int] {
        sortedGradeLevels
    }

    // MARK: - Loading

    private func loadCharacters() {
        guard let url = Bundle.main.url(forResource: "characters", withExtension: "json") else {
            logger.error("characters.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            characters = try JSONDecoder().decode([CharacterEntry].self, from: data)
            buildIndices()
        } catch {
            logger.error("Failed to decode characters.json: \(error)")
        }
    }

    /// Reads strokes.json from the bundle and parses it on a background thread.
    /// File read is synchronous (fast for ~8MB); JSON parsing runs detached so it
    /// doesn't block the main thread during launch. If `strokeData(for:)` is called
    /// before parsing finishes, it returns nil (recognition falls through to Vision OCR).
    private func startStrokeLoading() {
        guard let url = Bundle.main.url(forResource: "strokes", withExtension: "json") else {
            logger.error("strokes.json not found in bundle")
            return
        }
        guard let data = try? Data(contentsOf: url) else {
            logger.error("Failed to read strokes.json")
            return
        }
        Task.detached { [weak self] in
            guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                await MainActor.run { logger.error("strokes.json is not a dictionary") }
                return
            }
            await MainActor.run {
                self?.rawStrokeEntries = dict
            }
        }
    }

    private func buildIndices() {
        // Use uniquingKeysWith to avoid crashing on duplicate simplified entries in data
        characterIndex = Dictionary(characters.map { ($0.simplified, $0) }, uniquingKeysWith: { first, _ in first })
        // Traditional index: some traditional forms may collide, use first occurrence
        for entry in characters {
            if traditionalIndex[entry.traditional] == nil {
                traditionalIndex[entry.traditional] = entry
            }
        }
        // Pre-compute grade groupings (avoids repeated filter+sort on every call)
        charactersByGrade = Dictionary(grouping: characters, by: \.gradeLevel)
            .mapValues { $0.sorted { $0.orderInGrade < $1.orderInGrade } }
        sortedGradeLevels = charactersByGrade.keys.sorted()
        // Pre-compute tone-stripped pinyin for fast ASCII search
        pinyinNormalized = Dictionary(
            characters.map { ($0.simplified, CharacterEntry.stripTones($0.pinyin)) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
