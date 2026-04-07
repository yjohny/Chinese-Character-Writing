import Foundation
import SwiftData

/// Records each individual review event for analytics.
@Model
final class ReviewLog {
    var character: String = ""
    var reviewDate: Date = Date()
    var ratingRaw: Int = 0
    var elapsedDays: Int = 0
    var scheduledDays: Int = 0
    var stabilityBefore: Double = 0.0
    var stabilityAfter: Double = 0.0
    var wasOverride: Bool = false
    var visionConfidence: Double = 0.0

    /// Back-reference to the parent card. Inverse of `ReviewCard.logs`. The
    /// `character` string is also kept directly so logs remain analyzable even
    /// if the card relationship is ever nil.
    var card: ReviewCard?

    var rating: Rating {
        get { Rating(rawValue: ratingRaw) ?? .again }
        set { ratingRaw = newValue.rawValue }
    }

    init() {}

    init(character: String, rating: Rating, elapsedDays: Int, scheduledDays: Int,
         stabilityBefore: Double, stabilityAfter: Double,
         wasOverride: Bool = false, visionConfidence: Double = 0.0) {
        self.character = character
        self.reviewDate = Date()
        self.ratingRaw = rating.rawValue
        self.elapsedDays = elapsedDays
        self.scheduledDays = scheduledDays
        self.stabilityBefore = stabilityBefore
        self.stabilityAfter = stabilityAfter
        self.wasOverride = wasOverride
        self.visionConfidence = visionConfidence
    }
}
