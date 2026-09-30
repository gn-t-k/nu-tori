import SwiftUI

@main
struct NuToriApp: App {
    private let observation = ObservationSessions.live()

    var body: some Scene {
        WindowGroup {
            Text("nu-tori")
        }
    }
}
