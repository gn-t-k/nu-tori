/// 触覚を鳴らすかを決めるとき。本番で鳴らす型は `standard` で、「動きの見本」ではときごとに型を選び直して試す（`HapticTrial`）
public enum HapticMoment: CaseIterable, Sendable {
    /// 標準のカメラの「写真を使用」を押した
    case photoUsed
    /// 写真を選んで記録した
    case photosPicked
    /// 体重の知らせの中で「記録」を押した
    case weightRecordedInNotice
    /// 体重のシートで「記録」を押した
    case weightRecordedInSheet
    /// 文章を「送る」で送った
    case textSent
    /// プリセットを押した
    case presetTapped
    /// 体重の − と ＋ で値が動いた
    case weightStepped
    /// 帯の1日の丸を押した
    case dayTapped
    /// 食事を削除した
    case mealDeleted
    /// 待っていた食事の推定ができた
    case mealEstimated
    /// 待っていた食事の推定ができなかった
    case mealEstimationFailed
    /// 待っていた食事の写真に料理が見つからなかった
    case mealHadNoDishes
    /// 目標が決まった
    case goalDecided

    /// 本番で鳴らす型
    public var standard: HapticChoice {
        switch self {
        case .photoUsed, .weightRecordedInNotice, .mealEstimated, .goalDecided: .success
        case .photosPicked, .weightRecordedInSheet, .textSent, .presetTapped, .weightStepped,
            .dayTapped, .mealDeleted, .mealEstimationFailed, .mealHadNoDishes:
            .silent
        }
    }
}
