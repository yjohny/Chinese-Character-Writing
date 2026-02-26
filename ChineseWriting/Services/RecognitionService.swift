import Vision
import PencilKit
import UIKit

/// Result of attempting to recognize a handwritten character.
struct RecognitionResult {
    let recognizedCharacter: String?
    let confidence: Double
    let allCandidates: [(String, Double)]
    let isCorrect: Bool

    static let failed = RecognitionResult(
        recognizedCharacter: nil, confidence: 0,
        allCandidates: [], isCorrect: false
    )
}

/// Converts a PKDrawing into a recognized Chinese character via the Vision framework.
final class RecognitionService {
    static let confidenceThreshold: Double = 0.15
    static let maxCandidates: Int = 10

    /// Recognize a handwritten character from a PencilKit drawing.
    func recognize(
        drawing: PKDrawing,
        expected: String,
        traditional: Bool
    ) async -> RecognitionResult {
        let image = renderDrawing(drawing)
        guard let cgImage = image.cgImage else { return .failed }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      error == nil else {
                    continuation.resume(returning: .failed)
                    return
                }

                var allCandidates: [(String, Double)] = []
                for observation in observations {
                    let topCandidates = observation.topCandidates(Self.maxCandidates)
                    for candidate in topCandidates {
                        for char in candidate.string {
                            allCandidates.append((String(char), Double(candidate.confidence)))
                        }
                    }
                }

                // Check if expected character appears in any candidate
                let matchFound = allCandidates.contains { $0.0 == expected && $0.1 >= Self.confidenceThreshold }
                let topCandidate = allCandidates.first

                continuation.resume(returning: RecognitionResult(
                    recognizedCharacter: topCandidate?.0,
                    confidence: topCandidate?.1 ?? 0,
                    allCandidates: allCandidates,
                    isCorrect: matchFound
                ))
            }

            let langCode = traditional ? "zh-Hant" : "zh-Hans"
            request.recognitionLanguages = [langCode]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: .failed)
            }
        }
    }

    /// Render PKDrawing to a UIImage suitable for Vision recognition.
    /// White background, black strokes, square, centered, minimum 512x512.
    private func renderDrawing(_ drawing: PKDrawing) -> UIImage {
        let bounds = drawing.bounds
        guard bounds.width > 0, bounds.height > 0 else {
            return UIImage()
        }

        let padding: CGFloat = 40
        let contentSize = max(bounds.width, bounds.height) + padding * 2
        let size = max(contentSize, 512)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: size, height: size)))

            // Center the drawing
            let offsetX = (size - bounds.width) / 2 - bounds.origin.x
            let offsetY = (size - bounds.height) / 2 - bounds.origin.y

            context.cgContext.translateBy(x: offsetX, y: offsetY)

            let drawingImage = drawing.image(from: bounds, scale: 2.0)
            drawingImage.draw(in: bounds)
        }
    }
}
