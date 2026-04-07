import SwiftUI
import SwiftData

/// Root view with tab navigation: Practice, Progress, Settings.
/// Shows onboarding on first launch before the main tabs.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var characterData = CharacterDataService()
    @State private var ttsService = TTSService()
    @State private var soundService = SoundService()
    @State private var sessionManager: SessionManager?
    @State private var viewModel: PracticeViewModel?
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if let sessionManager, let viewModel {
                if showOnboarding {
                    OnboardingView(
                        sessionManager: sessionManager,
                        characterData: characterData
                    ) {
                        withAnimation { showOnboarding = false }
                    }
                } else {
                    TabView {
                    PracticeView(viewModel: viewModel)
                        .tabItem {
                            Label("Practice", systemImage: "pencil.and.outline")
                        }

                    CharacterBrowseView(
                        sessionManager: sessionManager,
                        characterData: characterData
                    )
                    .tabItem {
                        Label("Characters", systemImage: "character.book.closed.fill")
                    }

                    StatsView(
                        sessionManager: sessionManager,
                        characterData: characterData
                    )
                    .tabItem {
                        Label("Progress", systemImage: "chart.bar.fill")
                    }

                    SettingsView(sessionManager: sessionManager)
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                    }
                    .overlay(alignment: .top) {
                        if let message = sessionManager.lastSaveError {
                            SaveErrorBanner(message: message) {
                                sessionManager.lastSaveError = nil
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: sessionManager.lastSaveError)
                }
            } else {
                ProgressView("Loading...")
                    .onAppear { setupServices() }
            }
        }
    }

    /// Persistent banner shown when SwiftData saves fail. Tap to dismiss.
    /// The banner reappears on the next failed save until the underlying
    /// issue (e.g. disk full) is resolved.
    private struct SaveErrorBanner: View {
        let message: String
        let onDismiss: () -> Void

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.red)
            .cornerRadius(12)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func setupServices() {
        guard sessionManager == nil else { return }
        let sm = SessionManager(characterData: characterData, modelContext: modelContext)
        self.sessionManager = sm
        self.viewModel = PracticeViewModel(
            sessionManager: sm,
            ttsService: ttsService,
            characterData: characterData,
            soundService: soundService
        )
        showOnboarding = !(sm.fetchProfile()?.hasCompletedOnboarding ?? false)
    }
}
