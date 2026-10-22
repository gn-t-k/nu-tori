import SwiftUI

/// 目標を決めるページの下に添える、医療の一文と出し方のページへのリンク（仕様 #613 の「医療の一文と出し方の説明」。審査の 5.1.1(ix) と 1.4.1 を避けるため）
struct GoalSetupMedicalNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("医療の助言ではありません。持病のある方は、医師に相談してください。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("goal-setup-medical-note")
            DailyGuideExplanationLink()
        }
    }
}
