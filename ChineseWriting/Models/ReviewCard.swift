import Foundation
import SwiftData

/// Persisted FSRS state for a single character. One ReviewCard per character.
@Model
final class ReviewCard {
    // Identity
    /// Unique constraint enforces one ReviewCard per character at the database
    /// layer, preventing duplicates from race conditions or future code paths.
    @Attribute(.unique) var character: String = ""
    var gradeLevel: Int = 1
    var orderInGrade: Int = 0

    // FSRS state
    var stability: Double = 0.0
    var difficulty: Double = 0.0
    var reps: Int = 0
    var lapses: Int = 0
    var stateRaw: Int = 0               // CardState.rawValue

    // Scheduling
    var dueDate: Date = Date.distantFuture
    var lastReviewDate: Date?

    /// Review history for this card. Cascade-deletes when the card is removed,
    /// preventing orphaned ReviewLog rows.
    @Relationship(deleteRule: .cascade, inverse: \ReviewLog.card)
    var logs: [ReviewLog] = []

    var state: CardState {
        get { CardState(rawValue: stateRaw) ?? .new }
        set { stateRaw = newValue.rawValue }
    }

    init() {}

    init(character: String, gradeLevel: Int, orderInGrade: Int) {
        self.character = character
        self.gradeLevel = gradeLevel
        self.orderInGrade = orderInGrade
        self.stateRaw = CardState.new.rawValue
        self.dueDate = Date.distantFuture
    }

    /// Whether this character is considered mastered (stability >= threshold).
    var isMastered: Bool {
        stability >= FSRSEngine.masteryThreshold
    }
}
