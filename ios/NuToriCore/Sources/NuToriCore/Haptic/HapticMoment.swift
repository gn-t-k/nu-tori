/// 触覚を鳴らすとき。基準は DESIGN.md の「Haptics」。
/// 記録が変わらない操作（プリセット、体重の − と ＋、帯の1日の丸）は鳴らさないので、ここに無い
public enum HapticMoment: Sendable {
    /// 記録を作った・直した・消した編集が書けた
    case recordWritten
    /// 受け付けなかった1行が届いた（書き込みがサーバーで失敗した）
    case writeRejected
    /// 指でスクロールして、題と帯に出す日が変わった
    case dayScrolled
    /// 待っていた食事の推定ができた
    case mealEstimated
    /// 待っていた食事の推定ができなかった
    case mealEstimationFailed
    /// 待っていた食事の写真に料理が見つからなかった
    case mealHadNoDishes
    /// 目標が決まった
    case goalDecided

    /// 鳴らす型
    public var feedback: HapticFeedback {
        switch self {
        case .recordWritten, .mealEstimated, .goalDecided: .success
        case .writeRejected, .mealEstimationFailed: .error
        case .mealHadNoDishes: .warning
        case .dayScrolled: .selection
        }
    }

    /// 編集を書いた結果のとき。記録を作る・直す・消す編集が書けたら `recordWritten`。「会話として送り直す」は、その文章の食事が消えるので、消す編集に数える。
    /// 書いたものが無いとき（今と同じ値、空の名前、範囲の外）と、記録が変わらない返事の送り直しは nil
    public init?(_ edit: UserEdit, outcome: UserEdit.Outcome) {
        guard case .written = outcome else { return nil }
        switch edit {
        case .saveWeight, .recordCapturedMeal, .recordPickedMeals, .correctMealTime, .deleteMeal,
            .addDish, .renameDish, .correctDishQuantity, .correctIngredientQuantity, .deleteDish,
            .sendText, .resendAsConversation:
            self = .recordWritten
        case .resendReply:
            return nil
        }
    }
}
