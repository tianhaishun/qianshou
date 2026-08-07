import SwiftUI

@main
struct QianShouApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .defaultSize(width: 1160, height: 800)
        .windowResizability(.contentMinSize)
    }
}
