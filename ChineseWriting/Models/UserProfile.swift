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

    /// Grade level to start introducing new characters from (1-7, where 7 is "Expansion").
    /// Characters below this grade are created as assumed-known with staggered review dates.
    var startingGrade: Int = 1

    /// Daily practice goal (number of reviews per day).
    var dailyGoal: Int = 10

    /// Number of reviews completed today. Reset when the calendar day changes.
    var reviewsToday: Int = 0

    /// Tracks which day `reviewsToday` belongs to, separate from streak tracking.
    var lastReviewCountDate: Date?

    /// Comma-separated raw values of achieved milestone types. SwiftData doesn't support
    /// Set<String> directly, so we use a raw string and computed helpers.
    var achievedMilestonesRaw: String = ""

    /// Whether sound effects are enabled.
    var soundEffectsEnabled: Bool = true

    /// Stroke animation speed multiplier: 0 = slow (1.5×), 1 = normal (1×), 2 = fast (0.5×).
    var animationSpeed: Int = 1

    /// Session length (number of characters per session). 0 = unlimited (manual "Done").
    var sessionLength: Int = 0

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

    var achievedMilestones: Set<String> {
        get {
            guard !achievedMilestonesRaw.isEmpty else { return [] }
            return Set(achievedMilestonesRaw.split(separator: ",").map(String.init))
        }
        set { achievedMilestonesRaw = newValue.sorted().joined(separator: ",") }
    }

    func hasAchieved(_ milestone: MilestoneType) -> Bool {
        achievedMilestones.contains(milestone.rawValue)
    }

    func markAchieved(_ milestone: MilestoneType) {
        var set = achievedMilestones
        set.insert(milestone.rawValue)
        achievedMilestones = set
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
