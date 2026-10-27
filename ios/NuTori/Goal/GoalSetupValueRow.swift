import SwiftUI

/// 目標の設定のページの値の行。名前を左に、太字の値を右に置く（「推定消費カロリー　2,250 kcal」「1日の目安　2,250 kcal」）
struct GoalSetupValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundStyle(Color.primary)
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }
}
