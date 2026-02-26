import SwiftUI
import SwiftData

@main
struct ChineseWritingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            ReviewCard.self,
            ReviewLog.self,
            UserProfile.self
        ])
    }
}
