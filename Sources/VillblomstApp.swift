import SwiftUI

@main
struct VillblomstApp: App {
    @StateObject private var store = WallpaperStore()
    private let loc = Localization.shared

    var body: some Scene {
        WindowGroup("Villblomst") {
            ContentView(store: store, loc: loc)
                .task { await store.preparePool() }
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(store: store, loc: loc)
        }
    }
}
