public import Foundation

public enum SyncChange: Sendable, Equatable {
    case weightRecord(SyncedWeightRecord)
    /// サーバーは削除の印を返し直すので、同じ ID で2度届くことがある
    case weightRecordDeletion(recordId: UUID)
    case accountSettings(SyncedAccountSettings)
    /// 返事は消えないので、削除の印を持たない
    case aiUtterance(SyncedAiUtterance)
    /// 1日の目安は消えないので、削除の印を持たない。目標より先に届くことがある
    case dailyGuide(SyncedDailyGuide)
    case dish(SyncedDish)
    case dishDeletion(dishId: UUID)
    case dishEstimationStatus(SyncedDishEstimationStatus)
    /// 料理の削除の印と、別の変更で届く。届く順は約束しない
    case dishEstimationStatusDeletion(dishId: UUID)
    /// 推定消費カロリーは消えないので、削除の印を持たない
    case expenditureEstimate(SyncedExpenditureEstimate)
    /// 目標は消えないので、削除の印を持たない。閉じると、同じ ID でもう一度届く
    case goal(SyncedGoal)
    case ingredient(SyncedIngredient)
    case ingredientDeletion(ingredientId: UUID)
    case meal(SyncedMeal)
    case mealDeletion(mealId: UUID)
    case mealEstimationStatus(SyncedMealEstimationStatus)
    /// 食事の削除の印と、別の変更で届く。届く順は約束しない
    case mealEstimationStatusDeletion(mealId: UUID)
    case notice(SyncedNotice)
    /// サーバーからは届かない（知らせは削除の印を持たない）。受け付けなかった知らせの書き込みで、サーバーに知らせが無いときに、端末がキャッシュから外すのに使う
    case noticeRemoval(noticeId: UUID)
    /// 送った文章は消えないので、削除の印を持たない
    case sentText(SyncedSentText)
    /// サーバーからは届かない（送った文章は削除の印を持たない）。
    /// 受け付けなかった送った文章を作る書き込みで、サーバーに文章が無いときに、端末がキャッシュから外すのに使う
    case sentTextRemoval(sentTextId: UUID)
    /// 送った文章より先に届くことがある
    case sentTextStatus(SyncedSentTextStatus)
    /// アカウントに1つで、消えない。事実が変わると、同じ ID でもう一度届く
    case subscriptionStatus(SyncedSubscriptionStatus)
    case usualWeighingTime(SyncedUsualWeighingTime)
    /// 並び全体。届いたらキャッシュを置き換える
    case weightTrend(SyncedWeightTrend)
    /// 体重記録が1つも無くなった。傾向のキャッシュを空にする
    case weightTrendAbsence
    /// 週の見直しは消えないので、削除の印を持たない。指す推定消費カロリー・1日の目安・目標より先に届くことがある
    case weeklyReview(SyncedWeeklyReview)
    /// 知らない種類と読めない中身。サーバーが種類を足しても、古い版のアプリの同期が止まらないように、落とさずに持つ
    case unknown(kind: String)
}
