import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.chinesewriting.app", category: "Settings")

/// App settings: character set toggle, about info.
struct SettingsView: View {
    let sessionManager: SessionManager

    @State private var useTraditional: Bool = false
    @State private var startingGrade: Int = 1
    @State private var dailyGoal: Int = 10
    @State private var soundEffectsEnabled: Bool = true
    @State private var animationSpeed: Int = 1
    @State private var sessionLength: Int = 0
    @State private var showExportSheet = false
    @State private var exportFileURL: URL?

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

                Section("Session Length") {
                    Picker("Characters per session", selection: $sessionLength) {
                        Text("Unlimited").tag(0)
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("20").tag(20)
                    }
                    .onChange(of: sessionLength) { _, newValue in
                        sessionManager.updateSessionLength(newValue)
                    }
                    Text("How many characters to practice before ending a session. Unlimited means you tap Done when finished.")
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

                Section("Animation") {
                    Picker("Stroke Animation Speed", selection: $animationSpeed) {
                        Text("Slow").tag(0)
                        Text("Normal").tag(1)
                        Text("Fast").tag(2)
                    }
                    .onChange(of: animationSpeed) { _, newValue in
                        sessionManager.updateAnimationSpeed(newValue)
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

                Section("Data") {
                    Button(action: exportProgress) {
                        Label("Export Progress", systemImage: "square.and.arrow.up")
                    }
                    Text("Export your review data as JSON for backup or analysis.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    Text("Chinese character writing practice with spaced repetition (FSRS).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Acknowledgments") {
                    Text("Stroke order data derived from [Make Me a Hanzi](https://github.com/skishore/makemeahanzi), licensed under LGPL / CC-BY-SA.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showExportSheet) {
                if let url = exportFileURL {
                    ShareSheet(items: [url])
                }
            }
            .onAppear {
                let profile = sessionManager.fetchProfile()
                useTraditional = profile?.useTraditional ?? false
                startingGrade = max(1, profile?.startingGrade ?? 1)
                dailyGoal = profile?.dailyGoal ?? 10
                soundEffectsEnabled = profile?.soundEffectsEnabled ?? true
                animationSpeed = profile?.animationSpeed ?? 1
                sessionLength = profile?.sessionLength ?? 0
            }
        }
    }

    private func exportProgress() {
        guard let data = sessionManager.exportProgressData() else { return }
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("chinese-writing-progress.json")
        do {
            try data.write(to: fileURL)
            exportFileURL = fileURL
            showExportSheet = true
        } catch {
            logger.error("Export failed: \(error)")
        }
    }
}

/// UIKit share sheet wrapper for SwiftUI.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
