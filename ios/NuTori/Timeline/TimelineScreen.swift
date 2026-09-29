import SwiftUI

struct TimelineScreen: View {
    let isLoadingRecords: Bool

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline")
    }

    @ViewBuilder private var content: some View {
        if isLoadingRecords {
            VStack(spacing: 8) {
                ProgressView()
                Text("記録を読み込んでいます…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
