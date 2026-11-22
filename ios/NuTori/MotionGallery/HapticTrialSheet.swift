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
                    Text("選んだ型は、見本の中の操作と場面で鳴ります。見本を閉じると本番の型に戻ります。")
                }
                Section("型だけを鳴らす") {
                    ForEach(HapticChoice.allCases.filter { $0 != .silent }, id: \.self) { choice in
                        Button(choice.title) {
                            sample.play(choice)
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
        // 選びながら下のタイムラインで試せるよう、半分の高さでも開く
        .presentationDetents([.medium, .large])
        .sensoryFeedback(trigger: sample) { _, new in
            new.choice.feedback
        }
    }

    @State private var sample = Sample()
    @Environment(\.dismiss) private var dismiss

    /// 「型だけを鳴らす」で押した型。同じ型を続けて押しても鳴るよう、押した回数を持つ
    private struct Sample: Equatable {
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
        case .weightRecordedInNotice: "体重の知らせの中で記録した"
        case .weightRecordedInSheet: "体重のシートで記録した"
        case .textSent: "文章を送った"
        case .weightStepped: "体重の − ＋ を押した"
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
        case .lightImpact: "impact（light）"
        case .mediumImpact: "impact（medium）"
        case .heavyImpact: "impact（heavy）"
        case .softImpact: "impact（soft）"
        case .rigidImpact: "impact（rigid）"
        }
    }
}
