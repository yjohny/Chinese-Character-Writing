import SwiftUI

/// Small circular progress ring showing daily review progress (e.g. "3/10").
struct DailyProgressRing: View {
    let current: Int
    let goal: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(current) / Double(goal))
    }

    private var isComplete: Bool { current >= goal }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isComplete ? Color.green : Color.orange,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            Text("\(current)/\(goal)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(isComplete ? .green : .primary)
        }
        .frame(width: 40, height: 40)
    }
}
