import SwiftUI

/// App settings: character set toggle, about info.
struct SettingsView: View {
    let sessionManager: SessionManager

    @State private var useTraditional: Bool = false
    @State private var startingGrade: Int = 1
    @State private var dailyGoal: Int = 10
    @State private var soundEffectsEnabled: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Grade Level", selection: $startingGrade) {
                        ForEach(1...7, id: \.self) { grade in
                            Text(CharacterEntry.gradeName(for: grade)).tag(grade)
                        }
                    }
                    .onChange(of: startingGrade) { _, newValue in
                        sessionManager.updateStartingGrade(newValue)
                    }
                    Text("New characters start from this grade. Lower grades are verified periodically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Starting Grade")
                }

                Section("Daily Goal") {
                    Picker("Characters per day", selection: $dailyGoal) {
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("15").tag(15)
                        Text("20").tag(20)
                        Text("25").tag(25)
                    }
                    .onChange(of: dailyGoal) { _, newValue in
                        sessionManager.updateDailyGoal(newValue)
                    }
                    Text("How many characters to practice each day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
                        sessionManager.updateUseTraditional(newValue)
                    }
                }

                Section("Audio") {
                    Toggle("Sound Effects", isOn: $soundEffectsEnabled)
                        .onChange(of: soundEffectsEnabled) { _, newValue in
                            sessionManager.updateSoundEffects(newValue)
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
                let profile = sessionManager.fetchProfile()
                useTraditional = profile?.useTraditional ?? false
                startingGrade = max(1, profile?.startingGrade ?? 1)
                dailyGoal = profile?.dailyGoal ?? 10
                soundEffectsEnabled = profile?.soundEffectsEnabled ?? true
            }
        }
    }
}
