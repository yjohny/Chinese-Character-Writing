import PencilKit

/// Compares user-drawn strokes against expected character median data for recognition.
///
/// Uses the median centerline data from Make Me a Hanzi (stored in strokes.json) to check
/// whether the user drew approximately the right strokes in roughly the right positions
/// and directions. This is more reliable than Vision OCR for handwriting recognition,
/// especially for simple characters like 一 where OCR often fails.
///
/// Both coordinate systems are normalized to [0, 1] for comparison:
/// - User strokes: divided by canvas frame size (e.g. 300pt or 420pt)
/// - Expected medians: divided by 1024 (the Make Me a Hanzi coordinate space)
struct StrokeMatcher {

    // MARK: - Thresholds

    /// Max average distance (normalized) from user stroke to expected median polyline.
    /// 0.18 ≈ 18% of canvas — generous enough for sloppy handwriting.
    private static let distanceThreshold: Double = 0.18

    /// Max angle difference (radians) between start→end direction of user vs expected.
    /// ~72° allows for natural variation while filtering clearly wrong directions.
    private static let angleThreshold: Double = .pi / 2.5

    /// Points sampled per stroke for comparison.
    private static let sampleCount = 20

    /// Median data coordinate space.
    private static let referenceSize: CGFloat = 1024

    // MARK: - Public API

    /// Returns `true` if the drawing is a reasonable match for the expected character.
    ///
    /// - Parameters:
    ///   - drawing: The user's PencilKit drawing.
    ///   - strokeData: Expected character's stroke/median data from strokes.json.
    ///   - canvasSize: The frame size of the writing canvas (300 on iPhone, 420 on iPad).
    static func matches(
        drawing: PKDrawing,
        strokeData: StrokeData,
        canvasSize: CGFloat
    ) -> Bool {
        let expectedCount = strokeData.medians.count
        guard expectedCount > 0, !drawing.strokes.isEmpty else { return false }

        // Stroke count: allow ±max(2, expectedCount/3).
        // Very lenient — users sometimes lift mid-stroke or draw extras.
        let countDiff = abs(drawing.strokes.count - expectedCount)
        if countDiff > max(2, expectedCount / 3) { return false }

        // Normalize user strokes to [0, 1]
        let userStrokes = drawing.strokes.map { stroke in
            samplePoints(from: stroke).map { p in
                CGPoint(x: p.x / canvasSize, y: p.y / canvasSize)
            }
        }

        // Normalize expected medians to [0, 1]
        let expectedStrokes = (0..<expectedCount).map { i in
            StrokeRenderer.medianPoints(from: strokeData, strokeIndex: i).map { p in
                CGPoint(x: p.x / referenceSize, y: p.y / referenceSize)
            }
        }

        // Greedy matching: for each expected stroke, find the best unmatched user stroke
        // by direction + proximity.
        var matched = 0
        var used = Set<Int>()

        for expected in expectedStrokes {
            guard expected.count >= 2 else { continue }
            let expAngle = primaryAngle(expected)

            var bestIdx = -1
            var bestDist = Double.infinity

            for (j, user) in userStrokes.enumerated() where !used.contains(j) {
                guard user.count >= 2 else { continue }

                // Direction gate — skip clearly wrong orientations
                if angleDifference(primaryAngle(user), expAngle) > angleThreshold { continue }

                // Proximity: average distance from user points to expected polyline
                let dist = averageDistanceToPolyline(from: user, to: expected)
                if dist < bestDist {
                    bestDist = dist
                    bestIdx = j
                }
            }

            if bestIdx >= 0 && bestDist < distanceThreshold {
                matched += 1
                used.insert(bestIdx)
            }
        }

        // Accept if ≥60% of expected strokes were matched.
        return Double(matched) / Double(expectedCount) >= 0.6
    }

    // MARK: - Point sampling

    /// Sample evenly-spaced points along a PKStroke using parametric interpolation.
    private static func samplePoints(from stroke: PKStroke) -> [CGPoint] {
        let path = stroke.path
        guard path.count >= 2 else {
            return path.count == 1 ? [path[0].location] : []
        }
        let maxParam = CGFloat(path.count - 1)
        return (0..<sampleCount).map { i in
            let t = CGFloat(i) / CGFloat(sampleCount - 1) * maxParam
            return path.interpolatedPoint(at: t).location
        }
    }

    // MARK: - Direction helpers

    /// Angle (radians) from first to last point — the stroke's primary direction.
    private static func primaryAngle(_ points: [CGPoint]) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        return atan2(last.y - first.y, last.x - first.x)
    }

    /// Absolute angular difference, wrapped to [0, π].
    private static func angleDifference(_ a: Double, _ b: Double) -> Double {
        var diff = a - b
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return abs(diff)
    }

    // MARK: - Distance helpers

    /// Average minimum distance from each point in `from` to the polyline defined by `to`.
    private static func averageDistanceToPolyline(from points: [CGPoint], to polyline: [CGPoint]) -> Double {
        guard !points.isEmpty, polyline.count >= 2 else { return .infinity }
        var total = 0.0
        for p in points {
            var minDist = Double.infinity
            for i in 0..<polyline.count - 1 {
                minDist = min(minDist, pointToSegmentDistance(p, polyline[i], polyline[i + 1]))
            }
            total += minDist
        }
        return total / Double(points.count)
    }

    /// Shortest distance from point `p` to the line segment `a`–`b`.
    private static func pointToSegmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}
