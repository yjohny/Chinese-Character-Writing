import SwiftUI

/// Animates stroke-by-stroke rendering of a character after a miss.
/// Each stroke draws in sequence, with the current stroke animating in red.
struct StrokeOrderView: View {
    let strokeData: StrokeData
    var onComplete: (() -> Void)?
    var size: CGFloat = 280

    @State private var completedStrokes = 0
    @State private var currentStrokeProgress: CGFloat = 0
    @State private var animating = false

    private var totalStrokes: Int { strokeData.strokes.count }
    private var allPaths: [Path] { StrokeRenderer.allStrokes(from: strokeData) }
    private let scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 16) {
            Text("Stroke Order")
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                // Guide grid
                guideGrid

                // Completed strokes (black/filled)
                ForEach(0..<completedStrokes, id: \.self) { i in
                    if i < allPaths.count {
                        allPaths[i]
                            .fill(Color.primary)
                            .scaleEffect(displayScale, anchor: .topLeading)
                    }
                }

                // Current stroke animating (red, filled via median reveal)
                if completedStrokes < allPaths.count {
                    allPaths[completedStrokes]
                        .fill(Color.red)
                        .scaleEffect(displayScale, anchor: .topLeading)
                        .mask(
                            medianPath(for: completedStrokes)
                                .trim(from: 0, to: currentStrokeProgress)
                                .stroke(style: StrokeStyle(lineWidth: 150, lineCap: .round, lineJoin: .round))
                                .scaleEffect(displayScale, anchor: .topLeading)
                        )
                }

                // Stroke number labels
                ForEach(0..<totalStrokes, id: \.self) { i in
                    if i < completedStrokes {
                        strokeNumberLabel(i)
                    }
                }
            }
            .frame(width: size, height: size)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )

            Text("Stroke \(min(completedStrokes + 1, totalStrokes)) of \(totalStrokes)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { startAnimation() }
    }

    private var displayScale: CGFloat {
        size / StrokeRenderer.canvasSize
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

    private func strokeNumberLabel(_ index: Int) -> some View {
        let medians = StrokeRenderer.medianPoints(from: strokeData, strokeIndex: index)
        let point = medians.first ?? .zero
        let scaled = CGPoint(x: point.x * displayScale, y: point.y * displayScale)

        return Text("\(index + 1)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.red.opacity(0.7))
            .position(scaled)
    }

    /// Builds a path along the median (center line) of a stroke for use as a reveal mask.
    private func medianPath(for strokeIndex: Int) -> Path {
        let points = StrokeRenderer.medianPoints(from: strokeData, strokeIndex: strokeIndex)
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func startAnimation() {
        guard !animating else { return }
        animating = true
        animateNextStroke()
    }

    private func animateNextStroke() {
        guard completedStrokes < totalStrokes else {
            // All strokes done
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete?()
            }
            return
        }

        currentStrokeProgress = 0
        withAnimation(.easeInOut(duration: 0.6)) {
            currentStrokeProgress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            completedStrokes += 1
            currentStrokeProgress = 0
            animateNextStroke()
        }
    }
}
