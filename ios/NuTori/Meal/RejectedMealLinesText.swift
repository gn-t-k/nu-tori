import NuToriCore
import SwiftUI

/// 受け付けなかった書き込みの1行（「1.5杯に直せませんでした。」など）。行の下や、記録の行を外した位置に置く
struct RejectedMealLinesText: View {
    let lines: [RejectedMealLine]

    var body: some View {
        ForEach(lines, id: \.self) { line in
            Text(line.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("rejected-meal-line")
        }
    }
}
