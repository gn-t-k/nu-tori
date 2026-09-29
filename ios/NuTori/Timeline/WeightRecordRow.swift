import NuToriCore
import SwiftUI

struct WeightRecordRow: View {
    let record: WeightRecord

    var body: some View {
        VStack(alignment: .trailing) {
            Text("\(clock) \(kilograms)")
                .font(.subheadline)
                .monospacedDigit()
            if let sourceAppName {
                Text(sourceAppName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        // DESIGN.md は「薄く」とだけ言う。Primary をこの濃さで敷く。角はタイムラインのカード（12）
        .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    private var kilograms: String {
        WeightAmountText.kilograms(record.kilograms)
    }

    private var clock: String {
        WeightAmountText.clock(record.clockTime)
    }

    private var sourceAppName: String? {
        switch record.inputSource {
        case .manual: nil
        case .imported(let source): source.appName
        }
    }
}
