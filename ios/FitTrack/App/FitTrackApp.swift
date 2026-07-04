import SwiftUI
import SwiftData

@main
struct FitTrackApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .task { await container.bootstrap() }
        }
        .modelContainer(container.modelContainer)
    }
}
