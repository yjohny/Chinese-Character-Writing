import SwiftUI

/// Animates stroke-by-stroke rendering of a character after a miss.
/// Each stroke draws in sequence, with the current stroke animating in red.
struct StrokeOrderView: View {
    let strokeData: StrokeData
    var onComplete: (() -> Void)?
    var size: CGFloat = 280
    /// Animation speed: 0 = slow, 1 = normal, 2 = fast.
    var animationSpeed: Int = 1

    private var strokeDuration: Double {
        switch animationSpeed {
        case 0: return 0.8   // slow
        case 2: return 0.3   // fast
        default: return 0.5  // normal
        }
    }
    private var strokeDelay: Double {
        switch animationSpeed {
        case 0: return 850   // slow (ms)
        case 2: return 350   // fast (ms)
        default: return 550  // normal (ms)
        }
    }

    @State private var completedStrokes = 0
    @State private var currentStrokeProgress: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?

    private var totalStrokes: Int { strokeData.strokes.count }

    var body: some View {
        let paths = StrokeRenderer.allStrokes(from: strokeData)
        let scale = size / StrokeRenderer.canvasSize

        VStack(spacing: 16) {
            Text("Stroke Order")
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                // Guide grid
                guideGrid

                // Completed strokes (black/filled)
                ForEach(0..<completedStrokes, id: \.self) { i in
                    if i < paths.count {
                        paths[i]
                            .fill(Color.primary)
                            .scaleEffect(scale, anchor: .topLeading)
                    }
                }

                // Current stroke animating (red, filled via median reveal)
                if completedStrokes < paths.count {
                    paths[completedStrokes]
                        .fill(Color.red)
                        .scaleEffect(scale, anchor: .topLeading)
                        .mask(
                            medianPath(for: completedStrokes)
                                .trim(from: 0, to: currentStrokeProgress)
                                .stroke(style: StrokeStyle(lineWidth: 150, lineCap: .round, lineJoin: .round))
                                .scaleEffect(scale, anchor: .topLeading)
                        )
                }

                // Stroke number labels
                ForEach(0..<totalStrokes, id: \.self) { i in
                    if i < completedStrokes {
                        strokeNumberLabel(i, scale: scale)
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
            .contentShape(Rectangle())
            .onTapGesture { skipAnimation() }

            if completedStrokes < totalStrokes {
                Text("Stroke \(completedStrokes + 1) of \(totalStrokes) — tap to skip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("All \(totalStrokes) strokes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { startAnimation() }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
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

    private func strokeNumberLabel(_ index: Int, scale: CGFloat) -> some View {
        let medians = StrokeRenderer.medianPoints(from: strokeData, strokeIndex: index)
        let point = medians.first ?? .zero
        let scaled = CGPoint(x: point.x * scale, y: point.y * scale)

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

    /// Tap to instantly complete the animation and advance.
    private func skipAnimation() {
        animationTask?.cancel()
        animationTask = nil
        completedStrokes = totalStrokes
        currentStrokeProgress = 0
        onComplete?()
    }

    private func startAnimation() {
        // Reset state for fresh animation
        completedStrokes = 0
        currentStrokeProgress = 0
        animationTask?.cancel()

        animationTask = Task { @MainActor in
            for stroke in 0..<totalStrokes {
                guard !Task.isCancelled else { return }

                currentStrokeProgress = 0
                withAnimation(.easeInOut(duration: strokeDuration)) {
                    currentStrokeProgress = 1.0
                }

                try? await Task.sleep(for: .milliseconds(Int(strokeDelay)))
                guard !Task.isCancelled else { return }

                completedStrokes = stroke + 1
                currentStrokeProgress = 0
            }

            // All strokes done — brief pause then notify completion
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            onComplete?()
        }
    }
}
