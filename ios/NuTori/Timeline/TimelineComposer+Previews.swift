#if DEBUG
    import SwiftUI

    #Preview("状態ごと", arguments: TimelineComposer.Sample.allCases) { sample in
        VStack {
            Spacer()
            TimelineComposer(
                weightRecordedToday: sample.weightRecordedToday,
                preparingWeightEntry: sample.preparingWeightEntry,
                showsCameraNotice: sample.showsCameraNotice,
                onCapture: {},
                onPickPhotos: {},
                onWeight: {}
            )
        }
        .background(Color(.systemGroupedBackground))
    }

    extension TimelineComposer {
        fileprivate enum Sample: CaseIterable {
            /// 今日の体重がまだ。「体重を記録」のカプセル
            case weightUnrecorded
            /// 今日の体重を記録した。体重計の丸
            case weightRecorded
            /// 体重を押し、ヘルスケアの許可を求めている
            case preparingWeightEntry
            /// カメラを許可していない人が「撮る」を押した
            case cameraNotPermitted

            var weightRecordedToday: Bool {
                switch self {
                case .weightUnrecorded, .preparingWeightEntry: false
                case .weightRecorded, .cameraNotPermitted: true
                }
            }

            var preparingWeightEntry: Bool {
                switch self {
                case .preparingWeightEntry: true
                case .weightUnrecorded, .weightRecorded, .cameraNotPermitted: false
                }
            }

            var showsCameraNotice: Bool {
                switch self {
                case .cameraNotPermitted: true
                case .weightUnrecorded, .weightRecorded, .preparingWeightEntry: false
                }
            }
        }
    }
#endif
