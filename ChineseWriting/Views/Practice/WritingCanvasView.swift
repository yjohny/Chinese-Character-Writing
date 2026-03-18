import SwiftUI
import PencilKit

/// UIViewRepresentable wrapping PKCanvasView for handwriting input.
/// Supports both finger and Apple Pencil. Detects idle after drawing stops.
struct WritingCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var onSubmit: (() -> Void)?
    var showGuideGrid: Bool = true
    var onUndoAvailabilityChanged: ((Bool) -> Void)?

    /// Idle time (seconds) after last stroke before auto-submit.
    static let idleTimeout: TimeInterval = 3.0

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 20)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        canvas.overrideUserInterfaceStyle = .light
        context.coordinator.canvasView = canvas
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: WritingCanvasView
        var idleTimer: Timer?
        weak var canvasView: PKCanvasView?

        init(parent: WritingCanvasView) {
            self.parent = parent
        }

        deinit {
            idleTimer?.invalidate()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onUndoAvailabilityChanged?(canvasView.undoManager?.canUndo ?? false)

            // Reset idle timer
            idleTimer?.invalidate()

            // Only auto-submit if there are strokes
            guard !canvasView.drawing.strokes.isEmpty else { return }

            idleTimer = Timer.scheduledTimer(
                withTimeInterval: WritingCanvasView.idleTimeout,
                repeats: false
            ) { [weak self] _ in
                self?.parent.onSubmit?()
            }
        }

        func undo() {
            canvasView?.undoManager?.undo()
        }
    }
}

/// A canvas container with guide grid lines (田字格).
struct WritingCanvasContainer: View {
    @Binding var drawing: PKDrawing
    var onSubmit: (() -> Void)?
    var onUndoAvailabilityChanged: ((Bool) -> Void)?
    var size: CGFloat = 300

    /// Provides access to the canvas coordinator for undo support.
    @State private var coordinator: WritingCanvasView.Coordinator?

    var body: some View {
        ZStack {
            // Guide grid (田字格)
            Canvas { context, canvasSize in
                let rect = CGRect(origin: .zero, size: canvasSize)

                // Outer border
                context.stroke(
                    Path(rect.insetBy(dx: 1, dy: 1)),
                    with: .color(.gray.opacity(0.4)),
                    lineWidth: 2
                )

                // Horizontal center dashed line
                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: canvasSize.height / 2))
                hPath.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height / 2))
                context.stroke(
                    hPath,
                    with: .color(.gray.opacity(0.2)),
                    style: StrokeStyle(lineWidth: 1, dash: [8, 4])
                )

                // Vertical center dashed line
                var vPath = Path()
                vPath.move(to: CGPoint(x: canvasSize.width / 2, y: 0))
                vPath.addLine(to: CGPoint(x: canvasSize.width / 2, y: canvasSize.height))
                context.stroke(
                    vPath,
                    with: .color(.gray.opacity(0.2)),
                    style: StrokeStyle(lineWidth: 1, dash: [8, 4])
                )

                // Diagonal guides
                var d1 = Path()
                d1.move(to: CGPoint(x: 0, y: 0))
                d1.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height))
                context.stroke(d1, with: .color(.gray.opacity(0.1)),
                               style: StrokeStyle(lineWidth: 0.5, dash: [8, 8]))

                var d2 = Path()
                d2.move(to: CGPoint(x: canvasSize.width, y: 0))
                d2.addLine(to: CGPoint(x: 0, y: canvasSize.height))
                context.stroke(d2, with: .color(.gray.opacity(0.1)),
                               style: StrokeStyle(lineWidth: 0.5, dash: [8, 8]))
            }

            // Drawing canvas
            WritingCanvasView(
                drawing: $drawing,
                onSubmit: onSubmit,
                onUndoAvailabilityChanged: onUndoAvailabilityChanged
            )
        }
        .frame(width: size, height: size)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
