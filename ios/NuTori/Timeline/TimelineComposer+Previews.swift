#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: TimelineComposer.Sample.allCases) { sample in
        VStack {
            Spacer()
            TimelineComposer(
                weightRecordedToday: sample.weightRecordedToday,
                expandsGoalSetup: sample.expandsGoalSetup,
                preparingWeightEntry: sample.preparingWeightEntry,
                showsCameraNotice: sample.showsCameraNotice,
                initialDraft: sample.draft,
                onCapture: {},
                onPickPhotos: {},
                onWeight: {},
                onPresetTapped: { _ in },
                onSendText: { _ in }
            )
        }
        .background(Color(.systemGroupedBackground))
    }

    extension TimelineComposer {
        fileprivate enum Sample: CaseIterable {
            /// 今日の体重がまだ。丸の行の下に「体重を記録」のカプセル
            case weightUnrecorded
            /// 今日の体重を記録した。体重計の丸
            case weightRecorded
            /// 体重を押し、ヘルスケアの許可を求めている
            case preparingWeightEntry
            /// カメラを許可していない人が「撮る」を押した
            case cameraNotPermitted
            /// 書いている。「体重」とプリセットを隠し、「送る」を出す
            case writing
            /// プリセットを押した
            case presetInserted
            /// 空白だけ。「送る」は出すが押せない
            case onlyWhitespace
            /// 450 字を超えた。「残り N」を出す
            case nearLimit
            /// 500 字を超えた。「N 字多い」を出し、「送る」を押せない
            case overLimit
            /// 今日の体重がまだで、目標を立てる知らせのカードを広げている。体重は灰色の丸
            case goalSetupExpanded

            var weightRecordedToday: Bool {
                switch self {
                case .weightUnrecorded, .preparingWeightEntry, .writing, .overLimit,
                    .goalSetupExpanded:
                    false
                case .weightRecorded, .cameraNotPermitted, .presetInserted, .onlyWhitespace,
                    .nearLimit:
                    true
                }
            }

            var preparingWeightEntry: Bool {
                switch self {
                case .preparingWeightEntry: true
                case .weightUnrecorded, .weightRecorded, .cameraNotPermitted, .writing,
                    .presetInserted, .onlyWhitespace, .nearLimit, .overLimit, .goalSetupExpanded:
                    false
                }
            }

            var expandsGoalSetup: Bool {
                switch self {
                case .goalSetupExpanded: true
                case .weightUnrecorded, .weightRecorded, .preparingWeightEntry,
                    .cameraNotPermitted, .writing, .presetInserted, .onlyWhitespace, .nearLimit,
                    .overLimit:
                    false
                }
            }

            var showsCameraNotice: Bool {
                switch self {
                case .cameraNotPermitted: true
                case .weightUnrecorded, .weightRecorded, .preparingWeightEntry, .writing,
                    .presetInserted, .onlyWhitespace, .nearLimit, .overLimit, .goalSetupExpanded:
                    false
                }
            }

            var draft: TextDraft {
                switch self {
                case .weightUnrecorded, .weightRecorded, .preparingWeightEntry,
                    .cameraNotPermitted, .goalSetupExpanded:
                    TextDraft.empty
                case .writing:
                    TextDraft(text: "夜は定食屋で生姜焼き定食。ご飯は半分残して、味噌汁は全部飲んだ")
                case .presetInserted:
                    TextDraft(text: TextPreset.mealFeedbackSoFar.text)
                case .onlyWhitespace:
                    TextDraft(text: "  ")
                case .nearLimit:
                    TextDraft(text: String(repeating: "昼はサラダチキンとおにぎり2個。", count: 30))
                case .overLimit:
                    TextDraft(text: String(repeating: "昼はサラダチキンとおにぎり2個。", count: 34))
                }
            }
        }
    }
#endif
