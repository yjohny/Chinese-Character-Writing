import Foundation
import SwiftData

/// Singleton model for user preferences and streak data. Singleton-ness is
/// enforced at the database layer via `@Attribute(.unique)` on `key`.
@Model
final class UserProfile {
    /// The single stable key value used for the singleton profile row.
    static let singletonKey = "default"

    /// Stable singleton key. The unique constraint guarantees at most one
    /// UserProfile row exists. All instances default to `singletonKey`.
    @Attribute(.unique) var key: String = UserProfile.singletonKey

    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastPracticeDate: Date?
    var useTraditional: Bool = false
    var totalReviews: Int = 0
    var createdDate: Date = Date()

    /// Grade level to start introducing new characters from (1-7, where 7 is "Expansion").
    /// Characters below this grade are created as assumed-known with staggered review dates.
    var startingGrade: Int = 1

    /// Daily practice goal (number of reviews per day).
    var dailyGoal: Int = 10

    /// Number of reviews completed today. Reset when the calendar day changes.
    var reviewsToday: Int = 0

    /// Tracks which day `reviewsToday` belongs to, separate from streak tracking.
    var lastReviewCountDate: Date?

    /// Raw values of achieved milestone types. SwiftData stores `[String]`
    /// natively, so no string-encoding workaround is needed.
    var achievedMilestones: [String] = []

    /// Whether sound effects are enabled.
    var soundEffectsEnabled: Bool = true

    /// Stroke animation speed multiplier: 0 = slow (1.5×), 1 = normal (1×), 2 = fast (0.5×).
    var animationSpeed: Int = 1

    /// Session length (number of characters per session). 0 = unlimited (manual "Done").
    var sessionLength: Int = 0

    /// Whether the user has completed the first-run onboarding flow.
    var hasCompletedOnboarding: Bool = false

    init() {}

    // MARK: - Daily Goal

    /// Increment today's review counter, resetting if the calendar day changed.
    func incrementReviewsToday(now: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        if let last = lastReviewCountDate,
           calendar.startOfDay(for: last) == today {
            reviewsToday += 1
        } else {
            reviewsToday = 1
        }
        lastReviewCountDate = now
    }

    // MARK: - Milestones

    func hasAchieved(_ milestone: MilestoneType) -> Bool {
        achievedMilestones.contains(milestone.rawValue)
    }

    func markAchieved(_ milestone: MilestoneType) {
        if !achievedMilestones.contains(milestone.rawValue) {
            achievedMilestones.append(milestone.rawValue)
        }
    }

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
