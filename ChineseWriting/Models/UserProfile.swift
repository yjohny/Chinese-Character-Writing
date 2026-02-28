import Foundation
import SwiftData

/// Singleton-like model for user preferences and streak data.
@Model
final class UserProfile {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastPracticeDate: Date?
    var useTraditional: Bool = false
    var totalReviews: Int = 0
    var createdDate: Date = Date()

    /// Grade level to start introducing new characters from (1-6).
    /// Characters below this grade are created as assumed-known with staggered review dates.
    var startingGrade: Int = 1

    /// Whether the user has completed the first-launch onboarding (grade picker).
    var hasCompletedOnboarding: Bool = false

    init() {}

    /// Update streak based on practice today. Call once per session start.
    func updateStreak(now: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        if let lastDate = lastPracticeDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysBetween == 0 {
                // Already practiced today, no change
                return
            } else if daysBetween == 1 {
                // Consecutive day
                currentStreak += 1
            } else {
                // Streak broken
                currentStreak = 1
            }
        } else {
            // First ever practice
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        lastPracticeDate = now
    }
}
