import NuToriCore
import SwiftUI

struct TimelineScreen: View {
    let isLoadingRecords: Bool
    let session: AccountSession
    let onLeftTimeline: (SignInDestination) -> Void

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("timeline")
                .toolbar { accountButton }
                .sheet(isPresented: $showsAccount) {
                    NavigationStack {
                        AccountScreen(
                            session: session,
                            onClose: { showsAccount = false },
                            onLeftTimeline: onLeftTimeline
                        )
                    }
                }
        }
    }

    @State private var showsAccount = false

    @ViewBuilder private var content: some View {
        if isLoadingRecords {
            VStack(spacing: 8) {
                ProgressView()
                Text("記録を読み込んでいます…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            Color.clear
        }
    }

    private var accountButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showsAccount = true
            } label: {
                Image(systemName: "person.crop.circle")
            }
            .accessibilityLabel("アカウント")
            .accessibilityIdentifier("accountButton")
        }
    }
}
