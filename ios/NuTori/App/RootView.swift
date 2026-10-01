import SwiftUI

struct RootView: View {
    let model: RootModel

    var body: some View {
        content
            .task { await model.open() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    model.noteAppBackgrounded()
                case .active:
                    model.noteAppActive()
                    Task { await model.reopenIfSignedIn() }
                default:
                    break
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
        case .loadingTimeline, .timeline:
            TimelineScreenContainer(
                rejectedLines: model.rejectedLines,
                rejectedMealLines: model.rejectedMealLines,
                capture: { await model.capture($0) },
                prepareWeightEntry: { await model.prepareWeightEntry() },
                saveWeight: { write in
                    await model.saveWeight(write)
                },
                accountActions: AccountActions(
                    signedInAccountId: { await model.signedInAccountId() },
                    turnOnUsageData: { await model.turnOnUsageData() },
                    turnOffUsageData: { await model.turnOffUsageData() },
                    deleteAccount: { await model.deleteAccount() }
                )
            )
        }
    }
}
