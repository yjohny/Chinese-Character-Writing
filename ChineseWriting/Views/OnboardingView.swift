import SwiftUI

/// First-launch grade picker. Shown once before the user's first practice session.
struct OnboardingView: View {
    let sessionManager: SessionManager
    let onComplete: () -> Void

    @State private var selectedGrade: Int = 1

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Welcome!")
                .font(.largeTitle.bold())

            Text("What grade level would you like to start from?")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                ForEach(1...6, id: \.self) { grade in
                    Button {
                        selectedGrade = grade
                    } label: {
                        HStack {
                            Text("Grade \(grade)")
                                .font(.headline)
                            Spacer()
                            if selectedGrade == grade {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedGrade == grade ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedGrade == grade ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Text("Characters below your starting grade will be verified periodically to check your foundations.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                if let profile = sessionManager.fetchProfile() {
                    profile.startingGrade = selectedGrade
                    profile.hasCompletedOnboarding = true
                    try? profile.modelContext?.save()
                }
                if selectedGrade > 1 {
                    sessionManager.setupAssumedKnownCards(startingGrade: selectedGrade)
                }
                onComplete()
            } label: {
                Text("Start Practicing")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}
