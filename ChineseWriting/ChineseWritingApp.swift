import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.chinesewriting.app", category: "App")

@main
struct ChineseWritingApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: SchemaV1.self,
                migrationPlan: ChineseWritingMigrationPlan.self,
                configurations: ModelConfiguration()
            )
        } catch {
            // Persistence is required for the app to function. Log so the
            // failure is captured by the system, then crash with a useful
            // diagnostic rather than continuing in a broken state.
            logger.error("Failed to create ModelContainer: \(error)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
