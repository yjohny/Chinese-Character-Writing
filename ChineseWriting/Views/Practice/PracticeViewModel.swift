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

    var writingDrawing = PKDrawing()
    var tracingDrawing = PKDrawing()
    var rewriteDrawing = PKDrawing()

    var showCelebration = false
    var recognizedChar: String?
    var isRecognizing = false

    // Session stats
    var correctCount = 0
    var incorrectCount = 0
    var totalCount = 0

    // MARK: - Dependencies

    let sessionManager: SessionManager
    let ttsService: TTSService
    let characterData: CharacterDataService
    private let recognitionService = RecognitionService()

    var useTraditional: Bool {
        sessionManager.fetchProfile()?.useTraditional ?? false
    }

    init(sessionManager: SessionManager, ttsService: TTSService, characterData: CharacterDataService) {
        self.sessionManager = sessionManager
        self.ttsService = ttsService
        self.characterData = characterData
    }

    // MARK: - Actions

    func startSession() {
        correctCount = 0
        incorrectCount = 0
        totalCount = 0
        loadNextCard()
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

        Task {
            guard let entry = currentEntry else { return }
            let expected = useTraditional ? entry.traditional : entry.simplified
            let result = await recognitionService.recognize(
                drawing: writingDrawing,
                expected: expected,
                traditional: useTraditional
            )

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
        isRecognizing = false
        handleCorrect(wasOverride: true, visionConfidence: 0)
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

    func strokeOrderComplete() {
        studyState = .tracing
        tracingDrawing = PKDrawing()
    }

    func tracingComplete() {
        studyState = .rewriting
        rewriteDrawing = PKDrawing()
    }

    func submitRewrite() {
        guard studyState == .rewriting, !rewriteDrawing.strokes.isEmpty else { return }

        // Always rate as Again — the miss is recorded regardless of rewrite quality
        guard let card = currentCard else { return }
        sessionManager.rateCard(card, rating: .again)
        incorrectCount += 1
        totalCount += 1

        // Brief feedback then advance
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            loadNextCard()
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

        Task {
            try? await Task.sleep(for: .seconds(1.5))
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

        Task {
            try? await Task.sleep(for: .seconds(0.8))
            if currentStrokeData != nil {
                studyState = .showingStrokeOrder
            } else {
                // No stroke data available — skip to tracing with just the character shown
                studyState = .rewriting
                rewriteDrawing = PKDrawing()
            }
        }
    }

    private func loadNextCard() {
        if let (card, entry) = sessionManager.nextCard() {
            currentCard = card
            currentEntry = entry
            currentStrokeData = characterData.strokeData(for: entry.simplified)
            writingDrawing = PKDrawing()
            tracingDrawing = PKDrawing()
            rewriteDrawing = PKDrawing()
            recognizedChar = nil
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
