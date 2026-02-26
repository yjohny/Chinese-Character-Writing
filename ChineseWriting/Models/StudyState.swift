import Foundation

/// State machine for a single character within a study session.
enum StudyState: Equatable {
    case idle                       // No active session
    case presenting                 // TTS playing, prompt showing
    case writing                    // User is drawing on canvas
    case recognizing                // Vision processing the drawing
    case correct                    // Recognized correctly, celebration
    case incorrect                  // Recognized incorrectly
    case showingStrokeOrder         // Animating correct strokes after miss
    case tracing                    // User traces over ghost character
    case rewriting                  // Free-write retry after tracing
    case sessionComplete            // No more cards to review today
}

/// FSRS card lifecycle state.
enum CardState: Int, Codable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

/// FSRS review rating.
enum Rating: Int, Codable, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}
