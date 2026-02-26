import SwiftUI

/// Shows daily streak, characters mastered, and grade-level progress.
struct StatsView: View {
    let sessionManager: SessionManager
    let characterData: CharacterDataService

    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    if let profile = sessionManager.fetchProfile() {
                        HStack(spacing: 12) {
                            Image(systemName: "flame.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading) {
                                Text("\(profile.currentStreak) day streak")
                                    .font(.headline)
                                if profile.longestStreak > profile.currentStreak {
                                    Text("Best: \(profile.longestStreak) days")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text("\(sessionManager.masteredCount()) characters mastered")
                                    .font(.headline)
                                Text("\(profile.totalReviews) total reviews")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Grade Progress") {
                    ForEach(characterData.gradeLevels, id: \.self) { grade in
                        GradeProgressRow(
                            grade: grade,
                            total: characterData.totalCharacters(forGrade: grade),
                            introduced: sessionManager.totalIntroduced(forGrade: grade),
                            mastered: sessionManager.masteredCount(forGrade: grade)
                        )
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
}
