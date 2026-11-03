#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: TimelineComposer.Sample.allCases) { sample in
        VStack {
            Spacer()
            TimelineComposer(
                requiresSubscription: sample.requiresSubscription,
                preparingWeightEntry: sample.preparingWeightEntry,
                showsCameraNotice: sample.showsCameraNotice,
                initialDraft: sample.draft,
                onCapture: {},
                onPickPhotos: {},
                onWeight: {},
                onPresetTapped: { _ in },
                onSendText: { _ in },
                onOpenPaywall: {}
            )
        }
        .background(Color(.systemGroupedBackground))
    }

    extension TimelineComposer {
        fileprivate enum Sample: CaseIterable {
            /// 書いていない。丸の行に「撮る」「写真」「体重」と書く欄
            case idle
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
            /// サブスクリプション切れ。撮る・写真・書く欄を押せず、上にチップ。体重はいつもどおり
            case subscriptionExpired
            /// 書いている途中で日が変わり、サブスクリプションが切れた。下書きは残るが「送る」も押せない
            case subscriptionExpiredWhileWriting

            var requiresSubscription: Bool {
                switch self {
                case .subscriptionExpired, .subscriptionExpiredWhileWriting: true
                case .idle, .preparingWeightEntry, .cameraNotPermitted, .writing, .presetInserted,
                    .onlyWhitespace, .nearLimit, .overLimit:
                    false
                }
            }

            var preparingWeightEntry: Bool {
                switch self {
                case .preparingWeightEntry: true
                case .idle, .cameraNotPermitted, .writing, .presetInserted, .onlyWhitespace,
                    .nearLimit, .overLimit, .subscriptionExpired, .subscriptionExpiredWhileWriting:
                    false
                }
            }

            var showsCameraNotice: Bool {
                switch self {
                case .cameraNotPermitted: true
                case .idle, .preparingWeightEntry, .writing, .presetInserted, .onlyWhitespace,
                    .nearLimit, .overLimit, .subscriptionExpired, .subscriptionExpiredWhileWriting:
                    false
                }
            }

            var draft: TextDraft {
                switch self {
                case .idle, .preparingWeightEntry, .cameraNotPermitted, .subscriptionExpired:
                    TextDraft.empty
                case .writing, .subscriptionExpiredWhileWriting:
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
