import SwiftUI

/// Converts Make Me a Hanzi stroke data into renderable SwiftUI Paths.
///
/// Make Me a Hanzi coordinate system: 1024x1024 grid.
/// Origin at top-left of the character bounding box.
/// Y-axis: 0 at top of grid (y=900 in their coordinate), increases downward.
/// We need to transform: flip Y and translate.
struct StrokeRenderer {
    /// The original coordinate space size.
    static let canvasSize: CGFloat = 1024

    /// Parse a single SVG path 'd' string into a SwiftUI Path.
    static func path(from svgString: String) -> Path {
        let cgPath = parseSVGPath(svgString)
        // Transform: flip Y, shift so character is centered
        var transform = CGAffineTransform.identity
        transform = transform.scaledBy(x: 1, y: -1)
        transform = transform.translatedBy(x: 0, y: -900)

        if let transformedPath = cgPath.copy(using: &transform) {
            return Path(transformedPath)
        }
        return Path(cgPath)
    }

    /// Parse all strokes for a character into an array of Paths.
    static func allStrokes(from data: StrokeData) -> [Path] {
        data.strokes.map { path(from: $0) }
    }

    /// Returns median points for a given stroke, transformed to display coordinates.
    static func medianPoints(from data: StrokeData, strokeIndex: Int) -> [CGPoint] {
        guard strokeIndex < data.medians.count else { return [] }
        return data.medians[strokeIndex].map { pair in
            guard pair.count >= 2 else { return CGPoint.zero }
            return CGPoint(x: pair[0], y: 900 - pair[1])
        }
    }

    // MARK: - SVG Path Parser

    /// Minimal SVG path parser supporting M, L, Q, C, Z commands.
    /// Handles both absolute (uppercase) and relative (lowercase) commands.
    private static func parseSVGPath(_ d: String) -> CGPath {
        let path = CGMutablePath()
        var currentPoint = CGPoint.zero
        var startPoint = CGPoint.zero

        let tokens = tokenize(d)
        var i = 0

        func nextNumber() -> CGFloat {
            guard i < tokens.count else { return 0 }
            let val = CGFloat(Double(tokens[i]) ?? 0)
            i += 1
            return val
        }

        func nextPoint() -> CGPoint {
            CGPoint(x: nextNumber(), y: nextNumber())
        }

        while i < tokens.count {
            let token = tokens[i]
            i += 1

            switch token {
            case "M":
                let p = nextPoint()
                path.move(to: p)
                currentPoint = p
                startPoint = p
                // Subsequent coordinates are implicit lineTo
                while i < tokens.count, Double(tokens[i]) != nil {
                    let p = nextPoint()
                    path.addLine(to: p)
                    currentPoint = p
                }

            case "m":
                let dp = nextPoint()
                let p = CGPoint(x: currentPoint.x + dp.x, y: currentPoint.y + dp.y)
                path.move(to: p)
                currentPoint = p
                startPoint = p
                while i < tokens.count, Double(tokens[i]) != nil {
                    let dp = nextPoint()
                    let p = CGPoint(x: currentPoint.x + dp.x, y: currentPoint.y + dp.y)
                    path.addLine(to: p)
                    currentPoint = p
                }

            case "L":
                while i < tokens.count, Double(tokens[i]) != nil {
                    let p = nextPoint()
                    path.addLine(to: p)
                    currentPoint = p
                }

            case "l":
                while i < tokens.count, Double(tokens[i]) != nil {
                    let dp = nextPoint()
                    let p = CGPoint(x: currentPoint.x + dp.x, y: currentPoint.y + dp.y)
                    path.addLine(to: p)
                    currentPoint = p
                }

            case "H":
                while i < tokens.count, Double(tokens[i]) != nil {
                    let x = nextNumber()
                    let p = CGPoint(x: x, y: currentPoint.y)
                    path.addLine(to: p)
                    currentPoint = p
                }

            case "h":
                while i < tokens.count, Double(tokens[i]) != nil {
                    let dx = nextNumber()
                    let p = CGPoint(x: currentPoint.x + dx, y: currentPoint.y)
                    path.addLine(to: p)
                    currentPoint = p
                }

            case "V":
                while i < tokens.count, Double(tokens[i]) != nil {
                    let y = nextNumber()
                    let p = CGPoint(x: currentPoint.x, y: y)
                    path.addLine(to: p)
                    currentPoint = p
                }

            case "v":
                while i < tokens.count, Double(tokens[i]) != nil {
                    let dy = nextNumber()
                    let p = CGPoint(x: currentPoint.x, y: currentPoint.y + dy)
                    path.addLine(to: p)
                    currentPoint = p
                }

            case "Q":
                while i < tokens.count, Double(tokens[i]) != nil {
                    let control = nextPoint()
                    let end = nextPoint()
                    path.addQuadCurve(to: end, control: control)
                    currentPoint = end
                }

            case "q":
                while i < tokens.count, Double(tokens[i]) != nil {
                    let dc = nextPoint()
                    let de = nextPoint()
                    let control = CGPoint(x: currentPoint.x + dc.x, y: currentPoint.y + dc.y)
                    let end = CGPoint(x: currentPoint.x + de.x, y: currentPoint.y + de.y)
                    path.addQuadCurve(to: end, control: control)
                    currentPoint = end
                }

            case "C":
                while i < tokens.count, Double(tokens[i]) != nil {
                    let c1 = nextPoint()
                    let c2 = nextPoint()
                    let end = nextPoint()
                    path.addCurve(to: end, control1: c1, control2: c2)
                    currentPoint = end
                }

            case "c":
                while i < tokens.count, Double(tokens[i]) != nil {
                    let dc1 = nextPoint()
                    let dc2 = nextPoint()
                    let de = nextPoint()
                    let c1 = CGPoint(x: currentPoint.x + dc1.x, y: currentPoint.y + dc1.y)
                    let c2 = CGPoint(x: currentPoint.x + dc2.x, y: currentPoint.y + dc2.y)
                    let end = CGPoint(x: currentPoint.x + de.x, y: currentPoint.y + de.y)
                    path.addCurve(to: end, control1: c1, control2: c2)
                    currentPoint = end
                }

            case "S":
                while i < tokens.count, Double(tokens[i]) != nil {
                    let c2 = nextPoint()
                    let end = nextPoint()
                    // Smooth cubic: c1 is reflection of previous c2
                    path.addCurve(to: end, control1: currentPoint, control2: c2)
                    currentPoint = end
                }

            case "s":
                while i < tokens.count, Double(tokens[i]) != nil {
                    let dc2 = nextPoint()
                    let de = nextPoint()
                    let c2 = CGPoint(x: currentPoint.x + dc2.x, y: currentPoint.y + dc2.y)
                    let end = CGPoint(x: currentPoint.x + de.x, y: currentPoint.y + de.y)
                    path.addCurve(to: end, control1: currentPoint, control2: c2)
                    currentPoint = end
                }

            case "Z", "z":
                path.closeSubpath()
                currentPoint = startPoint

            default:
                break
            }
        }

        return path
    }

    /// Tokenize an SVG path string into commands and numbers.
    private static func tokenize(_ d: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for char in d {
            if char.isLetter {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            } else if char == "," || char == " " || char == "\t" || char == "\n" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else if char == "-" && !current.isEmpty && !current.hasSuffix("e") && !current.hasSuffix("E") {
                tokens.append(current)
                current = String(char)
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }
}
