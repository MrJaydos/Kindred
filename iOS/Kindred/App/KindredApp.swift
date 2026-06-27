import SwiftUI
import SwiftData

@main
struct KindredApp: App {
    @StateObject private var env = AppEnvironment.makePrototype()

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environmentObject(env)
        }
        .modelContainer(for: [CreatureRecord.self, LineageRecord.self, RosterRecord.self])
    }
}
