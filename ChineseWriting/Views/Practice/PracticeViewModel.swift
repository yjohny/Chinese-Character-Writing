import SwiftUI
import PencilKit
import Observation

/// Drives the study session state machine. Orchestrates all services.
@MainActor
@Observable
final class PracticeViewModel {
    // MARK: - State

    var studyState: StudyState = .idle
    var currentEntry: CharacterEntry?
    var currentCard: ReviewCard?
    var currentStrokeData: StrokeData?

    /// Canvas frame size — set by PracticeView, used for stroke matching normalization.
    var canvasSize: CGFloat = 300

    var writingDrawing = PKDrawing()
    var tracingDrawing = PKDrawing()
    var rewriteDrawing = PKDrawing()

    var showCelebration = false
    var recognizedChar: String?
    var isRecognizing = false
    var rewriteFeedback: String?

    /// When true, stroke order review was triggered from the correct screen
    /// (optional review), so we advance to the next card instead of tracing.
    var isReviewingAfterCorrect = false

    /// Tracks consecutive failed rewrite attempts so we can offer an escape hatch.
    var rewriteAttempts = 0

    /// Whether the user has drawn enough strokes to qualify for the "I got it right" override.
    /// Requires at least half the expected stroke count (minimum 2) to prevent gaming.
    var hasDrawnEnoughForOverride: Bool {
        let drawnCount = writingDrawing.strokes.count
        if let strokeData = currentStrokeData {
            let minimum = max(2, strokeData.strokes.count / 2)
            return drawnCount >= minimum
        }
        return drawnCount >= 2
    }

    // Practice stats (running totals for current practice)
    var correctCount = 0
    var incorrectCount = 0
    var totalCount = 0

    /// Triggers the daily goal completion celebration overlay.
    var showDailyGoalComplete = false

    /// When non-nil, shows the milestone celebration overlay.
    var activeMilestone: MilestoneType?

    // MARK: - Dependencies

    let sessionManager: SessionManager
    let ttsService: TTSService
    let characterData: CharacterDataService
    let soundService: SoundService
    private let recognitionService = RecognitionService()
    private let hapticGenerator = UINotificationFeedbackGenerator()

    /// Tracks in-flight async work (recognition, delayed transitions) so it can be
    /// cancelled when the user ends the session or moves to the next card.
    private var pendingTask: Task<Void, Never>?

    var useTraditional: Bool {
        sessionManager.fetchProfile()?.useTraditional ?? false
    }

    init(sessionManager: SessionManager, ttsService: TTSService, characterData: CharacterDataService, soundService: SoundService) {
        self.sessionManager = sessionManager
        self.ttsService = ttsService
        self.characterData = characterData
        self.soundService = soundService
    }

    // MARK: - Actions

    /// Auto-start practice when the view appears. Loads the first card if idle.
    func beginIfNeeded() {
        guard studyState == .idle else { return }
        correctCount = 0
        incorrectCount = 0
        totalCount = 0
        soundService.isEnabled = sessionManager.fetchProfile()?.soundEffectsEnabled ?? true
        loadNextCard()
    }

    /// User taps "Done" to end practice early.
    func endPractice() {
        pendingTask?.cancel()
        pendingTask = nil
        ttsService.stop()
        isRecognizing = false
        isReviewingAfterCorrect = false
        rewriteAttempts = 0
        showCelebration = false
        showDailyGoalComplete = false
        activeMilestone = nil
        studyState = .sessionComplete
    }

    /// Start practicing again (from the completion screen).
    func practiceMore() {
        pendingTask?.cancel()
        pendingTask = nil
        correctCount = 0
        incorrectCount = 0
        totalCount = 0
        loadNextCard()
    }

    /// Called when the app returns to the foreground. Unsticks state that
    /// depends on callbacks that the system may have swallowed while backgrounded
    /// (e.g. TTS completion that transitions presenting → writing).
    func handleReturnToForeground() {
        if studyState == .presenting {
            transitionToWriting()
        }
    }

    func playTTS() {
        guard let entry = currentEntry else { return }
        let ttsText: String
        if let example = entry.exampleWords.first {
            ttsText = example.ttsText
        } else {
            ttsText = entry.simplified
        }
        ttsService.speak(ttsText, traditional: useTraditional) { [weak self] in
            guard let self else { return }
            if self.studyState == .presenting {
                self.transitionToWriting()
            }
        }
    }

    /// Transition from presenting to writing. If the user drew strokes during
    /// TTS playback, schedule an auto-submit so they don't have to manually tap Check.
    private func transitionToWriting() {
        studyState = .writing
        if !writingDrawing.strokes.isEmpty {
            pendingTask?.cancel()
            pendingTask = Task {
                try? await Task.sleep(for: .seconds(WritingCanvasView.idleTimeout))
                guard !Task.isCancelled, studyState == .writing else { return }
                submitWriting()
            }
        }
    }

    func submitWriting() {
        guard studyState == .writing, !writingDrawing.strokes.isEmpty else { return }
        studyState = .recognizing
        isRecognizing = true

        pendingTask?.cancel()
        pendingTask = Task {
            guard let entry = currentEntry else { return }
            let expected = useTraditional ? entry.traditional : entry.simplified
            let result = await recognitionService.recognize(
                drawing: writingDrawing,
                expected: expected,
                traditional: useTraditional,
                strokeData: currentStrokeData,
                canvasSize: canvasSize,
                gradeLevel: entry.gradeLevel
            )

            guard !Task.isCancelled, studyState == .recognizing else { return }

            isRecognizing = false
            recognizedChar = result.recognizedCharacter

            if result.isCorrect {
                handleCorrect(wasOverride: false, visionConfidence: result.confidence)
            } else {
                handleIncorrect()
            }
        }
    }

    func overrideCorrect() {
        if studyState == .recognizing || studyState == .incorrect {
            pendingTask?.cancel()
            pendingTask = nil
            isRecognizing = false
            handleCorrect(wasOverride: true, visionConfidence: 0)
        } else if studyState == .rewriting {
            // Override during rewrite — recognition misidentified valid handwriting.
            // Treat as successful rewrite: rate as .again (they needed help) and advance.
            pendingTask?.cancel()
            pendingTask = nil
            isRecognizing = false
            rewriteFeedback = nil

            guard let card = currentCard else { return }
            sessionManager.rateCard(card, rating: .again)
            incorrectCount += 1
            totalCount += 1
            rewriteAttempts = 0
            triggerHaptic(success: true)
            soundService.play(.correct)
            checkDailyGoalAndMilestones()

            pendingTask = Task {
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }
                loadNextCard()
            }
        }
    }

    /// User taps "Show me" — they don't know this character.
    /// Treats it as incorrect and enters the stroke review flow.
    func skipAsUnknown() {
        guard studyState == .writing else { return }
        pendingTask?.cancel()
        pendingTask = nil
        isRecognizing = false
        handleIncorrect()
    }

    func clearCanvas() {
        switch studyState {
        case .writing:
            writingDrawing = PKDrawing()
        case .rewriting:
            rewriteDrawing = PKDrawing()
        case .tracing:
            tracingDrawing = PKDrawing()
        default:
            break
        }
    }

    /// User taps "Review Strokes" on the correct screen to optionally review stroke order.
    func reviewStrokeOrder() {
        guard studyState == .correct, currentStrokeData != nil else { return }
        pendingTask?.cancel()
        pendingTask = nil
        isReviewingAfterCorrect = true
        studyState = .showingStrokeOrder
    }

    func strokeOrderComplete() {
        if isReviewingAfterCorrect {
            isReviewingAfterCorrect = false
            loadNextCard()
        } else {
            studyState = .tracing
            tracingDrawing = PKDrawing()
        }
    }

    func tracingComplete() {
        studyState = .rewriting
        rewriteDrawing = PKDrawing()
        rewriteFeedback = nil
        rewriteAttempts = 0
    }

    /// User taps "Show strokes again" after multiple failed rewrite attempts.
    /// Re-enters stroke order animation → tracing → rewriting flow.
    func showStrokesAgain() {
        guard studyState == .rewriting, currentStrokeData != nil else { return }
        pendingTask?.cancel()
        pendingTask = nil
        rewriteFeedback = nil
        rewriteAttempts = 0
        studyState = .showingStrokeOrder
    }

    func submitRewrite() {
        guard studyState == .rewriting, !rewriteDrawing.strokes.isEmpty else { return }

        // Recognize the rewrite to verify the user wrote the character correctly
        isRecognizing = true

        pendingTask?.cancel()
        pendingTask = Task {
            guard let entry = currentEntry, let card = currentCard else { return }
            let expected = useTraditional ? entry.traditional : entry.simplified
            let result = await recognitionService.recognize(
                drawing: rewriteDrawing,
                expected: expected,
                traditional: useTraditional,
                strokeData: currentStrokeData,
                canvasSize: canvasSize,
                gradeLevel: entry.gradeLevel
            )

            guard !Task.isCancelled, studyState == .rewriting else { return }

            isRecognizing = false

            if result.isCorrect {
                // They wrote it correctly after review — rate as "again" since they
                // needed help, but let them move on
                rewriteFeedback = nil
                rewriteAttempts = 0
                sessionManager.rateCard(card, rating: .again)
                incorrectCount += 1
                totalCount += 1
                triggerHaptic(success: true)
                soundService.play(.correct)
                checkDailyGoalAndMilestones()

                pendingTask = Task {
                    try? await Task.sleep(for: .seconds(0.8))
                    guard !Task.isCancelled else { return }
                    loadNextCard()
                }
            } else {
                // Not quite right — encourage them to try again
                rewriteAttempts += 1
                rewriteFeedback = "Almost! Try again"
                rewriteDrawing = PKDrawing()
                triggerHaptic(success: false)
                soundService.play(.incorrect)
            }
        }
    }

    // MARK: - Private

    private func handleCorrect(wasOverride: Bool, visionConfidence: Double) {
        studyState = .correct
        showCelebration = true
        triggerHaptic(success: true)
        soundService.play(.correct)

        guard let card = currentCard else { return }
        sessionManager.rateCard(
            card, rating: .good,
            wasOverride: wasOverride,
            visionConfidence: visionConfidence
        )
        correctCount += 1
        totalCount += 1
        checkDailyGoalAndMilestones()
        prefetchNextStrokeData()

        pendingTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            loadNextCard()
        }
    }

    private func handleIncorrect() {
        studyState = .incorrect
        triggerHaptic(success: false)
        soundService.play(.incorrect)

        // Load stroke data for animation
        if let entry = currentEntry {
            currentStrokeData = resolveStrokeData(for: entry)
        }
        prefetchNextStrokeData()

        pendingTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            if currentStrokeData != nil {
                studyState = .showingStrokeOrder
            } else {
                // No stroke data available — skip to rewriting
                studyState = .rewriting
                rewriteDrawing = PKDrawing()
            }
        }
    }

    private func loadNextCard() {
        pendingTask?.cancel()
        pendingTask = nil
        ttsService.stop()
        isRecognizing = false
        isReviewingAfterCorrect = false
        rewriteAttempts = 0
        showCelebration = false
        showDailyGoalComplete = false
        activeMilestone = nil

        if let (card, entry) = sessionManager.nextCard() {
            currentCard = card
            currentEntry = entry
            currentStrokeData = resolveStrokeData(for: entry)
            writingDrawing = PKDrawing()
            tracingDrawing = PKDrawing()
            rewriteDrawing = PKDrawing()
            recognizedChar = nil
            rewriteFeedback = nil
            studyState = .presenting
            playTTS()
        } else {
            studyState = .sessionComplete
        }
    }

    /// Resolves stroke data for the current character, accounting for traditional mode.
    /// When the traditional form differs from simplified, stroke data (which is
    /// simplified-only from Make Me a Hanzi) would be wrong — return nil so
    /// recognition falls through to Vision OCR, which handles traditional correctly.
    private func resolveStrokeData(for entry: CharacterEntry) -> StrokeData? {
        if useTraditional && entry.simplified != entry.traditional {
            return nil
        }
        return characterData.strokeData(for: entry.simplified)
    }

    /// Pre-decode the next card's stroke data while the user views the result screen,
    /// so loadNextCard() doesn't pay the JSON decode cost.
    private func prefetchNextStrokeData() {
        if let (_, entry) = sessionManager.peekNextCard() {
            _ = characterData.strokeData(for: entry.simplified)
        }
    }

    /// Check if the daily goal was just reached or a milestone was achieved.
    private func checkDailyGoalAndMilestones() {
        if sessionManager.dailyGoalReached {
            showDailyGoalComplete = true
            soundService.play(.dailyGoal)
        }
        if let milestone = sessionManager.checkForNewMilestones() {
            activeMilestone = milestone
            soundService.play(.milestone)
        }
    }

    private func triggerHaptic(success: Bool) {
        hapticGenerator.notificationOccurred(success ? .success : .error)
        hapticGenerator.prepare()
    }
}
