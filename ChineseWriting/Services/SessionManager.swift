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

    /// Don't introduce new cards if this many or more cards are in relearning (recently missed).
    static let maxRelearningBeforeStopNew = 5
    /// Don't introduce new cards if more than this many reviews are due (catch-up backstop).
    static let maxDueBeforeStopNew = 50

    init(characterData: CharacterDataService, modelContext: ModelContext) {
        self.characterData = characterData
        self.modelContext = modelContext
    }

    // MARK: - Next Card

    /// Returns the next card to study, along with its character data.
    /// Returns nil if no cards are available (all caught up for now).
    func nextCard() -> (ReviewCard, CharacterEntry)? {
        // 1. Relearning cards due now
        let dueRelearning = fetchDueCards(state: .relearning)
        if let card = dueRelearning.first,
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

        // 4. Existing new cards (created but never completed — user quit mid-session)
        let newStateRaw = CardState.new.rawValue
        let existingNewDescriptor = FetchDescriptor<ReviewCard>(
            predicate: #Predicate { $0.stateRaw == newStateRaw },
            sortBy: [SortDescriptor(\.orderInGrade)]
        )
        if let card = (try? modelContext.fetch(existingNewDescriptor))?.first,
           let entry = characterData.character(forSimplified: card.character) {
            return (card, entry)
        }

        // 5. New cards (only if few relearning cards and due backlog is manageable)
        let relearningCount = dueRelearning.count
        let totalDue = dueReviews.count
        if relearningCount < Self.maxRelearningBeforeStopNew && totalDue < Self.maxDueBeforeStopNew {
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
            predicate: #Predicate { $0.gradeLevel == grade }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func learningCount(forGrade grade: Int) -> Int {
        let threshold = FSRSEngine.masteryThreshold
        let newStateRaw = CardState.new.rawValue
        let descriptor = FetchDescriptor<ReviewCard>(
            predicate: #Predicate {
                $0.gradeLevel == grade && $0.stateRaw != newStateRaw && $0.stability < threshold
            }
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
        // Batch-fetch all existing card characters to avoid per-character queries
        let allCardsDescriptor = FetchDescriptor<ReviewCard>()
        let existingCards = (try? modelContext.fetch(allCardsDescriptor)) ?? []
        let existingCharacters = Set(existingCards.map(\.character))

        // Find the next character that doesn't have a ReviewCard yet
        for grade in characterData.gradeLevels {
            let gradeChars = characterData.characters(forGrade: grade)
            for entry in gradeChars {
                if !existingCharacters.contains(entry.simplified) {
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

                    return (card, entry)
                }
            }
        }
        return nil
    }

    private func daysBetween(_ from: Date, and to: Date) -> Int {
        let calendar = Calendar.current
        let fromDay = calendar.startOfDay(for: from)
        let toDay = calendar.startOfDay(for: to)
        return max(0, calendar.dateComponents([.day], from: fromDay, to: toDay).day ?? 0)
    }
}
