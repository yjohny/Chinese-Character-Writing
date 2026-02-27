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

        // VNImageRequestHandler.perform() is synchronous — the completion handler
        // runs inline during perform(), so there is no threading concern between
        // the handler and the catch block. We capture the result and resume once.
        return await withCheckedContinuation { continuation in
            var result: RecognitionResult?

            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      error == nil else {
                    result = .failed
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

                result = RecognitionResult(
                    recognizedCharacter: topCandidate?.0,
                    confidence: topCandidate?.1 ?? 0,
                    allCandidates: allCandidates,
                    isCorrect: matchFound
                )
            }

            let langCode = traditional ? "zh-Hant" : "zh-Hans"
            request.recognitionLanguages = [langCode]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.customWords = [expected]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("⚠️ Vision perform() failed: \(error)")
            }

            continuation.resume(returning: result ?? .failed)
        }
    }

    /// Render PKDrawing to a UIImage suitable for Vision recognition.
    /// White background, black strokes, square 512×512, scaled to fill.
    private func renderDrawing(_ drawing: PKDrawing) -> UIImage {
        let bounds = drawing.bounds
        guard bounds.width > 0, bounds.height > 0 else {
            return UIImage()
        }

        let imageSize: CGFloat = 512
        let padding: CGFloat = 40
        let available = imageSize - padding * 2 // 432

        // Scale drawing up so the longest dimension fills the available space.
        // This prevents thin strokes (e.g. 一) from being tiny in the image.
        // Cap at 6× to avoid over-scaling very small marks.
        let scaleFactor = min(available / max(bounds.width, bounds.height), 6.0)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.preferredRange = .standard
        format.scale = 1.0 // Consistent pixel dimensions across devices
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: imageSize, height: imageSize), format: format
        )
        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: imageSize, height: imageSize)))

            let scaledWidth = bounds.width * scaleFactor
            let scaledHeight = bounds.height * scaleFactor
            let destRect = CGRect(
                x: (imageSize - scaledWidth) / 2,
                y: (imageSize - scaledHeight) / 2,
                width: scaledWidth,
                height: scaledHeight
            )

            // Force light-mode trait collection so PencilKit renders "black"
            // ink as actual black. Without this, dark mode causes adaptive ink
            // colours to flip, producing invisible white-on-white strokes.
            let lightTraits = UITraitCollection(userInterfaceStyle: .light)
            lightTraits.performAsCurrent {
                let drawingImage = drawing.image(from: bounds, scale: 2.0)
                drawingImage.draw(in: destRect)
            }
        }
    }
}
