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
        var existingNewDescriptor = FetchDescriptor<ReviewCard>(
            predicate: #Predicate { $0.stateRaw == newStateRaw },
            sortBy: [SortDescriptor(\.orderInGrade)]
        )
        existingNewDescriptor.fetchLimit = 1
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

        // 6. Pacing adjustment: when new cards are blocked due to struggling,
        //    pull forward below-grade verification cards to mix in easier material.
        //    This silently adjusts difficulty without telling the user.
        let newCardsBlocked = relearningCount >= Self.maxRelearningBeforeStopNew
            || totalDue >= Self.maxDueBeforeStopNew
        if newCardsBlocked {
            let startingGrade = fetchProfile()?.startingGrade ?? 1
            if startingGrade > 1 {
                if let card = fetchNextUnverifiedBelowGradeCard(startingGrade: startingGrade),
                   let entry = characterData.character(forSimplified: card.character) {
                    return (card, entry)
                }
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

    // MARK: - Reset

    /// Deletes all ReviewCards, ReviewLogs, and resets the UserProfile.
    /// Used when the user wants to start completely fresh.
    func resetAllProgress() {
        // Delete all review cards
        do {
            try modelContext.delete(model: ReviewCard.self)
        } catch {
            print("Failed to delete ReviewCards: \(error)")
        }

        // Delete all review logs
        do {
            try modelContext.delete(model: ReviewLog.self)
        } catch {
            print("Failed to delete ReviewLogs: \(error)")
        }

        // Reset profile (keep preferences, clear progress)
        if let profile = fetchProfile() {
            profile.currentStreak = 0
            profile.longestStreak = 0
            profile.lastPracticeDate = nil
            profile.totalReviews = 0
        }

        try? modelContext.save()
    }

    // MARK: - Starting Grade

    /// Creates assumed-known ReviewCards for all characters below the starting grade.
    /// Cards get graduated initial stability based on grade distance and staggered due dates
    /// so they trickle in for verification rather than flooding the queue.
    func setupAssumedKnownCards(startingGrade: Int) {
        guard startingGrade > 1 else { return }

        let existingCharacters = fetchAllCardCharacters()

        let now = Date()
        let calendar = Calendar.current
        let assumedDifficulty = fsrs.initialDifficulty(rating: .good)

        for grade in characterData.gradeLevels where grade < startingGrade {
            let gradeDistance = startingGrade - grade
            let initialStability: Double
            switch gradeDistance {
            case 1: initialStability = 7.0
            case 2: initialStability = 14.0
            default: initialStability = 21.0
            }

            let gradeChars = characterData.characters(forGrade: grade)
            let spreadDays = max(1, Int(initialStability))

            for (index, entry) in gradeChars.enumerated() {
                guard !existingCharacters.contains(entry.simplified) else { continue }

                let card = ReviewCard(
                    character: entry.simplified,
                    gradeLevel: entry.gradeLevel,
                    orderInGrade: entry.orderInGrade
                )
                card.state = .review
                card.stability = initialStability
                card.difficulty = assumedDifficulty
                // Stagger due dates evenly across the stability window
                let dayOffset = index % spreadDays
                let dueDate = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
                card.dueDate = dueDate
                // Set lastReviewDate so elapsed days = stability when the card comes due,
                // giving retrievability ≈ 0.9 and proper stability increase on success
                let stabilityDays = Int(initialStability)
                card.lastReviewDate = calendar.date(byAdding: .day, value: -stabilityDays, to: dueDate)
                modelContext.insert(card)
            }
        }

        try? modelContext.save()
    }

    // MARK: - Private

    /// Fetches just the character strings from all ReviewCards, returning a Set for
    /// existence checks. Avoids retaining the full card object graph in the caller's scope.
    private func fetchAllCardCharacters() -> Set<String> {
        let descriptor = FetchDescriptor<ReviewCard>()
        let cards = (try? modelContext.fetch(descriptor)) ?? []
        return Set(cards.map(\.character))
    }

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
        let startingGrade = max(1, fetchProfile()?.startingGrade ?? 1)

        let existingCharacters = fetchAllCardCharacters()

        // Find the next character that doesn't have a ReviewCard yet,
        // starting from the user's chosen grade level
        for grade in characterData.gradeLevels where grade >= startingGrade {
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

    /// Finds the next below-grade assumed-known card that hasn't been independently reviewed yet.
    /// Used for pacing adjustment: when the user is struggling at their starting grade,
    /// we pull forward easier verification cards to build confidence and check foundations.
    /// Prioritizes grades closest to the starting grade (most likely gaps).
    private func fetchNextUnverifiedBelowGradeCard(startingGrade: Int) -> ReviewCard? {
        let reviewStateRaw = CardState.review.rawValue
        // Assumed-known cards: state = .review, reps == 0, lapses == 0
        // (pre-seeded with stability but never independently reviewed)
        var descriptor = FetchDescriptor<ReviewCard>(
            predicate: #Predicate {
                $0.stateRaw == reviewStateRaw && $0.reps == 0 && $0.lapses == 0
            },
            sortBy: [
                SortDescriptor(\.gradeLevel, order: .reverse), // closest to starting grade first
                SortDescriptor(\.dueDate)
            ]
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func daysBetween(_ from: Date, and to: Date) -> Int {
        let calendar = Calendar.current
        let fromDay = calendar.startOfDay(for: from)
        let toDay = calendar.startOfDay(for: to)
        return max(0, calendar.dateComponents([.day], from: fromDay, to: toDay).day ?? 0)
    }
}
