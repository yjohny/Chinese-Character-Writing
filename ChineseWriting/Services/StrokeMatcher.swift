import PencilKit

/// Compares user-drawn strokes against expected character median data for recognition.
///
/// Uses the median centerline data from Make Me a Hanzi (stored in strokes.json) to check
/// whether the user drew approximately the right strokes in roughly the right positions
/// and directions. This is more reliable than Vision OCR for handwriting recognition,
/// especially for simple characters like 一 where OCR often fails.
///
/// Both coordinate systems are normalized via bounding-box normalization:
/// each set of strokes is centered at (0.5, 0.5) and scaled by max(width, height),
/// making matching invariant to position and scale within the writing area.
struct StrokeMatcher {

    // MARK: - Strict thresholds

    /// Max average distance (normalized) from user stroke to expected median polyline.
    /// 0.15 ≈ 15% of normalized extent.
    private static let distanceThreshold: Double = 0.15

    /// Max angle difference (radians) between start→end direction of user vs expected.
    /// ~65° allows for natural variation while filtering clearly wrong directions.
    private static let angleThreshold: Double = .pi / 2.77

    /// Max distance (normalized) between user stroke start point and expected start point.
    /// 0.22 ≈ 22% of normalized extent — catches reversed strokes while allowing imprecision.
    private static let startPointThreshold: Double = 0.22

    /// DTW distance threshold (normalized). Strokes with DTW cost above this are rejected
    /// even if their average polyline distance is acceptable.
    private static let dtwThreshold: Double = 0.18

    // MARK: - Relaxed thresholds (≈1.4× strict)

    private static let relaxedDistanceThreshold: Double = 0.21
    private static let relaxedAngleThreshold: Double = .pi / 2.25  // ~80°
    private static let relaxedStartPointThreshold: Double = 0.30
    private static let relaxedDtwThreshold: Double = 0.25

    // MARK: - Scoring

    /// Reject any stroke where a single metric exceeds this multiple of the
    /// pass's threshold, even if the composite score is below 1.0.
    private static let ceilingMultiplier: Double = 2.0

    /// Soft scoring weights — shape (distance + DTW) weighted more than direction/position.
    private static let angleWeight: Double = 0.20
    private static let startWeight: Double = 0.20
    private static let distWeight: Double = 0.30
    private static let dtwWeight: Double = 0.30

    // MARK: - Match ratios

    /// Points sampled per stroke for comparison.
    private static let sampleCount = 20

    /// Match ratio thresholds by grade level (strict pass).
    /// Lower grades are more lenient; higher grades require more strokes to match.
    private static let matchThresholds: [ClosedRange<Int>: Double] = [
        1...2: 0.75,   // Grades 1–2: simpler characters, younger learners
        3...4: 0.80,   // Grades 3–4: moderate
        5...7: 0.85,   // Grades 5–6 + Expansion: complex characters, expect more accuracy
    ]

    /// Default match threshold when grade is unknown.
    private static let defaultMatchThreshold: Double = 0.80

    /// Relaxed pass requires a higher fraction of strokes to match.
    private static let relaxedMatchThreshold: Double = 0.90

    // MARK: - Public API

    /// Returns `true` if the drawing is a reasonable match for the expected character.
    ///
    /// Uses a two-pass strategy:
    /// 1. Strict pass with grade-based match ratio.
    /// 2. Relaxed pass with loosened thresholds but 90% match requirement.
    ///
    /// Both passes use bounding-box normalization and soft composite scoring.
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

        // Sample raw points (canvas coordinates for user, Make Me a Hanzi for expected)
        let rawUserStrokes = drawing.strokes.map { samplePoints(from: $0) }
        let rawExpectedStrokes = (0..<expectedCount).map { i in
            StrokeRenderer.medianPoints(from: strokeData, strokeIndex: i)
        }

        // Bounding-box normalize: center at (0.5, 0.5), scale by max(width, height).
        // This makes matching invariant to position and scale within the writing area.
        let userStrokes = boundingBoxNormalize(rawUserStrokes)
        let expectedStrokes = boundingBoxNormalize(rawExpectedStrokes)

        // Strict pass — grade-based match ratio
        let strictRatio = matchRatio(
            userStrokes: userStrokes, expectedStrokes: expectedStrokes,
            angleTh: angleThreshold, startTh: startPointThreshold,
            distTh: distanceThreshold, dtwTh: dtwThreshold
        )
        if strictRatio >= matchThreshold(for: gradeLevel) {
            return true
        }

        // Relaxed pass — loosened per-stroke thresholds, higher overall match requirement
        let relaxedRatio = matchRatio(
            userStrokes: userStrokes, expectedStrokes: expectedStrokes,
            angleTh: relaxedAngleThreshold, startTh: relaxedStartPointThreshold,
            distTh: relaxedDistanceThreshold, dtwTh: relaxedDtwThreshold
        )
        return relaxedRatio >= relaxedMatchThreshold
    }

    // MARK: - Matching

    /// Fraction of expected strokes that match a user stroke, using soft composite scoring.
    ///
    /// For each expected stroke, greedily finds the best unmatched user stroke whose
    /// composite score (weighted blend of angle, start-point, distance, DTW) is below 1.0.
    /// A hard ceiling rejects any stroke where a single metric exceeds 2× the threshold.
    private static func matchRatio(
        userStrokes: [[CGPoint]],
        expectedStrokes: [[CGPoint]],
        angleTh: Double,
        startTh: Double,
        distTh: Double,
        dtwTh: Double
    ) -> Double {
        let expectedCount = expectedStrokes.count
        guard expectedCount > 0 else { return 0 }

        var matched = 0
        var used = Set<Int>()

        for expected in expectedStrokes {
            guard expected.count >= 2 else { continue }
            let expAngle = primaryAngle(expected)

            var bestIdx = -1
            var bestScore = Double.infinity

            for (j, user) in userStrokes.enumerated() where !used.contains(j) {
                guard user.count >= 2 else { continue }

                // Compute raw metrics
                let angleDiff = angleDifference(primaryAngle(user), expAngle)
                let startDist = hypot(user[0].x - expected[0].x, user[0].y - expected[0].y)
                let avgDist = averageDistanceToPolyline(from: user, to: expected)
                let resampledExpected = resamplePolyline(expected, count: sampleCount)
                let dtwDist = dtwDistance(user, resampledExpected)

                // Hard ceiling: reject if any single metric exceeds 2× threshold
                if angleDiff > angleTh * ceilingMultiplier { continue }
                if startDist > startTh * ceilingMultiplier { continue }
                if avgDist > distTh * ceilingMultiplier { continue }
                if dtwDist > dtwTh * ceilingMultiplier { continue }

                // Soft composite score: 0 = perfect, 1.0 = at threshold boundary
                let score = angleWeight * (angleDiff / angleTh)
                    + startWeight * (startDist / startTh)
                    + distWeight * (avgDist / distTh)
                    + dtwWeight * (dtwDist / dtwTh)

                if score < 1.0 && score < bestScore {
                    bestScore = score
                    bestIdx = j
                }
            }

            if bestIdx >= 0 {
                matched += 1
                used.insert(bestIdx)
            }
        }

        return Double(matched) / Double(expectedCount)
    }

    // MARK: - Bounding-box normalization

    /// Normalize stroke polylines by centering at (0.5, 0.5) and scaling by
    /// max(width, height). Preserves aspect ratio so strokes like 一 stay flat.
    private static func boundingBoxNormalize(_ strokes: [[CGPoint]]) -> [[CGPoint]] {
        var minX = Double.infinity, minY = Double.infinity
        var maxX = -Double.infinity, maxY = -Double.infinity
        for stroke in strokes {
            for p in stroke {
                minX = min(minX, p.x)
                minY = min(minY, p.y)
                maxX = max(maxX, p.x)
                maxY = max(maxY, p.y)
            }
        }
        guard minX.isFinite, minY.isFinite else { return strokes }

        let extent = max(maxX - minX, maxY - minY)
        guard extent > 0 else { return strokes }

        let centerX = (minX + maxX) / 2.0
        let centerY = (minY + maxY) / 2.0

        return strokes.map { stroke in
            stroke.map { p in
                CGPoint(
                    x: (p.x - centerX) / extent + 0.5,
                    y: (p.y - centerY) / extent + 0.5
                )
            }
        }
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

    /// Normalized DTW distance between two point sequences.
    /// Uses a Sakoe-Chiba band to constrain the warping window, reducing
    /// complexity from O(n*m) to O(n*band) while still allowing reasonable warping.
    /// Returns the average per-point cost of the optimal warping path.
    private static func dtwDistance(_ a: [CGPoint], _ b: [CGPoint]) -> Double {
        let n = a.count
        let m = b.count
        guard n > 0, m > 0 else { return .infinity }

        // Sakoe-Chiba band: allow warping within ±band of the diagonal.
        // A band of ~30% of sequence length provides good flexibility
        // while cutting computation significantly for longer sequences.
        let band = max(3, max(n, m) / 3)

        // Cost matrix. Use 1-D array for performance.
        var dtw = [Double](repeating: .infinity, count: (n + 1) * (m + 1))
        let w = m + 1 // row width
        dtw[0] = 0

        for i in 1...n {
            let jMin = max(1, i - band)
            let jMax = min(m, i + band)
            for j in jMin...jMax {
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
