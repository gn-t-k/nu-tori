/// 食事の栄養の合計の見せ方。推定の状態ごとの合計の列（食事の画面の「状態ごとの料理の一覧の場所と合計」）と、
/// 日の丸に数えるかを決める
public enum MealNutrition: Hashable, Sendable {
    /// まだ出せない。合計は「—」で、日の丸には「推定が済んでいない食事」として数える
    case pending
    /// 料理なし・推定できなかった。合計は 0 kcal で、日の丸には数えない（kcal が出ない食事）
    case noFood
    /// 分かる料理と材料から出した合計。料理ごとに待つ料理があるか、写真の推定が済んでいない食事に足した料理の分なら、
    /// 値に「以上」が付く（`NutrientAmount.atLeast`）。分かる値が1つも無い栄養は「不明」
    case estimated(NutrientTotals)
}
