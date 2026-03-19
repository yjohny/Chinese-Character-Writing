import SwiftUI

/// A single row showing progress for one grade level.
struct GradeProgressRow: View {
    let grade: Int
    let total: Int
    let introduced: Int
    let learning: Int
    let mastered: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(mastered) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(CharacterEntry.gradeName(for: grade))
                    .font(.subheadline.bold())
                Spacer()
                Text("\(mastered)/\(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(progressColor)

            HStack {
                Label("\(introduced) seen", systemImage: "eye.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Label("\(learning) learning", systemImage: "book.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Spacer()
                Label("\(mastered) mastered", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(CharacterEntry.gradeName(for: grade)): \(mastered) of \(total) mastered, \(learning) learning, \(introduced) seen")
    }

    private var progressColor: Color {
        if progress >= 0.8 { return .green }
        if progress >= 0.4 { return .blue }
        return .orange
    }
}
