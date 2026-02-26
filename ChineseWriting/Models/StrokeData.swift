import Foundation

/// Stroke order data for one character, derived from Make Me a Hanzi.
/// The strokes array contains SVG path 'd' attribute strings in correct stroke order.
/// The medians array has corresponding median-line points for animation pacing.
/// Coordinate system: 1024x1024 grid, origin top-left, Y increases downward (after transform).
struct StrokeData: Codable {
    let character: String
    let strokes: [String]           // SVG path 'd' strings in stroke order
    let medians: [[[Double]]]       // median points per stroke: [[[x,y], [x,y], ...], ...]
}

/// Container for the strokes.json file (keyed by character).
typealias StrokeDataMap = [String: StrokeData]
