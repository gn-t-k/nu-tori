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
    /// スクロールして、題と帯に出す日が変わった
    case dayScrolled
    /// 記録を直した（体重、食事の時刻、料理の名前と量、材料の量）
    case recordCorrected
    /// 料理を足した
    case dishAdded
    /// 料理を削除した
    case dishDeleted
    /// 食事を削除した
    case mealDeleted
    /// 受け付けなかった1行が届いた（書き込みがサーバーで失敗した）
    case writeRejected
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
            .dayTapped, .dayScrolled, .recordCorrected, .dishAdded, .dishDeleted, .mealDeleted,
            .writeRejected, .mealEstimationFailed, .mealHadNoDishes:
            .silent
        }
    }

    /// 体重・食事・料理の画面から送った、記録を直す・消す編集と料理を足す編集のとき。
    /// 記録を作る編集（体重の記録、写真、文章）は、押した場所ごとにときが違うので、ここでは決めない。
    /// 編集を送ったときに決まるので、今と同じ値で書かれなかった編集でも鳴る
    public init?(editing edit: UserEdit) {
        switch edit {
        case .saveWeight(.correct), .correctMealTime, .renameDish, .correctDishQuantity,
            .correctIngredientQuantity:
            self = .recordCorrected
        case .addDish:
            self = .dishAdded
        case .deleteDish:
            self = .dishDeleted
        case .deleteMeal:
            self = .mealDeleted
        case .saveWeight(.create), .recordCapturedMeal, .recordPickedMeals, .sendText,
            .resendAsConversation, .resendReply:
            return nil
        }
    }
}
