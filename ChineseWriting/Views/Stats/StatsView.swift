import SwiftUI

/// Shows daily streak, characters mastered, and grade-level progress.
struct StatsView: View {
    let sessionManager: SessionManager
    let characterData: CharacterDataService

    var body: some View {
        // Touch statsRevision so @Observable re-renders this view after reviews.
        let _ = sessionManager.statsRevision
        NavigationStack {
            List {
                Section("Today") {
                    if let profile = sessionManager.fetchProfile() {
                        if profile.totalReviews == 0 {
                            VStack(spacing: 8) {
                                Text("No reviews yet")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("Complete your first practice session to start tracking progress.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "flame.fill")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                                    .accessibilityHidden(true)
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
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(profile.currentStreak) day streak\(profile.longestStreak > profile.currentStreak ? ", best: \(profile.longestStreak) days" : "")")

                            let progress = sessionManager.dailyProgress()
                            HStack(spacing: 12) {
                                Image(systemName: "target")
                                    .font(.title2)
                                    .foregroundStyle(progress.current >= progress.goal ? .green : .orange)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Today: \(progress.current)/\(progress.goal) reviews")
                                        .font(.headline)
                                    ProgressView(value: min(1.0, Double(progress.current) / Double(max(1, progress.goal))))
                                        .tint(progress.current >= progress.goal ? .green : .orange)
                                }
                            }
                            .padding(.vertical, 4)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Today: \(progress.current) of \(progress.goal) reviews\(progress.current >= progress.goal ? ", goal complete" : "")")

                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading) {
                                    Text("\(sessionManager.masteredCount()) characters mastered")
                                        .font(.headline)
                                    Text("\(profile.totalReviews) total reviews")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(sessionManager.masteredCount()) characters mastered, \(profile.totalReviews) total reviews")
                        }
                    }
                }

                Section("Review History") {
                    ReviewHeatmapView(reviewCounts: sessionManager.reviewCountsByDay())
                        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))

                    let forecast = sessionManager.reviewForecast()
                    if forecast.today > 0 || forecast.tomorrow > 0 {
                        HStack(spacing: 16) {
                            if forecast.today > 0 {
                                Label("\(forecast.today) due now", systemImage: "clock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            if forecast.tomorrow > 0 {
                                Label("\(forecast.tomorrow) tomorrow", systemImage: "sunrise.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Grade Progress") {
                    let gradeStats = sessionManager.allGradeStats()
                    ForEach(characterData.gradeLevels, id: \.self) { grade in
                        let stats = gradeStats[grade]
                        GradeProgressRow(
                            grade: grade,
                            total: characterData.totalCharacters(forGrade: grade),
                            introduced: stats?.introduced ?? 0,
                            learning: stats?.learning ?? 0,
                            mastered: stats?.mastered ?? 0
                        )
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
}
