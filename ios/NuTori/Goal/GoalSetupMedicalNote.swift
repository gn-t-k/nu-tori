import SwiftUI

/// 審査の 5.1.1(ix) と 1.4.1 を避けるため、目標を決めるページに医療の一文と出し方のリンクを添える（仕様 #613）
struct GoalSetupMedicalNote: View {
    let isDeciding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("医療の助言ではありません。持病のある方は、医師に相談してください。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("goal-setup-medical-note")
            DailyGuideExplanationLink()
        }
        // DESIGN.md の押せないボタン（`.disabled` に任せる）に従わず、文も薄くする。仕様 #523 の「決める」が、押したら「ほかを薄くして」と決めているため
        .opacity(isDeciding ? 0.4 : 1)
        .disabled(isDeciding)
    }
}
