import SwiftUI

/// Searchable character browser. Users can search by character, pinyin, or meaning,
/// filter by grade, and see review status (new / learning / mastered) for each character.
struct CharacterBrowseView: View {
    let sessionManager: SessionManager
    let characterData: CharacterDataService

    @State private var searchText = ""
    @State private var selectedGrade: Int = 0 // 0 = all grades

    var body: some View {
        let _ = sessionManager.statsRevision
        NavigationStack {
            let cards = sessionManager.allCardsByCharacter()
            let filtered = filteredCharacters
            let useTraditional = sessionManager.fetchProfile()?.useTraditional ?? false

            List {
                if filtered.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(groupedByGrade(filtered), id: \.grade) { group in
                        Section(CharacterEntry.gradeName(for: group.grade)) {
                            ForEach(group.characters) { entry in
                                CharacterRow(
                                    entry: entry,
                                    card: cards[entry.simplified],
                                    useTraditional: useTraditional
                                )
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Pinyin, meaning, or character")
            .navigationTitle("Characters")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Grade", selection: $selectedGrade) {
                            Text("All Grades").tag(0)
                            ForEach(characterData.gradeLevels, id: \.self) { grade in
                                Text(CharacterEntry.gradeName(for: grade)).tag(grade)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: selectedGrade == 0 ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
        }
    }

    private var filteredCharacters: [CharacterEntry] {
        var results = characterData.characters

        // Grade filter
        if selectedGrade > 0 {
            results = characterData.characters(forGrade: selectedGrade)
        }

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter { entry in
                entry.simplified.contains(query)
                || entry.traditional.contains(query)
                || entry.pinyin.lowercased().contains(query)
                || entry.meaning.lowercased().contains(query)
            }
        }

        return results
    }

    private struct GradeGroup {
        let grade: Int
        let characters: [CharacterEntry]
    }

    private func groupedByGrade(_ chars: [CharacterEntry]) -> [GradeGroup] {
        let grouped = Dictionary(grouping: chars, by: \.gradeLevel)
        return grouped.keys.sorted().map { grade in
            GradeGroup(grade: grade, characters: grouped[grade]!.sorted { $0.orderInGrade < $1.orderInGrade })
        }
    }
}

// MARK: - Character Row

private struct CharacterRow: View {
    let entry: CharacterEntry
    let card: ReviewCard?
    let useTraditional: Bool

    private var statusText: String {
        if let card {
            if card.isMastered { return "Mastered" }
            if card.state != .new { return "Learning" }
            return "Seen"
        }
        return "New"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.displayCharacter(traditional: useTraditional))
                .font(.custom("STKaiti", size: 32))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.pinyin)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(entry.meaning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            statusBadge
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.displayCharacter(traditional: useTraditional)), \(entry.pinyin), \(entry.meaning), \(statusText)")
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let card {
            if card.isMastered {
                Label("Mastered", systemImage: "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else if card.state != .new {
                Label("Learning", systemImage: "book.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            } else {
                Label("Seen", systemImage: "eye.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("New")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }
}
