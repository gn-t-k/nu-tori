import SwiftUI

@main
struct NuToriApp: App {
    var body: some Scene {
        WindowGroup {
            Text("nu-tori")
        }
    }

    private let observation = ObservationSessions.live()
}
