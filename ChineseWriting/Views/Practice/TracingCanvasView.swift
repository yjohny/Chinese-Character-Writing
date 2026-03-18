import SwiftUI
import PencilKit

/// Shows a ghost character at low opacity with a drawing canvas overlaid for tracing.
struct TracingCanvasView: View {
    let strokeData: StrokeData
    @Binding var drawing: PKDrawing
    var onComplete: (() -> Void)?
    var size: CGFloat = 300

    private var displayScale: CGFloat { size / StrokeRenderer.canvasSize }

    var body: some View {
        let paths = StrokeRenderer.allStrokes(from: strokeData)

        VStack(spacing: 16) {
            Text("Trace the character")
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                // Guide grid
                guideGrid

                // Ghost character at low opacity
                ForEach(0..<paths.count, id: \.self) { i in
                    paths[i]
                        .fill(Color.gray.opacity(0.15))
                        .scaleEffect(displayScale, anchor: .topLeading)
                }

                // Tracing canvas
                WritingCanvasView(drawing: $drawing, onSubmit: onComplete)
            }
            .frame(width: size, height: size)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tracing canvas with guide character")
            .accessibilityHint("Trace over the gray character with your finger or Apple Pencil")
            .accessibilityAddTraits(.allowsDirectInteraction)

            Text("Trace over the gray character")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var guideGrid: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            context.stroke(Path(rect.insetBy(dx: 1, dy: 1)),
                           with: .color(.gray.opacity(0.3)), lineWidth: 1)

            var hPath = Path()
            hPath.move(to: CGPoint(x: 0, y: canvasSize.height / 2))
            hPath.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height / 2))
            context.stroke(hPath, with: .color(.gray.opacity(0.15)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [6, 4]))

            var vPath = Path()
            vPath.move(to: CGPoint(x: canvasSize.width / 2, y: 0))
            vPath.addLine(to: CGPoint(x: canvasSize.width / 2, y: canvasSize.height))
            context.stroke(vPath, with: .color(.gray.opacity(0.15)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [6, 4]))
        }
    }
}
