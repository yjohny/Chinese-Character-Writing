import Foundation
import SwiftData

/// Manages the study queue: picks the next character and rates reviewed cards.
///
/// Priority order:
/// 1. Relearning cards (failed recently, due now)
/// 2. Learning cards (in initial acquisition, due now)
/// 3. Due review cards (past scheduled date)
/// 4. New cards (next unseen character from current grade, in order)
@MainActor
@Observable
final class SessionManager {
    let characterData: CharacterDataService
    let modelContext: ModelContext
    let fsrs = FSRSEngine()

    /// Maximum new cards to introduce per day.
    static let maxNewPerDay = 10
    /// Don't introduce new cards if more than this many reviews are due.
    static let maxDueBeforeStopNew = 20

    private var newCardsIntroducedToday = 0
    private var lastNewCardDate: Date?

    init(characterData: CharacterDataService, modelContext: ModelContext) {
        self.characterData = characterData
        self.modelContext = modelContext
    }

    // MARK: - Next Card

    /// Returns the next card to study, along with its character data.
    /// Returns nil if no cards are available (session complete for today).
    func nextCard() -> (ReviewCard, CharacterEntry)? {
        resetNewCardCountIfNeeded()

        // 1. Relearning cards due now
        if let card = fetchDueCards(state: .relearning).first,
           let entry = characterData.character(forSimplified: card.character) {
            return (card, entry)
        }

        // 2. Learning cards due now
        if let card = fetchDueCards(state: .learning).first,
           let entry = characterData.character(forSimplified: card.character) {
            return (card, entry)
        }

        // 3. Review cards due now
        let dueReviews = fetchDueCards(state: .review)
        if let card = dueReviews.first,
           let entry = characterData.character(forSimplified: card.character) {
            return (card, entry)
        }

        // 4. New cards (only if due backlog is small enough)
        let totalDue = dueReviews.count
        if totalDue < Self.maxDueBeforeStopNew && newCardsIntroducedToday < Self.maxNewPerDay {
            if let (card, entry) = introduceNextNewCard() {
                return (card, entry)
            }
        }

        return nil
    }

    // MARK: - Rate Card

    /// Rate the current card and update FSRS state.
    func rateCard(
        _ card: ReviewCard,
        rating: Rating,
        wasOverride: Bool = false,
        visionConfidence: Double = 0.0
    ) {
        let now = Date()
        let elapsedDays = daysBetween(card.lastReviewDate ?? now, and: now)

        let stabilityBefore = card.stability
        let result = fsrs.schedule(
            stability: card.stability,
            difficulty: card.difficulty,
            cardState: card.state,
            elapsedDays: elapsedDays,
            rating: rating,
            now: now
        )

        // Update card
        card.stability = result.stability
        card.difficulty = result.difficulty
        card.state = result.state
        card.dueDate = result.dueDate
        card.lastReviewDate = now

        if rating == .again {
            card.lapses += 1
        } else {
            card.reps += 1
        }

        // Create review log
        let log = ReviewLog(
            character: card.character,
            rating: rating,
            elapsedDays: elapsedDays,
            scheduledDays: result.interval,
            stabilityBefore: stabilityBefore,
            stabilityAfter: result.stability,
            wasOverride: wasOverride,
            visionConfidence: visionConfidence
        )
        modelContext.insert(log)

        // Update user profile
        if let profile = fetchProfile() {
            profile.totalReviews += 1
            profile.updateStreak(now: now)
        }

        try? modelContext.save()
    }

    // MARK: - Stats

    func masteredCount() -> Int {
        let threshold = FSRSEngine.masteryThreshold
        let descriptor = FetchDescriptor<ReviewCard>(
            predicate: #Predicate { $0.stability >= threshold }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func totalIntroduced(forGrade grade: Int) -> Int {
        let descriptor = FetchDescriptor<ReviewCard>(
            predicate: #Predicate { $0.gradeLevel == grade && $0.stateRaw != 0 }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func masteredCount(forGrade grade: Int) -> Int {
        let threshold = FSRSEngine.masteryThreshold
        let descriptor = FetchDescriptor<ReviewCard>(
            predicate: #Predicate { $0.gradeLevel == grade && $0.stability >= threshold }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func fetchProfile() -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? modelContext.fetch(descriptor)) ?? []
        if let profile = profiles.first {
            return profile
        }
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        try? modelContext.save()
        return newProfile
    }

    // MARK: - Private

    private func fetchDueCards(state: CardState) -> [ReviewCard] {
        let now = Date()
        let stateRaw = state.rawValue
        let descriptor = FetchDescriptor<ReviewCard>(
            predicate: #Predicate {
                $0.stateRaw == stateRaw && $0.dueDate <= now
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func introduceNextNewCard() -> (ReviewCard, CharacterEntry)? {
        // Find the next character that doesn't have a ReviewCard yet
        for grade in characterData.gradeLevels {
            let gradeChars = characterData.characters(forGrade: grade)
            for entry in gradeChars {
                let char = entry.simplified
                let descriptor = FetchDescriptor<ReviewCard>(
                    predicate: #Predicate { $0.character == char }
                )
                let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
                if existingCount == 0 {
                    // Create a new ReviewCard
                    let card = ReviewCard(
                        character: entry.simplified,
                        gradeLevel: entry.gradeLevel,
                        orderInGrade: entry.orderInGrade
                    )
                    card.dueDate = Date() // due immediately
                    card.state = .new
                    modelContext.insert(card)
                    try? modelContext.save()

                    newCardsIntroducedToday += 1
                    lastNewCardDate = Date()
                    return (card, entry)
                }
            }
        }
        return nil
    }

    private func resetNewCardCountIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let lastDate = lastNewCardDate,
           !calendar.isDate(lastDate, inSameDayAs: today) {
            newCardsIntroducedToday = 0
        }
    }

    private func daysBetween(_ from: Date, and to: Date) -> Int {
        let calendar = Calendar.current
        let fromDay = calendar.startOfDay(for: from)
        let toDay = calendar.startOfDay(for: to)
        return max(0, calendar.dateComponents([.day], from: fromDay, to: toDay).day ?? 0)
    }
}
