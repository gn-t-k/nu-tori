import SwiftUI

/// 決めずに新しい案が返ったときの1行
struct GoalSetupRecalculatedNote: View {
    var body: some View {
        Text("新しい体重で計算し直しました。")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
