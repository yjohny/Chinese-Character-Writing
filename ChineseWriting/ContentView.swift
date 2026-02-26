import SwiftUI
import SwiftData

/// Root view with tab navigation: Practice, Progress, Settings.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var characterData = CharacterDataService()
    @State private var ttsService = TTSService()
    @State private var sessionManager: SessionManager?
    @State private var viewModel: PracticeViewModel?

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
            } else {
                ProgressView("Loading...")
                    .onAppear { setupServices() }
            }
        }
    }

    private func setupServices() {
        let sm = SessionManager(characterData: characterData, modelContext: modelContext)
        self.sessionManager = sm
        self.viewModel = PracticeViewModel(
            sessionManager: sm,
            ttsService: ttsService,
            characterData: characterData
        )
    }
}
