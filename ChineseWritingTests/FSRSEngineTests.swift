import XCTest
@testable import ChineseWriting

final class FSRSEngineTests: XCTestCase {
    let engine = FSRSEngine()

    // MARK: - Weight Validation

    func testDefaultWeightsCount() {
        XCTAssertEqual(FSRSEngine.defaultWeights.count, 19)
    }

    func testCustomWeightsWrongCountTraps() {
        // Can't test precondition failure in a unit test easily,
        // but we verify that the correct count works.
        let weights = FSRSEngine.defaultWeights
        let e = FSRSEngine(weights: weights)
        XCTAssertEqual(e.w.count, 19)
    }

    // MARK: - Retrievability

    func testRetrievabilityAtZeroDays() {
        // At t=0 elapsed, retrievability should be 1.0 (perfect recall)
        let r = engine.retrievability(elapsedDays: 0, stability: 10)
        XCTAssertEqual(r, 1.0, accuracy: 1e-10)
    }

    func testRetrievabilityAtStability() {
        // At t=S, R should be approximately 0.9 (desired retention)
        let s = 10.0
        let r = engine.retrievability(elapsedDays: s, stability: s)
        XCTAssertEqual(r, 0.9, accuracy: 0.01)
    }

    func testRetrievabilityDecreases() {
        let s = 10.0
        let r1 = engine.retrievability(elapsedDays: 5, stability: s)
        let r2 = engine.retrievability(elapsedDays: 10, stability: s)
        let r3 = engine.retrievability(elapsedDays: 20, stability: s)
        XCTAssertGreaterThan(r1, r2)
        XCTAssertGreaterThan(r2, r3)
    }

    func testRetrievabilityZeroStability() {
        let r = engine.retrievability(elapsedDays: 5, stability: 0)
        XCTAssertEqual(r, 0.0)
    }

    // MARK: - Initial Stability

    func testInitialStabilityIncreasesByRating() {
        let sAgain = engine.initialStability(rating: .again)
        let sHard = engine.initialStability(rating: .hard)
        let sGood = engine.initialStability(rating: .good)
        let sEasy = engine.initialStability(rating: .easy)

        XCTAssertLessThan(sAgain, sHard)
        XCTAssertLessThan(sHard, sGood)
        XCTAssertLessThan(sGood, sEasy)
    }

    func testInitialStabilityFloor() {
        // Even with weights that might produce negative values, stability is floored at 0.1
        let s = engine.initialStability(rating: .again)
        XCTAssertGreaterThanOrEqual(s, 0.1)
    }

    func testInitialStabilityMatchesWeights() {
        // S0(G) = w[G-1]
        XCTAssertEqual(engine.initialStability(rating: .again), max(FSRSEngine.defaultWeights[0], 0.1))
        XCTAssertEqual(engine.initialStability(rating: .hard), max(FSRSEngine.defaultWeights[1], 0.1))
        XCTAssertEqual(engine.initialStability(rating: .good), max(FSRSEngine.defaultWeights[2], 0.1))
        XCTAssertEqual(engine.initialStability(rating: .easy), max(FSRSEngine.defaultWeights[3], 0.1))
    }

    // MARK: - Initial Difficulty

    func testInitialDifficultyDecreasesWithBetterRating() {
        let dAgain = engine.initialDifficulty(rating: .again)
        let dHard = engine.initialDifficulty(rating: .hard)
        let dGood = engine.initialDifficulty(rating: .good)
        let dEasy = engine.initialDifficulty(rating: .easy)

        XCTAssertGreaterThan(dAgain, dHard)
        XCTAssertGreaterThan(dHard, dGood)
        XCTAssertGreaterThan(dGood, dEasy)
    }

    func testInitialDifficultyClamped() {
        for rating in Rating.allCases {
            let d = engine.initialDifficulty(rating: rating)
            XCTAssertGreaterThanOrEqual(d, 1.0)
            XCTAssertLessThanOrEqual(d, 10.0)
        }
    }

    // MARK: - Next Difficulty

    func testNextDifficultyMeanReverts() {
        // After many "Good" ratings, difficulty should approach D0(Good)
        var d = 8.0 // Start high
        for _ in 0..<50 {
            d = engine.nextDifficulty(current: d, rating: .good)
        }
        let d0Good = engine.initialDifficulty(rating: .good)
        XCTAssertEqual(d, d0Good, accuracy: 0.5)
    }

    func testNextDifficultyAgainIncreases() {
        let d = 5.0
        let newD = engine.nextDifficulty(current: d, rating: .again)
        XCTAssertGreaterThan(newD, d)
    }

    func testNextDifficultyEasyDecreases() {
        let d = 5.0
        let newD = engine.nextDifficulty(current: d, rating: .easy)
        XCTAssertLessThan(newD, d)
    }

    func testNextDifficultyClamped() {
        // Even extreme inputs should stay in [1, 10]
        let high = engine.nextDifficulty(current: 10.0, rating: .again)
        XCTAssertLessThanOrEqual(high, 10.0)

        let low = engine.nextDifficulty(current: 1.0, rating: .easy)
        XCTAssertGreaterThanOrEqual(low, 1.0)
    }

    // MARK: - Stability After Success

    func testStabilityAfterSuccessIncreases() {
        let s = 5.0
        let d = 5.0
        let r = 0.9
        let newS = engine.stabilityAfterSuccess(difficulty: d, stability: s, retrievability: r, rating: .good)
        XCTAssertGreaterThan(newS, s)
    }

    func testStabilityAfterSuccessEasyBonusVsGood() {
        let s = 5.0
        let d = 5.0
        let r = 0.9
        let sGood = engine.stabilityAfterSuccess(difficulty: d, stability: s, retrievability: r, rating: .good)
        let sEasy = engine.stabilityAfterSuccess(difficulty: d, stability: s, retrievability: r, rating: .easy)
        XCTAssertGreaterThan(sEasy, sGood)
    }

    func testStabilityAfterSuccessHardPenaltyVsGood() {
        let s = 5.0
        let d = 5.0
        let r = 0.9
        let sHard = engine.stabilityAfterSuccess(difficulty: d, stability: s, retrievability: r, rating: .hard)
        let sGood = engine.stabilityAfterSuccess(difficulty: d, stability: s, retrievability: r, rating: .good)
        XCTAssertLessThan(sHard, sGood)
    }

    func testStabilityAfterSuccessFloor() {
        let newS = engine.stabilityAfterSuccess(difficulty: 10, stability: 0.1, retrievability: 1.0, rating: .good)
        XCTAssertGreaterThanOrEqual(newS, 0.1)
    }

    // MARK: - Stability After Failure

    func testStabilityAfterFailureDecreases() {
        let s = 10.0
        let d = 5.0
        let r = 0.5
        let newS = engine.stabilityAfterFailure(difficulty: d, stability: s, retrievability: r)
        XCTAssertLessThan(newS, s)
    }

    func testStabilityAfterFailureNeverExceedsOld() {
        let s = 2.0
        let d = 1.0
        let r = 0.1
        let newS = engine.stabilityAfterFailure(difficulty: d, stability: s, retrievability: r)
        XCTAssertLessThanOrEqual(newS, s)
    }

    func testStabilityAfterFailureFloor() {
        let newS = engine.stabilityAfterFailure(difficulty: 10, stability: 0.1, retrievability: 1.0)
        XCTAssertGreaterThanOrEqual(newS, 0.1)
    }

    // MARK: - Short-Term Stability

    func testStabilityShortTermGoodNeverDecreases() {
        let s = 5.0
        let newS = engine.stabilityShortTerm(stability: s, rating: .good)
        XCTAssertGreaterThanOrEqual(newS, s)
    }

    func testStabilityShortTermEasyNeverDecreases() {
        let s = 5.0
        let newS = engine.stabilityShortTerm(stability: s, rating: .easy)
        XCTAssertGreaterThanOrEqual(newS, s)
    }

    func testStabilityShortTermAgainDecreases() {
        let s = 5.0
        let newS = engine.stabilityShortTerm(stability: s, rating: .again)
        XCTAssertLessThan(newS, s)
    }

    func testStabilityShortTermFloor() {
        let newS = engine.stabilityShortTerm(stability: 0.1, rating: .again)
        XCTAssertGreaterThanOrEqual(newS, 0.1)
    }

    // MARK: - Interval Calculation

    func testIntervalApproximatesStability() {
        // With default retention 0.9, interval ≈ stability
        let s = 10.0
        let i = engine.interval(stability: s)
        XCTAssertEqual(Double(i), s, accuracy: 1.0)
    }

    func testIntervalMinimumIsOne() {
        let i = engine.interval(stability: 0.01)
        XCTAssertGreaterThanOrEqual(i, 1)
    }

    func testIntervalMaximum() {
        let i = engine.interval(stability: 100000.0)
        XCTAssertLessThanOrEqual(i, FSRSEngine.maximumInterval)
    }

    func testIntervalEdgeCases() {
        XCTAssertEqual(engine.interval(stability: 0), 1)
        XCTAssertEqual(engine.interval(stability: 1, retention: 0), 1)
        XCTAssertEqual(engine.interval(stability: 1, retention: 1), 1)
    }

    // MARK: - Schedule: New Card

    func testScheduleNewCardGoodGoesToReview() {
        let result = engine.schedule(
            stability: 0, difficulty: 0,
            cardState: .new, elapsedDays: 0,
            rating: .good
        )
        XCTAssertEqual(result.state, .review)
        XCTAssertGreaterThan(result.stability, 0)
        XCTAssertGreaterThanOrEqual(result.interval, 1)
    }

    func testScheduleNewCardAgainGoesToLearning() {
        let result = engine.schedule(
            stability: 0, difficulty: 0,
            cardState: .new, elapsedDays: 0,
            rating: .again
        )
        XCTAssertEqual(result.state, .learning)
        XCTAssertEqual(result.interval, 1)
    }

    func testScheduleNewCardHardGoesToLearning() {
        let result = engine.schedule(
            stability: 0, difficulty: 0,
            cardState: .new, elapsedDays: 0,
            rating: .hard
        )
        XCTAssertEqual(result.state, .learning)
    }

    func testScheduleNewCardEasyGoesToReview() {
        let result = engine.schedule(
            stability: 0, difficulty: 0,
            cardState: .new, elapsedDays: 0,
            rating: .easy
        )
        XCTAssertEqual(result.state, .review)
    }

    func testScheduleNewCardSetsInitialStabilityAndDifficulty() {
        let result = engine.schedule(
            stability: 0, difficulty: 0,
            cardState: .new, elapsedDays: 0,
            rating: .good
        )
        let expectedS = engine.initialStability(rating: .good)
        let expectedD = engine.initialDifficulty(rating: .good)
        XCTAssertEqual(result.stability, expectedS, accuracy: 1e-10)
        XCTAssertEqual(result.difficulty, expectedD, accuracy: 1e-10)
    }

    // MARK: - Schedule: Learning/Relearning

    func testScheduleLearningGoodSameDayGoesToReview() {
        let result = engine.schedule(
            stability: 3.0, difficulty: 5.0,
            cardState: .learning, elapsedDays: 0,
            rating: .good
        )
        XCTAssertEqual(result.state, .review)
    }

    func testScheduleLearningAgainSameDayGoesToRelearning() {
        let result = engine.schedule(
            stability: 3.0, difficulty: 5.0,
            cardState: .learning, elapsedDays: 0,
            rating: .again
        )
        XCTAssertEqual(result.state, .relearning)
    }

    func testScheduleRelearningGoodSameDayGoesToReview() {
        let result = engine.schedule(
            stability: 3.0, difficulty: 5.0,
            cardState: .relearning, elapsedDays: 0,
            rating: .good
        )
        XCTAssertEqual(result.state, .review)
    }

    func testScheduleLearningMultiDayGoodGoesToReview() {
        let result = engine.schedule(
            stability: 3.0, difficulty: 5.0,
            cardState: .learning, elapsedDays: 3,
            rating: .good
        )
        XCTAssertEqual(result.state, .review)
        XCTAssertGreaterThan(result.stability, 0)
    }

    func testScheduleLearningMultiDayAgainGoesToRelearning() {
        let result = engine.schedule(
            stability: 3.0, difficulty: 5.0,
            cardState: .learning, elapsedDays: 3,
            rating: .again
        )
        XCTAssertEqual(result.state, .relearning)
    }

    // MARK: - Schedule: Review

    func testScheduleReviewGoodStaysInReview() {
        let result = engine.schedule(
            stability: 10.0, difficulty: 5.0,
            cardState: .review, elapsedDays: 10,
            rating: .good
        )
        XCTAssertEqual(result.state, .review)
        XCTAssertGreaterThan(result.stability, 10.0)
    }

    func testScheduleReviewAgainGoesToRelearning() {
        let result = engine.schedule(
            stability: 10.0, difficulty: 5.0,
            cardState: .review, elapsedDays: 10,
            rating: .again
        )
        XCTAssertEqual(result.state, .relearning)
        XCTAssertLessThan(result.stability, 10.0)
    }

    func testScheduleReviewEasyLongerIntervalThanGood() {
        let good = engine.schedule(
            stability: 10.0, difficulty: 5.0,
            cardState: .review, elapsedDays: 10,
            rating: .good
        )
        let easy = engine.schedule(
            stability: 10.0, difficulty: 5.0,
            cardState: .review, elapsedDays: 10,
            rating: .easy
        )
        XCTAssertGreaterThan(easy.interval, good.interval)
    }

    func testScheduleReviewHardShorterIntervalThanGood() {
        let hard = engine.schedule(
            stability: 10.0, difficulty: 5.0,
            cardState: .review, elapsedDays: 10,
            rating: .hard
        )
        let good = engine.schedule(
            stability: 10.0, difficulty: 5.0,
            cardState: .review, elapsedDays: 10,
            rating: .good
        )
        XCTAssertLessThan(hard.interval, good.interval)
    }

    func testScheduleReviewSameDayGoodStaysInReview() {
        let result = engine.schedule(
            stability: 10.0, difficulty: 5.0,
            cardState: .review, elapsedDays: 0,
            rating: .good
        )
        XCTAssertEqual(result.state, .review)
    }

    func testScheduleReviewSameDayAgainGoesToRelearning() {
        let result = engine.schedule(
            stability: 10.0, difficulty: 5.0,
            cardState: .review, elapsedDays: 0,
            rating: .again
        )
        XCTAssertEqual(result.state, .relearning)
    }

    // MARK: - Due Date

    func testDueDateIsInFuture() {
        let now = Date()
        let result = engine.schedule(
            stability: 0, difficulty: 0,
            cardState: .new, elapsedDays: 0,
            rating: .good, now: now
        )
        XCTAssertGreaterThan(result.dueDate, now)
    }

    func testDueDateMatchesInterval() {
        let now = Date()
        let result = engine.schedule(
            stability: 10.0, difficulty: 5.0,
            cardState: .review, elapsedDays: 10,
            rating: .good, now: now
        )
        let expected = Calendar.current.date(byAdding: .day, value: result.interval, to: now)!
        XCTAssertEqual(
            Calendar.current.startOfDay(for: result.dueDate),
            Calendar.current.startOfDay(for: expected)
        )
    }

    // MARK: - Mastery Threshold

    func testMasteryThreshold() {
        XCTAssertEqual(FSRSEngine.masteryThreshold, 21.0)
    }

    // MARK: - FSRS v5 Specific: newD Passed to Stability Functions

    func testScheduleReviewUsesNewDifficultyForStability() {
        // Verify that scheduling a review card uses the updated difficulty
        // (not the old one) when computing new stability.
        // We do this by comparing with manual computation.
        let s = 10.0
        let d = 5.0
        let t = 10
        let rating = Rating.good

        let result = engine.schedule(
            stability: s, difficulty: d,
            cardState: .review, elapsedDays: t,
            rating: rating
        )

        // Manual computation following the code path
        let r = engine.retrievability(elapsedDays: Double(t), stability: s)
        let newD = engine.nextDifficulty(current: d, rating: rating)
        let expectedS = engine.stabilityAfterSuccess(
            difficulty: newD, stability: s, retrievability: r, rating: rating
        )

        XCTAssertEqual(result.stability, expectedS, accuracy: 1e-10)
        XCTAssertEqual(result.difficulty, newD, accuracy: 1e-10)
    }

    func testScheduleLearningMultiDayUsesNewDifficultyForStability() {
        let s = 3.0
        let d = 5.0
        let t = 3
        let rating = Rating.good

        let result = engine.schedule(
            stability: s, difficulty: d,
            cardState: .learning, elapsedDays: t,
            rating: rating
        )

        let r = engine.retrievability(elapsedDays: Double(t), stability: s)
        let newD = engine.nextDifficulty(current: d, rating: rating)
        let expectedS = engine.stabilityAfterSuccess(
            difficulty: newD, stability: s, retrievability: r, rating: rating
        )

        XCTAssertEqual(result.stability, expectedS, accuracy: 1e-10)
        XCTAssertEqual(result.difficulty, newD, accuracy: 1e-10)
    }
}
