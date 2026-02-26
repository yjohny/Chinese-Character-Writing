import Foundation

/// Pure, stateless FSRS v5 scheduler. All methods are pure functions — no SwiftData or UIKit dependency.
/// Reference: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
struct FSRSEngine {
    // MARK: - Constants

    /// Forgetting curve decay constant (FSRS-4.5).
    static let decay: Double = -0.5
    /// Derived factor: 0.9^(1/decay) - 1 = 19/81.
    static let factor: Double = 19.0 / 81.0

    /// Target probability of recall at review time.
    static let desiredRetention: Double = 0.9

    /// Maximum interval in days.
    static let maximumInterval: Int = 36500

    /// Stability threshold (days) to consider a character "mastered".
    static let masteryThreshold: Double = 21.0

    // MARK: - Default Parameters (19 weights, FSRS v5 optimized defaults)

    static let defaultWeights: [Double] = [
        0.4872,   // w0:  initial stability for Again
        1.4003,   // w1:  initial stability for Hard
        3.7145,   // w2:  initial stability for Good
        13.8206,  // w3:  initial stability for Easy
        5.1618,   // w4:  initial difficulty baseline
        1.2298,   // w5:  difficulty sensitivity to first rating
        0.8975,   // w6:  difficulty delta per rating deviation from Good
        0.031,    // w7:  mean reversion weight
        1.6474,   // w8:  recall stability: base factor (used as e^w8)
        0.1367,   // w9:  recall stability: current stability decay exponent
        1.0461,   // w10: recall stability: retrievability factor
        2.1072,   // w11: forget stability: base factor
        0.0793,   // w12: forget stability: difficulty exponent
        0.3246,   // w13: forget stability: old stability power
        1.587,    // w14: forget stability: retrievability factor
        0.2272,   // w15: hard penalty multiplier (< 1)
        2.8755,   // w16: easy bonus multiplier (> 1)
        0.5425,   // w17: short-term review grade scaling
        0.0912,   // w18: short-term review grade offset
    ]

    let w: [Double]

    init(weights: [Double] = FSRSEngine.defaultWeights) {
        self.w = weights
    }

    // MARK: - Core Formulas

    /// Retrievability: probability of recall after `t` days with stability `S`.
    /// R(t, S) = (1 + FACTOR * t / S) ^ DECAY
    func retrievability(elapsedDays t: Double, stability s: Double) -> Double {
        guard s > 0 else { return 0 }
        return pow(1.0 + Self.factor * t / s, Self.decay)
    }

    /// Initial stability when first rating a new card.
    /// S0(G) = w[G-1], floored at 0.1.
    func initialStability(rating: Rating) -> Double {
        max(w[rating.rawValue - 1], 0.1)
    }

    /// Initial difficulty when first rating a new card.
    /// D0(G) = clamp(w4 - e^(w5*(G-1)) + 1, 1, 10)
    func initialDifficulty(rating: Rating) -> Double {
        let g = Double(rating.rawValue)
        let d = w[4] - exp(w[5] * (g - 1.0)) + 1.0
        return clampDifficulty(d)
    }

    /// Update difficulty after a review.
    /// D'(D,G) = w7 * D0(4) + (1 - w7) * (D - w6*(G-3))
    /// Mean-reverts toward the "Easy" initial difficulty to prevent "difficulty hell".
    func nextDifficulty(current d: Double, rating: Rating) -> Double {
        let g = Double(rating.rawValue)
        // D0(4) without clamping for mean reversion target
        let d0Easy = w[4] - exp(w[5] * 3.0) + 1.0
        let delta = d - w[6] * (g - 3.0)
        let newD = w[7] * d0Easy + (1.0 - w[7]) * delta
        return clampDifficulty(newD)
    }

    /// Stability after a SUCCESSFUL recall (rating >= Hard).
    /// S'r = S * (1 + e^w8 * (11-D) * S^(-w9) * (e^(w10*(1-R)) - 1) * penalty * bonus)
    func stabilityAfterSuccess(
        difficulty d: Double,
        stability s: Double,
        retrievability r: Double,
        rating: Rating
    ) -> Double {
        let innerFactor = exp(w[8])
            * (11.0 - d)
            * pow(s, -w[9])
            * (exp(w[10] * (1.0 - r)) - 1.0)

        var multiplier = 1.0
        if rating == .hard { multiplier = w[15] }
        if rating == .easy { multiplier = w[16] }

        let newS = s * (innerFactor * multiplier + 1.0)
        return max(newS, 0.1)
    }

    /// Stability after a LAPSE (rating == Again).
    /// S'f = w11 * D^(-w12) * ((S+1)^w13 - 1) * e^(w14*(1-R))
    /// Clamped to never exceed the old stability.
    func stabilityAfterFailure(
        difficulty d: Double,
        stability s: Double,
        retrievability r: Double
    ) -> Double {
        let newS = w[11]
            * pow(d, -w[12])
            * (pow(s + 1.0, w[13]) - 1.0)
            * exp(w[14] * (1.0 - r))
        return max(min(newS, s), 0.1)
    }

    /// Short-term stability update for same-day reviews.
    /// S' = S * e^(w17 * (G - 3 + w18))
    func stabilityShortTerm(stability s: Double, rating: Rating) -> Double {
        let g = Double(rating.rawValue)
        var increase = exp(w[17] * (g - 3.0 + w[18]))
        // Good and Easy should never decrease stability
        if rating.rawValue >= 3 {
            increase = max(increase, 1.0)
        }
        return max(s * increase, 0.1)
    }

    /// Compute the review interval (days) for a target retention given stability.
    /// I = round(S / FACTOR * (retention^(1/DECAY) - 1))
    /// When desiredRetention = 0.9, this simplifies to approximately round(S).
    func interval(stability s: Double, retention: Double = FSRSEngine.desiredRetention) -> Int {
        guard retention > 0, retention < 1, s > 0 else { return 1 }
        let i = (s / Self.factor) * (pow(retention, 1.0 / Self.decay) - 1.0)
        return max(1, min(Int(round(i)), Self.maximumInterval))
    }

    // MARK: - Schedule

    /// The result of scheduling a card after a review.
    struct SchedulingResult {
        let stability: Double
        let difficulty: Double
        let state: CardState
        let interval: Int           // days until next review
        let dueDate: Date
    }

    /// Main entry point. Given a card's current state and a rating, compute next state.
    func schedule(
        stability: Double,
        difficulty: Double,
        cardState: CardState,
        elapsedDays: Int,
        rating: Rating,
        now: Date = Date()
    ) -> SchedulingResult {
        switch cardState {
        case .new:
            return scheduleNew(rating: rating, now: now)
        case .learning, .relearning:
            return scheduleLearning(
                stability: stability, difficulty: difficulty,
                cardState: cardState, elapsedDays: elapsedDays,
                rating: rating, now: now
            )
        case .review:
            return scheduleReview(
                stability: stability, difficulty: difficulty,
                elapsedDays: elapsedDays, rating: rating, now: now
            )
        }
    }

    // MARK: - Private

    private func scheduleNew(rating: Rating, now: Date) -> SchedulingResult {
        let s = initialStability(rating: rating)
        let d = initialDifficulty(rating: rating)

        let nextState: CardState
        let nextInterval: Int

        switch rating {
        case .again:
            nextState = .learning
            nextInterval = 1
        case .hard:
            nextState = .learning
            nextInterval = 1
        case .good:
            nextState = .review
            nextInterval = interval(stability: s)
        case .easy:
            nextState = .review
            nextInterval = interval(stability: s)
        }

        return SchedulingResult(
            stability: s, difficulty: d, state: nextState,
            interval: nextInterval,
            dueDate: Calendar.current.date(byAdding: .day, value: nextInterval, to: now) ?? now
        )
    }

    private func scheduleLearning(
        stability: Double, difficulty: Double, cardState: CardState,
        elapsedDays: Int, rating: Rating, now: Date
    ) -> SchedulingResult {
        let t = Double(max(elapsedDays, 0))

        // Same-day review (elapsed < 1 day)
        if t < 1 {
            let newS = stabilityShortTerm(stability: stability, rating: rating)
            let newD = nextDifficulty(current: difficulty, rating: rating)
            let nextState: CardState
            let nextInterval: Int

            switch rating {
            case .again:
                nextState = .relearning
                nextInterval = 1
            case .hard:
                nextState = cardState
                nextInterval = 1
            case .good:
                nextState = .review
                nextInterval = interval(stability: newS)
            case .easy:
                nextState = .review
                nextInterval = interval(stability: newS)
            }

            return SchedulingResult(
                stability: newS, difficulty: newD, state: nextState,
                interval: nextInterval,
                dueDate: Calendar.current.date(byAdding: .day, value: nextInterval, to: now) ?? now
            )
        }

        // Multi-day learning review
        let r = retrievability(elapsedDays: t, stability: stability)
        let newD = nextDifficulty(current: difficulty, rating: rating)
        let newS: Double
        let nextState: CardState
        let nextInterval: Int

        switch rating {
        case .again:
            newS = stabilityAfterFailure(difficulty: difficulty, stability: stability, retrievability: r)
            nextState = .relearning
            nextInterval = 1
        case .hard:
            newS = stabilityAfterSuccess(difficulty: difficulty, stability: stability, retrievability: r, rating: rating)
            nextState = cardState
            nextInterval = 1
        case .good:
            newS = stabilityAfterSuccess(difficulty: difficulty, stability: stability, retrievability: r, rating: rating)
            nextState = .review
            nextInterval = interval(stability: newS)
        case .easy:
            newS = stabilityAfterSuccess(difficulty: difficulty, stability: stability, retrievability: r, rating: rating)
            nextState = .review
            nextInterval = interval(stability: newS)
        }

        return SchedulingResult(
            stability: newS, difficulty: newD, state: nextState,
            interval: nextInterval,
            dueDate: Calendar.current.date(byAdding: .day, value: nextInterval, to: now) ?? now
        )
    }

    private func scheduleReview(
        stability: Double, difficulty: Double,
        elapsedDays: Int, rating: Rating, now: Date
    ) -> SchedulingResult {
        let t = Double(max(elapsedDays, 0))

        // Same-day re-review
        if t < 1 {
            let newS = stabilityShortTerm(stability: stability, rating: rating)
            let newD = nextDifficulty(current: difficulty, rating: rating)
            let nextState: CardState = rating == .again ? .relearning : .review
            let nextInterval = rating == .again ? 1 : interval(stability: newS)
            return SchedulingResult(
                stability: newS, difficulty: newD, state: nextState,
                interval: nextInterval,
                dueDate: Calendar.current.date(byAdding: .day, value: nextInterval, to: now) ?? now
            )
        }

        let r = retrievability(elapsedDays: t, stability: stability)
        let newD = nextDifficulty(current: difficulty, rating: rating)
        let newS: Double
        let nextState: CardState
        let nextInterval: Int

        switch rating {
        case .again:
            newS = stabilityAfterFailure(difficulty: difficulty, stability: stability, retrievability: r)
            nextState = .relearning
            nextInterval = 1
        case .hard:
            newS = stabilityAfterSuccess(difficulty: difficulty, stability: stability, retrievability: r, rating: rating)
            nextState = .review
            nextInterval = interval(stability: newS)
        case .good:
            newS = stabilityAfterSuccess(difficulty: difficulty, stability: stability, retrievability: r, rating: rating)
            nextState = .review
            nextInterval = interval(stability: newS)
        case .easy:
            newS = stabilityAfterSuccess(difficulty: difficulty, stability: stability, retrievability: r, rating: rating)
            nextState = .review
            nextInterval = interval(stability: newS)
        }

        return SchedulingResult(
            stability: newS, difficulty: newD, state: nextState,
            interval: nextInterval,
            dueDate: Calendar.current.date(byAdding: .day, value: nextInterval, to: now) ?? now
        )
    }

    private func clampDifficulty(_ d: Double) -> Double {
        min(max(d, 1.0), 10.0)
    }
}
