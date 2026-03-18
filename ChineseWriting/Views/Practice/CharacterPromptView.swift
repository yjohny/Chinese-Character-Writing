import SwiftUI

/// Displays the character prompt: pinyin, meaning, example word, and TTS button.
struct CharacterPromptView: View {
    let entry: CharacterEntry
    let useTraditional: Bool
    var onTTSTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            // Pinyin
            Text(entry.pinyin)
                .font(.title2)
                .foregroundStyle(.primary)

            // Meaning
            Text(entry.meaning)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Example word — show only the English meaning, not the Chinese,
            // so the user must recall the character from audio alone.
            if let example = entry.exampleWords.first {
                Text("Example: \(example.meaning)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // TTS button
            Button(action: { onTTSTap?() }) {
                Label("Listen", systemImage: "speaker.wave.2.fill")
                    .font(.body)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .accessibilityHint("Hear the character pronounced in context")
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Character prompt: \(entry.pinyin), meaning: \(entry.meaning)")
    }
}
