import SwiftUI

/// App settings: character set toggle, about info.
struct SettingsView: View {
    let sessionManager: SessionManager

    @State private var useTraditional: Bool = false
    @State private var startingGrade: Int = 1
    @State private var showResetConfirmation = false
    @State private var showResetDone = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Grade Level", selection: $startingGrade) {
                        ForEach(1...6, id: \.self) { grade in
                            Text("Grade \(grade)").tag(grade)
                        }
                    }
                    .onChange(of: startingGrade) { _, newValue in
                        if let profile = sessionManager.fetchProfile() {
                            profile.startingGrade = newValue
                            try? profile.modelContext?.save()
                        }
                        sessionManager.setupAssumedKnownCards(startingGrade: newValue)
                    }
                    Text("New characters start from this grade. Lower grades are verified periodically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Starting Grade")
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

                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset All Progress")
                        }
                    }
                    Text("Removes all review history and starts fresh. This cannot be undone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                let profile = sessionManager.fetchProfile()
                useTraditional = profile?.useTraditional ?? false
                startingGrade = max(1, profile?.startingGrade ?? 1)
            }
            .alert("Reset All Progress?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    sessionManager.resetAllProgress()
                    // Re-setup assumed-known cards if starting grade > 1
                    if startingGrade > 1 {
                        sessionManager.setupAssumedKnownCards(startingGrade: startingGrade)
                    }
                    showResetDone = true
                }
            } message: {
                Text("This will erase all your review history, streaks, and mastery progress. Your settings will be kept. This cannot be undone.")
            }
            .alert("Progress Reset", isPresented: $showResetDone) {
                Button("OK") {}
            } message: {
                Text("All progress has been reset. Your next practice session will start fresh.")
            }
        }
    }
}
