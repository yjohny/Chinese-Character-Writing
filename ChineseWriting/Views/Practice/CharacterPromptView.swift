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

            // Example word
            if let example = entry.exampleWords.first {
                let displayWord = useTraditional ? example.wordTraditional : example.word
                HStack(spacing: 4) {
                    Text(displayWord)
                        .font(.custom("STKaiti", size: 28))
                    Text("(\(example.meaning))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // TTS button
            Button(action: { onTTSTap?() }) {
                Label("Listen", systemImage: "speaker.wave.2.fill")
                    .font(.body)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .padding()
    }
}
