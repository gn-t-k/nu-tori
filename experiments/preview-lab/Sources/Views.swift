import SwiftUI

/// 同期の状態の見本。プレビューとスナップショットの両方に渡す
enum SyncSample: String, CaseIterable, Identifiable, Sendable {
    case synced
    case pending
    case failed
    case offline

    var id: String { rawValue }
}

struct SyncBanner: View {
    let sample: SyncSample

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
            Text(title)
            Spacer()
        }
        .padding()
        .background(tint.opacity(0.2), in: .rect(cornerRadius: 12))
        .padding()
    }

    private var title: String {
        switch sample {
        case .synced: "Synced"
        case .pending: "3 records waiting to send"
        case .failed: "Could not save 1 record"
        case .offline: "Offline"
        }
    }

    private var symbol: String {
        switch sample {
        case .synced: "checkmark.circle"
        case .pending: "arrow.up.circle"
        case .failed: "exclamationmark.triangle"
        case .offline: "wifi.slash"
        }
    }

    private var tint: Color {
        switch sample {
        case .synced: .green
        case .pending: .blue
        case .failed: .orange
        case .offline: .gray
        }
    }
}

extension EnvironmentValues {
    @Entry var labTint: Color = .gray
}

/// PreviewModifier の trait が当たると赤、当たらないと灰色になる
struct TintBadge: View {
    @Environment(\.labTint) private var tint

    var body: some View {
        Text("modifier applied?")
            .padding()
            .frame(width: 240, height: 80)
            .background(tint)
    }
}

struct RedTint: PreviewModifier {
    func body(content: Content, context: Void) -> some View {
        content.environment(\.labTint, .red)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var redTint: Self = .modifier(RedTint())
}

struct RecordList: View {
    var body: some View {
        List {
            Section("Today") {
                ForEach(SyncSample.allCases) { sample in
                    SyncBanner(sample: sample)
                }
            }
        }
    }
}

#Preview("plain") {
    SyncBanner(sample: .failed)
}

#Preview("arguments", arguments: SyncSample.allCases) { sample in
    SyncBanner(sample: sample)
}

#Preview("modifier", traits: .redTint) {
    TintBadge()
}

#Preview("list") {
    RecordList()
}
