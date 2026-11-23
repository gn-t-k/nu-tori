import NuToriCore
import SwiftUI

/// 「動きの見本」で、触覚を鳴らすときごとに型を選び直すシート。選んだ型は、見本の中の操作と場面で鳴る
struct HapticTrialSheet: View {
    @Binding var trial: HapticTrial

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(HapticMoment.allCases, id: \.self) { moment in
                        Picker(moment.title, selection: $trial[moment]) {
                            ForEach(HapticChoice.allCases, id: \.self) { choice in
                                Text(
                                    choice == moment.standard ? "\(choice.title)（本番）" : choice.title
                                )
                                .tag(choice)
                            }
                        }
                    }
                } header: {
                    Text("鳴らすとき")
                } footer: {
                    Text("選んだ型は、見本の中で鳴ります。押した操作の触覚は、タイムラインと下の入力欄で操作したときに鳴ります。見本を閉じると本番の型に戻ります。")
                }
                Section("型だけを鳴らす") {
                    ForEach(HapticChoice.allCases.filter { $0 != .silent }, id: \.self) { choice in
                        Button(choice.title) {
                            played.play(choice)
                        }
                    }
                }
            }
            .navigationTitle("触覚を試す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("本番に戻す") {
                        trial = .standard
                    }
                    .disabled(trial == .standard)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        // 選びながら後ろのタイムラインと場面のボタンで試せるよう、半分の高さで開いているあいだは後ろも触れる
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .sensoryFeedback(trigger: played) { _, new in
            new.choice.feedback
        }
    }

    @State private var played = PlayedChoice()
    @Environment(\.dismiss) private var dismiss

    /// 「型だけを鳴らす」で押した型。同じ型を続けて押しても鳴るよう、押した回数を持つ
    private struct PlayedChoice: Equatable {
        private(set) var choice = HapticChoice.silent
        private var count = 0

        mutating func play(_ choice: HapticChoice) {
            self.choice = choice
            count += 1
        }
    }
}

extension HapticMoment {
    fileprivate var title: String {
        switch self {
        case .photoUsed: "「写真を使用」を押した"
        case .photosPicked: "写真を選んで記録した"
        case .weightRecordedInNotice: "体重の知らせの中で記録した"
        case .weightRecordedInSheet: "体重のシートで記録した"
        case .textSent: "文章を送った"
        case .presetTapped: "プリセットを押した"
        case .weightStepped: "体重の − ＋ を押した"
        case .dayTapped: "帯の1日の丸を押した"
        case .dayScrolled: "スクロールで日が変わった"
        case .recordCorrected: "記録を直した（体重・食事の時刻・料理・材料）"
        case .dishAdded: "料理を足した"
        case .dishDeleted: "料理を削除した"
        case .mealDeleted: "食事を削除した"
        case .writeRejected: "書き込みを受け付けなかった"
        case .mealEstimated: "待っていた推定ができた"
        case .mealEstimationFailed: "待っていた推定ができなかった"
        case .mealHadNoDishes: "写真に料理が見つからなかった"
        case .goalDecided: "目標が決まった"
        }
    }
}

extension HapticChoice {
    fileprivate var title: String {
        switch self {
        case .silent: "鳴らさない"
        case .success: "success"
        case .warning: "warning"
        case .error: "error"
        case .selection: "selection"
        case .increase: "increase"
        case .decrease: "decrease"
        case .lightImpact: "impact（light）"
        case .mediumImpact: "impact（medium）"
        case .heavyImpact: "impact（heavy）"
        case .softImpact: "impact（soft）"
        case .solidImpact: "impact（solid）"
        case .rigidImpact: "impact（rigid）"
        }
    }
}
