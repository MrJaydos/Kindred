import SwiftUI
import SwiftData

@main
struct KindredApp: App {
    @StateObject private var env  = AppEnvironment.makePrototype()
    @StateObject private var game: GameViewModel

    init() {
        let env = AppEnvironment.makePrototype()
        _env  = StateObject(wrappedValue: env)
        _game = StateObject(wrappedValue: GameViewModel(env: env))
    }

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environmentObject(env)
                .environmentObject(game)
        }
        .modelContainer(for: [CreatureRecord.self, LineageRecord.self, RosterRecord.self])
    }
}
