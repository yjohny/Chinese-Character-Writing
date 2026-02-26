import SwiftUI

/// App settings: character set toggle, about info.
struct SettingsView: View {
    let sessionManager: SessionManager

    @State private var useTraditional: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Character Set") {
                    Toggle(isOn: $useTraditional) {
                        VStack(alignment: .leading) {
                            Text(useTraditional ? "Traditional Chinese" : "Simplified Chinese")
                                .font(.body)
                            Text(useTraditional ? "繁體中文" : "简体中文")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: useTraditional) { _, newValue in
                        if let profile = sessionManager.fetchProfile() {
                            profile.useTraditional = newValue
                            try? profile.modelContext?.save()
                        }
                    }
                }

                Section("Statistics") {
                    if let profile = sessionManager.fetchProfile() {
                        LabeledContent("Total Reviews", value: "\(profile.totalReviews)")
                        LabeledContent("Current Streak", value: "\(profile.currentStreak) days")
                        LabeledContent("Longest Streak", value: "\(profile.longestStreak) days")
                        LabeledContent("Characters Mastered", value: "\(sessionManager.masteredCount())")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    Text("Chinese character writing practice with spaced repetition (FSRS).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                useTraditional = sessionManager.fetchProfile()?.useTraditional ?? false
            }
        }
    }
}
