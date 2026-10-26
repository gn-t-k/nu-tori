import NuToriCore
import SwiftUI

/// タイムラインの体重の行。時刻はカードの外に置く側が付ける（DESIGN.md の own-record-time）が、読み上げはここで時刻から読む
struct WeightRecordRow: View {
    let record: WeightRecord

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .trailing) {
                Text(kilograms)
                    .font(.subheadline)
                    .monospacedDigit()
                if let sourceAppName {
                    Text(sourceAppName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding()
        // DESIGN.md の own-record-card。角はタイムラインのカード（12）
        .background(
            Color.accentColor.opacity(OwnRecordCard.tintOpacity),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [record.clockText, kilograms, sourceAppName].compactMap(\.self).joined(separator: " "))
    }

    private var kilograms: String {
        WeightAmountText.kilograms(record.kilograms)
    }

    private var sourceAppName: String? {
        switch record.inputSource {
        case .manual: nil
        case .imported(let source): source.appName
        }
    }
}
