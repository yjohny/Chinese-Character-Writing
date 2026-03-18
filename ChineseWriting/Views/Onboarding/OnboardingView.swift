import SwiftUI

/// First-run onboarding flow. Introduces the app, lets the user pick a starting
/// grade, and explains the practice loop before dropping them into their first session.
struct OnboardingView: View {
    let sessionManager: SessionManager
    let characterData: CharacterDataService
    var onComplete: () -> Void

    @State private var page = 0
    @State private var selectedGrade: Int = 1

    var body: some View {
        TabView(selection: $page) {
            welcomePage.tag(0)
            howItWorksPage.tag(1)
            gradePickerPage.tag(2)
            tipsPage.tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)

            Text("Chinese Character\nWriting Practice")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Learn to write Chinese characters through\nspaced repetition and stroke practice.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            nextButton
        }
        .padding(32)
    }

    private var howItWorksPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("How It Works")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 16) {
                stepRow(icon: "speaker.wave.2.fill", color: .blue,
                        title: "Listen & Write",
                        detail: "Hear the character in context, then write it from memory.")

                stepRow(icon: "checkmark.circle.fill", color: .green,
                        title: "Get Feedback",
                        detail: "Your handwriting is recognized automatically. Correct answers advance.")

                stepRow(icon: "hand.draw.fill", color: .orange,
                        title: "Practice Strokes",
                        detail: "If you miss one, watch the stroke order, trace it, then write it again.")

                stepRow(icon: "arrow.triangle.2.circlepath", color: .purple,
                        title: "Spaced Repetition",
                        detail: "Characters you know appear less often. Ones you struggle with come back sooner.")
            }
            .padding(.horizontal)

            Spacer()

            nextButton
        }
        .padding(32)
    }

    private var gradePickerPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "graduationcap.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("Pick Your Level")
                .font(.title.bold())

            Text("Characters are organized by school grade (the official 部编版 curriculum). Choose where to start — you can change this later in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Picker("Starting Grade", selection: $selectedGrade) {
                ForEach(1...7, id: \.self) { grade in
                    Text(CharacterEntry.gradeName(for: grade)).tag(grade)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)

            Text(gradeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: 40)

            Spacer()

            nextButton
        }
        .padding(32)
    }

    private var tipsPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lightbulb.fill")
                .font(.system(size: 50))
                .foregroundStyle(.yellow)

            Text("Quick Tips")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 14) {
                tipRow(icon: "eye.fill", color: .orange,
                       text: "Don't know a character? Tap \"Show me\" to see the strokes.")

                tipRow(icon: "checkmark.circle.fill", color: .green,
                       text: "Recognition wrong? Tap \"I got it right\" to override.")

                tipRow(icon: "arrow.uturn.backward", color: .blue,
                       text: "Made a wrong stroke? Use Undo instead of clearing everything.")

                tipRow(icon: "hand.tap.fill", color: .purple,
                       text: "Tap the stroke animation to skip ahead on characters you know.")
            }
            .padding(.horizontal)

            Spacer()

            Button(action: finishOnboarding) {
                Text("Start Practicing")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(32)
    }

    // MARK: - Helpers

    private var nextButton: some View {
        Button(action: { withAnimation { page += 1 } }) {
            Text("Next")
                .font(.title3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
    }

    private func stepRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func tipRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    private var gradeDescription: String {
        let count = characterData.totalCharacters(forGrade: selectedGrade)
        let name = CharacterEntry.gradeName(for: selectedGrade)
        if selectedGrade <= 6 {
            return "\(name): \(count) characters from the school curriculum."
        } else {
            return "\(name): \(count) common characters for advanced learners."
        }
    }

    private func finishOnboarding() {
        sessionManager.updateStartingGrade(selectedGrade)
        if let profile = sessionManager.fetchProfile() {
            profile.hasCompletedOnboarding = true
        }
        onComplete()
    }
}
