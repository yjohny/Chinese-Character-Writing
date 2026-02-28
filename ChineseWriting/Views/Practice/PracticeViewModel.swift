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

    // Practice stats (running totals for current practice)
    var correctCount = 0
    var incorrectCount = 0
    var totalCount = 0

    // MARK: - Dependencies

    let sessionManager: SessionManager
    let ttsService: TTSService
    let characterData: CharacterDataService
    private let recognitionService = RecognitionService()

    /// Tracks in-flight async work (recognition, delayed transitions) so it can be
    /// cancelled when the user ends the session or moves to the next card.
    private var pendingTask: Task<Void, Never>?

    var useTraditional: Bool {
        sessionManager.fetchProfile()?.useTraditional ?? false
    }

    init(sessionManager: SessionManager, ttsService: TTSService, characterData: CharacterDataService) {
        self.sessionManager = sessionManager
        self.ttsService = ttsService
        self.characterData = characterData
    }

    // MARK: - Actions

    /// Auto-start practice when the view appears. Loads the first card if idle.
    func beginIfNeeded() {
        guard studyState == .idle else { return }
        correctCount = 0
        incorrectCount = 0
        totalCount = 0
        loadNextCard()
    }

    /// User taps "Done" to end practice early.
    func endPractice() {
        pendingTask?.cancel()
        pendingTask = nil
        ttsService.stop()
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
            studyState = .writing
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
                self.studyState = .writing
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
        guard studyState == .writing || studyState == .recognizing else { return }
        pendingTask?.cancel()
        pendingTask = nil
        isRecognizing = false
        handleCorrect(wasOverride: true, visionConfidence: 0)
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
                sessionManager.rateCard(card, rating: .again)
                incorrectCount += 1
                totalCount += 1
                triggerHaptic(success: true)

                pendingTask = Task {
                    try? await Task.sleep(for: .seconds(0.8))
                    guard !Task.isCancelled else { return }
                    loadNextCard()
                }
            } else {
                // Not quite right — encourage them to try again
                rewriteFeedback = "Almost! Try again"
                rewriteDrawing = PKDrawing()
                triggerHaptic(success: false)
            }
        }
    }

    // MARK: - Private

    private func handleCorrect(wasOverride: Bool, visionConfidence: Double) {
        studyState = .correct
        showCelebration = true
        triggerHaptic(success: true)

        guard let card = currentCard else { return }
        sessionManager.rateCard(
            card, rating: .good,
            wasOverride: wasOverride,
            visionConfidence: visionConfidence
        )
        correctCount += 1
        totalCount += 1

        pendingTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            loadNextCard()
        }
    }

    private func handleIncorrect() {
        studyState = .incorrect
        triggerHaptic(success: false)

        // Load stroke data for animation
        if let entry = currentEntry {
            currentStrokeData = characterData.strokeData(for: entry.simplified)
        }

        pendingTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
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

        if let (card, entry) = sessionManager.nextCard() {
            currentCard = card
            currentEntry = entry
            currentStrokeData = characterData.strokeData(for: entry.simplified)
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

    private func triggerHaptic(success: Bool) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(success ? .success : .error)
    }
}
