import NuToriCore
import SwiftUI

/// 「すべての記録」。使い始めた日からの体重を、新しい順に1日1行で並べる。
/// 行を押すとその日の体重の画面へ潜り、直すのはそこでする
struct WeightHistoryScreen: View {
    let rows: [RepresentativeWeight]

    var body: some View {
        List(rows, id: \.record.id) { row in
            NavigationLink(value: row.day) {
                LabeledContent(TimelineDayText.label(for: row.day)) {
                    HStack(spacing: 8) {
                        Text(WeightAmountText.kilograms(row.record.kilograms))
                            .monospacedDigit()
                        if row.otherRecordCount > 0 {
                            Text("ほか\(row.otherRecordCount)件")
                        }
                    }
                }
            }
        }
        .navigationTitle("すべての記録")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("weight-history-screen")
    }
}
