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

    /// Bumped after every rateCard/save so views that read stats re-render.
    /// `@Observable` tracks reads of this property; views that touch it get invalidated.
    private(set) var statsRevision: Int = 0

    /// Set to true in rateCard() when reviewsToday hits dailyGoal exactly (fires once).
    var dailyGoalReached: Bool = false

    /// Cached set of character strings that already have ReviewCards. Avoids
    /// materializing all cards on every `nextCard()` / `introduceNextNewCard()` call.
    /// Invalidated (set to nil) only when new cards are created.
    private var knownCardCharacters: Set<String>?

    /// Cached UserProfile to avoid repeated SwiftData fetches. The profile is a
    /// singleton — once fetched (or created), it never changes identity. Properties
    /// are mutated in place, so the cached reference stays valid.
    private var cachedProfile: UserProfile?

    init(characterData: CharacterDataService, modelContext: ModelContext) {
        self.characterData = characterData
        self.modelContext = modelContext
    }

    // MARK: - Next Card

    /// Returns the next card to study, along with its character data.
    /// Returns nil if no cards are available (all caught up for now).
    func nextCard() -> (ReviewCard, CharacterEntry)? {
        // 1. Relearning cards due now
        if let card = fetchFirstDueCard(state: .relearning),
           let entry = characterData.character(forSimplified: card.character) {
            return (card, entry)
        }

        // 2. Learning cards due now
        if let card = fetchFirstDueCard(state: .learning),
           let entry = characterData.character(forSimplified: card.character) {
            return (card, entry)
        }

        // 3. Review cards due now
        if let card = fetchFirstDueCard(state: .review),
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
        // Use fetchCount — much cheaper than materializing all due cards
        let relearningCount = countDueCards(state: .relearning)
        let totalDue = countDueCards(state: .review)
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

    /// Peeks at the likely next card without creating new ReviewCards or mutating state.
    /// Used for prefetching stroke data during transitions.
    func peekNextCard() -> (ReviewCard, CharacterEntry)? {
        // Check due cards in priority order (same as nextCard, but read-only)
        for state: CardState in [.relearning, .learning, .review] {
            if let card = fetchFirstDueCard(state: state),
               let entry = characterData.character(forSimplified: card.character) {
                return (card, entry)
            }
        }
        // Check existing .new cards
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
        // Don't introduce new cards here — that mutates state.
        // Peek returns nil if next card would be a fresh introduction.
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

        card.reps += 1
        if rating == .again {
            card.lapses += 1
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
        dailyGoalReached = false
        if let profile = fetchProfile() {
            profile.incrementReviewsToday(now: now)
            profile.totalReviews += 1
            profile.updateStreak(now: now)
            if profile.reviewsToday == profile.dailyGoal {
                dailyGoalReached = true
            }
        }

        saveContext()
        statsRevision += 1
    }

    // MARK: - Daily Goal

    /// Returns today's review progress and the daily goal target.
    func dailyProgress() -> (current: Int, goal: Int) {
        guard let profile = fetchProfile() else { return (0, 10) }
        let calendar = Calendar.current
        if let last = profile.lastReviewCountDate,
           calendar.startOfDay(for: last) == calendar.startOfDay(for: Date()) {
            return (profile.reviewsToday, profile.dailyGoal)
        }
        return (0, profile.dailyGoal)
    }

    func updateDailyGoal(_ goal: Int) {
        if let profile = fetchProfile() {
            profile.dailyGoal = goal
            saveContext()
        }
    }

    // MARK: - Milestones

    /// Checks for a newly achieved milestone. Returns one at a time to avoid modal stacking.
    func checkForNewMilestones() -> MilestoneType? {
        guard let profile = fetchProfile() else { return nil }

        // Check mastery milestones (cheap: single fetchCount query)
        let mastered = masteredCount()
        for (count, milestone) in MilestoneType.masteryThresholds {
            if mastered >= count && !profile.hasAchieved(milestone) {
                profile.markAchieved(milestone)
                saveContext()
                return milestone
            }
        }

        // Check streak milestones (free: reads cached profile properties)
        for (days, milestone) in MilestoneType.streakThresholds {
            if profile.currentStreak >= days && !profile.hasAchieved(milestone) {
                profile.markAchieved(milestone)
                saveContext()
                return milestone
            }
        }

        // Check grade completion — only if there are unachieved grade milestones.
        // This avoids the expensive allGradeStats() fetch (materializes all cards)
        // on every review once all grade milestones have been achieved.
        let hasUnachievedGradeMilestone = characterData.gradeLevels.contains { grade in
            guard let milestone = MilestoneType.gradeComplete(for: grade) else { return false }
            return !profile.hasAchieved(milestone)
        }
        if hasUnachievedGradeMilestone {
            let gradeStats = allGradeStats()
            for grade in characterData.gradeLevels {
                guard let milestone = MilestoneType.gradeComplete(for: grade) else { continue }
                let total = characterData.totalCharacters(forGrade: grade)
                let gradeMastered = gradeStats[grade]?.mastered ?? 0
                if gradeMastered >= total && total > 0 && !profile.hasAchieved(milestone) {
                    profile.markAchieved(milestone)
                    saveContext()
                    return milestone
                }
            }
        }

        return nil
    }

    // MARK: - Sound Settings

    func updateSoundEffects(_ enabled: Bool) {
        if let profile = fetchProfile() {
            profile.soundEffectsEnabled = enabled
            saveContext()
        }
    }

    func updateAnimationSpeed(_ speed: Int) {
        if let profile = fetchProfile() {
            profile.animationSpeed = speed
            saveContext()
        }
    }

    func updateSessionLength(_ length: Int) {
        if let profile = fetchProfile() {
            profile.sessionLength = length
            saveContext()
        }
    }

    // MARK: - Stats

    func masteredCount() -> Int {
        let threshold = FSRSEngine.masteryThreshold
        let descriptor = FetchDescriptor<ReviewCard>(
            predicate: #Predicate { $0.stability >= threshold }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    /// Stats for a single grade level.
    struct GradeStats {
        let introduced: Int
        let learning: Int
        let mastered: Int
    }

    /// Fetches introduced/learning/mastered counts for all grades in a single query,
    /// avoiding 3 separate fetchCount calls per grade (21+ queries → 1).
    func allGradeStats() -> [Int: GradeStats] {
        let descriptor = FetchDescriptor<ReviewCard>()
        guard let cards = try? modelContext.fetch(descriptor) else { return [:] }

        let threshold = FSRSEngine.masteryThreshold
        var result: [Int: (introduced: Int, learning: Int, mastered: Int)] = [:]

        for card in cards {
            let grade = card.gradeLevel
            var stats = result[grade] ?? (0, 0, 0)
            stats.introduced += 1
            if card.state != .new && card.stability < threshold {
                stats.learning += 1
            }
            if card.stability >= threshold {
                stats.mastered += 1
            }
            result[grade] = stats
        }

        return result.mapValues { GradeStats(introduced: $0.introduced, learning: $0.learning, mastered: $0.mastered) }
    }

    /// Returns all ReviewCards indexed by character string, for batch lookup.
    func allCardsByCharacter() -> [String: ReviewCard] {
        let descriptor = FetchDescriptor<ReviewCard>()
        guard let cards = try? modelContext.fetch(descriptor) else { return [:] }
        return Dictionary(cards.map { ($0.character, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Returns review counts per day for the last N weeks, for the heatmap.
    /// Dictionary keys are calendar day starts (midnight), values are review counts.
    func reviewCountsByDay(weeks: Int = 12) -> [Date: Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: today) else {
            return [:]
        }
        let descriptor = FetchDescriptor<ReviewLog>(
            predicate: #Predicate { $0.reviewDate >= startDate }
        )
        guard let logs = try? modelContext.fetch(descriptor) else { return [:] }

        var counts: [Date: Int] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.reviewDate)
            counts[day, default: 0] += 1
        }
        return counts
    }

    /// Returns the number of reviews due today and in the coming days.
    func reviewForecast() -> (today: Int, tomorrow: Int, thisWeek: Int) {
        let calendar = Calendar.current
        let now = Date()
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: todayEnd)!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))!

        let descriptor = FetchDescriptor<ReviewCard>(
            predicate: #Predicate { $0.dueDate <= weekEnd }
        )
        guard let cards = try? modelContext.fetch(descriptor) else { return (0, 0, 0) }

        var today = 0, tomorrow = 0, week = 0
        for card in cards {
            if card.dueDate <= now {
                today += 1
            } else if card.dueDate <= todayEnd {
                today += 1
            }
            if card.dueDate > todayEnd && card.dueDate <= tomorrowEnd {
                tomorrow += 1
            }
            week += 1
        }
        return (today, tomorrow, week)
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

    /// Exports all review data as a JSON-compatible dictionary for backup/analysis.
    func exportProgressData() -> Data? {
        let profile = fetchProfile()
        let cardDescriptor = FetchDescriptor<ReviewCard>()
        let logDescriptor = FetchDescriptor<ReviewLog>(sortBy: [SortDescriptor(\.reviewDate)])
        guard let cards = try? modelContext.fetch(cardDescriptor),
              let logs = try? modelContext.fetch(logDescriptor) else {
            return nil
        }

        let dateFormatter = ISO8601DateFormatter()

        let exportCards = cards.map { card -> [String: Any] in
            [
                "character": card.character,
                "gradeLevel": card.gradeLevel,
                "stability": card.stability,
                "difficulty": card.difficulty,
                "reps": card.reps,
                "lapses": card.lapses,
                "state": card.state.rawValue,
                "dueDate": dateFormatter.string(from: card.dueDate),
                "lastReviewDate": card.lastReviewDate.map { dateFormatter.string(from: $0) } ?? ""
            ]
        }

        let exportLogs = logs.map { log -> [String: Any] in
            [
                "character": log.character,
                "reviewDate": dateFormatter.string(from: log.reviewDate),
                "rating": log.rating.rawValue,
                "elapsedDays": log.elapsedDays,
                "scheduledDays": log.scheduledDays,
                "stabilityBefore": log.stabilityBefore,
                "stabilityAfter": log.stabilityAfter
            ]
        }

        let export: [String: Any] = [
            "exportDate": dateFormatter.string(from: Date()),
            "version": "1.0",
            "profile": [
                "totalReviews": profile?.totalReviews ?? 0,
                "currentStreak": profile?.currentStreak ?? 0,
                "longestStreak": profile?.longestStreak ?? 0,
                "startingGrade": profile?.startingGrade ?? 1,
                "dailyGoal": profile?.dailyGoal ?? 10
            ],
            "cards": exportCards,
            "reviewLogs": exportLogs
        ]

        return try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
    }

    func fetchProfile() -> UserProfile? {
        if let cached = cachedProfile {
            return cached
        }
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? modelContext.fetch(descriptor)) ?? []
        if let profile = profiles.first {
            cachedProfile = profile
            return profile
        }
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        saveContext()
        cachedProfile = newProfile
        return newProfile
    }

    // MARK: - Settings

    func updateStartingGrade(_ grade: Int) {
        if let profile = fetchProfile() {
            profile.startingGrade = grade
            saveContext()
        }
        setupAssumedKnownCards(startingGrade: grade)
    }

    func updateUseTraditional(_ value: Bool) {
        if let profile = fetchProfile() {
            profile.useTraditional = value
            saveContext()
        }
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

        knownCardCharacters = nil // Invalidate — bulk insert changes the set
        saveContext()
        statsRevision += 1
    }

    // MARK: - Private

    /// Returns the cached set of character strings with existing ReviewCards.
    /// Lazily populated on first call; invalidated when new cards are inserted.
    private func fetchAllCardCharacters() -> Set<String> {
        if let cached = knownCardCharacters {
            return cached
        }
        let descriptor = FetchDescriptor<ReviewCard>()
        let cards = (try? modelContext.fetch(descriptor)) ?? []
        let result = Set(cards.map(\.character))
        knownCardCharacters = result
        return result
    }

    /// Fetch just the first due card for a given state (fetchLimit: 1).
    private func fetchFirstDueCard(state: CardState) -> ReviewCard? {
        let now = Date()
        let stateRaw = state.rawValue
        var descriptor = FetchDescriptor<ReviewCard>(
            predicate: #Predicate {
                $0.stateRaw == stateRaw && $0.dueDate <= now
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    /// Count due cards for a given state without materializing them (fetchCount).
    private func countDueCards(state: CardState) -> Int {
        let now = Date()
        let stateRaw = state.rawValue
        let descriptor = FetchDescriptor<ReviewCard>(
            predicate: #Predicate {
                $0.stateRaw == stateRaw && $0.dueDate <= now
            }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
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
                    knownCardCharacters?.insert(entry.simplified)
                    saveContext()

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

    /// Centralized save with error logging. Persistence failures (disk full,
    /// constraint violations) are logged rather than silently swallowed.
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("⚠️ SwiftData save failed: \(error)")
        }
    }
}
