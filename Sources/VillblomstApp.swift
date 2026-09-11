import SwiftUI

@main
struct VillblomstApp: App {
    @StateObject private var store = WallpaperStore()

    var body: some Scene {
        WindowGroup("Villblomst") {
            ContentView(store: store)
                .task { await store.preparePool() }
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(store: store)
        }
    }
}
