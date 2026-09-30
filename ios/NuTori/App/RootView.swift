import NuToriCore
import SwiftUI

struct RootView: View {
    let model: RootModel

    var body: some View {
        content
            .task { await model.open() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await model.reopenIfSignedIn() }
                }
            }
    }

    @Environment(\.scenePhase) private var scenePhase

    @ViewBuilder private var content: some View {
        switch model.screen {
        case .opening:
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        case .signIn(let prompt, let status):
            SignInView(prompt: prompt, status: status) { result in
                Task { await model.signIn(with: result) }
            }
        case .loadingTimeline:
            TimelineScreen(isLoadingRecords: true, session: model.session) { destination in
                model.replaceScreen(with: destination)
            }
        case .timeline:
            TimelineScreen(isLoadingRecords: false, session: model.session) { destination in
                model.replaceScreen(with: destination)
            }
        }
    }
}
