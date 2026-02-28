import SwiftUI
import SwiftData

/// Root view with tab navigation: Practice, Progress, Settings.
/// Shows onboarding (grade picker) on first launch.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var characterData = CharacterDataService()
    @State private var ttsService = TTSService()
    @State private var sessionManager: SessionManager?
    @State private var viewModel: PracticeViewModel?
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if let sessionManager, let viewModel {
                TabView {
                    PracticeView(viewModel: viewModel)
                        .tabItem {
                            Label("Practice", systemImage: "pencil.and.outline")
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
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(sessionManager: sessionManager) {
                        showOnboarding = false
                    }
                }
            } else {
                ProgressView("Loading...")
                    .onAppear { setupServices() }
            }
        }
    }

    private func setupServices() {
        guard sessionManager == nil else { return }
        let sm = SessionManager(characterData: characterData, modelContext: modelContext)
        self.sessionManager = sm
        self.viewModel = PracticeViewModel(
            sessionManager: sm,
            ttsService: ttsService,
            characterData: characterData
        )

        // Show onboarding if the user hasn't completed it yet
        let profile = sm.fetchProfile()
        if profile?.hasCompletedOnboarding != true {
            showOnboarding = true
        }
    }
}
