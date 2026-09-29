import NuToriCore
import SwiftUI

struct WeightRecordRow: View {
    let record: WeightRecord

    var body: some View {
        VStack(alignment: .trailing) {
            Text("\(clock) \(record.kilogramsLabel)")
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

    private var clock: String {
        let time = record.clockTime
        return "\(time.hour):\(String(format: "%02d", time.minute))"
    }

    private var sourceAppName: String? {
        switch record.inputSource {
        case .manual: nil
        case .imported(let source): source.appName
        }
    }
}

extension WeightRecord {
    var kilogramsLabel: String {
        let rounded = (kilograms * 10).rounded() / 10
        return String(format: "%.1f kg", locale: Locale(identifier: "en_US_POSIX"), rounded)
    }
}
