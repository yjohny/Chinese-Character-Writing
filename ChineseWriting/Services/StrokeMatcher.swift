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

    /// Max distance (normalized) between user stroke start point and expected start point.
    /// 0.25 ≈ 25% of canvas — catches reversed strokes while allowing natural imprecision.
    private static let startPointThreshold: Double = 0.25

    /// DTW distance threshold (normalized). Strokes with DTW cost above this are rejected
    /// even if their average polyline distance is acceptable.
    private static let dtwThreshold: Double = 0.20

    /// Points sampled per stroke for comparison.
    private static let sampleCount = 20

    /// Median data coordinate space.
    private static let referenceSize: CGFloat = 1024

    /// Match ratio thresholds by grade level.
    /// Lower grades are more lenient; higher grades require more strokes to match.
    private static let matchThresholds: [ClosedRange<Int>: Double] = [
        1...2: 0.70,   // Grades 1–2: simpler characters, younger learners
        3...4: 0.75,   // Grades 3–4: moderate
        5...6: 0.80,   // Grades 5–6: complex characters, expect more accuracy
    ]

    /// Default match threshold when grade is unknown.
    private static let defaultMatchThreshold: Double = 0.75

    // MARK: - Public API

    /// Returns `true` if the drawing is a reasonable match for the expected character.
    ///
    /// - Parameters:
    ///   - drawing: The user's PencilKit drawing.
    ///   - strokeData: Expected character's stroke/median data from strokes.json.
    ///   - canvasSize: The frame size of the writing canvas (300 on iPhone, 420 on iPad).
    ///   - gradeLevel: The character's school grade (1–6), used to adjust strictness.
    static func matches(
        drawing: PKDrawing,
        strokeData: StrokeData,
        canvasSize: CGFloat,
        gradeLevel: Int? = nil
    ) -> Bool {
        let expectedCount = strokeData.medians.count
        guard expectedCount > 0, !drawing.strokes.isEmpty else { return false }

        // Stroke count: allow ±max(2, expectedCount/3).
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
        // by direction, start-point proximity, shape (DTW), and polyline distance.
        var matched = 0
        var used = Set<Int>()

        for expected in expectedStrokes {
            guard expected.count >= 2 else { continue }
            let expAngle = primaryAngle(expected)

            var bestIdx = -1
            var bestScore = Double.infinity

            for (j, user) in userStrokes.enumerated() where !used.contains(j) {
                guard user.count >= 2 else { continue }

                // Gate 1: Direction — skip clearly wrong orientations
                if angleDifference(primaryAngle(user), expAngle) > angleThreshold { continue }

                // Gate 2: Start point — the stroke must begin in roughly the right place.
                // Catches reversed strokes (e.g. 一 drawn right-to-left) that pass
                // the direction check when the angle is close to 180°.
                let startDist = hypot(user[0].x - expected[0].x, user[0].y - expected[0].y)
                if startDist > startPointThreshold { continue }

                // Proximity: average distance from user points to expected polyline
                let avgDist = averageDistanceToPolyline(from: user, to: expected)
                if avgDist >= distanceThreshold { continue }

                // Shape: DTW catches strokes that are near the polyline on average
                // but have a wrong shape (e.g. a curve where a line should be).
                let resampledExpected = resamplePolyline(expected, count: sampleCount)
                let dtwDist = dtwDistance(user, resampledExpected)
                if dtwDist >= dtwThreshold { continue }

                // Combined score: weight both metrics for best-match selection
                let score = avgDist * 0.5 + dtwDist * 0.5
                if score < bestScore {
                    bestScore = score
                    bestIdx = j
                }
            }

            if bestIdx >= 0 {
                matched += 1
                used.insert(bestIdx)
            }
        }

        let threshold = matchThreshold(for: gradeLevel)
        return Double(matched) / Double(expectedCount) >= threshold
    }

    // MARK: - Grade-based leniency

    private static func matchThreshold(for gradeLevel: Int?) -> Double {
        guard let grade = gradeLevel else { return defaultMatchThreshold }
        for (range, threshold) in matchThresholds {
            if range.contains(grade) { return threshold }
        }
        return defaultMatchThreshold
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

    /// Resample a polyline to exactly `count` evenly-spaced points along its arc length.
    private static func resamplePolyline(_ points: [CGPoint], count: Int) -> [CGPoint] {
        guard points.count >= 2, count >= 2 else { return points }

        // Compute cumulative arc lengths
        var cumLengths = [0.0]
        for i in 1..<points.count {
            let d = hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)
            cumLengths.append(cumLengths.last! + d)
        }
        let totalLength = cumLengths.last!
        guard totalLength > 0 else { return points }

        var result = [CGPoint]()
        var segIdx = 0
        for i in 0..<count {
            let target = totalLength * Double(i) / Double(count - 1)
            while segIdx < cumLengths.count - 2 && cumLengths[segIdx + 1] < target {
                segIdx += 1
            }
            let segLen = cumLengths[segIdx + 1] - cumLengths[segIdx]
            let t = segLen > 0 ? (target - cumLengths[segIdx]) / segLen : 0
            let p = CGPoint(
                x: points[segIdx].x + t * (points[segIdx + 1].x - points[segIdx].x),
                y: points[segIdx].y + t * (points[segIdx + 1].y - points[segIdx].y)
            )
            result.append(p)
        }
        return result
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

    // MARK: - DTW (Dynamic Time Warping)

    /// Normalized DTW distance between two point sequences of equal length.
    /// Returns the average per-point cost of the optimal warping path.
    private static func dtwDistance(_ a: [CGPoint], _ b: [CGPoint]) -> Double {
        let n = a.count
        let m = b.count
        guard n > 0, m > 0 else { return .infinity }

        // Cost matrix. Use 1-D array for performance.
        var dtw = [Double](repeating: .infinity, count: (n + 1) * (m + 1))
        let w = m + 1 // row width
        dtw[0] = 0

        for i in 1...n {
            for j in 1...m {
                let cost = hypot(a[i - 1].x - b[j - 1].x, a[i - 1].y - b[j - 1].y)
                dtw[i * w + j] = cost + min(
                    dtw[(i - 1) * w + j],       // insertion
                    dtw[i * w + (j - 1)],        // deletion
                    dtw[(i - 1) * w + (j - 1)]   // match
                )
            }
        }

        // Normalize by path length (n + m is upper bound; use max for simplicity)
        return dtw[n * w + m] / Double(max(n, m))
    }
}
