public import Foundation

/// 画面から受ける、記録を作る・直す・消す編集。`RootModel.perform(_:)` の1つの口で受け、
/// どれも電波が無くてもその場でキャッシュに当たり、書き込みが送り待ちに並ぶ。後始末は `aftermath` に種類ごとに書く
public enum UserEdit: Sendable {
    /// 体重を記録する・直す
    case saveWeight(WeightEntry.Write)
    /// 撮った写真1枚を、1つの食事にする。食事の時刻は撮った時刻（付帯情報に無ければ `sentAt`）。`sentAt` は「写真を使用」を押した時刻
    case recordCapturedMeal(MealPhotoOriginal, sentAt: Date)
    /// 選んだ写真を、撮影時刻の近いものごとの食事にまとめる。`pickedAt` は選び終えた時刻
    case recordPickedMeals([MealPhotoOriginal], pickedAt: Date)
    /// 食事の画面で撮った時刻を直す。その場で1日の丸と日のまとめが直した日に移る
    case correctMealTime(MealCard, eatenAt: Date)
    /// 食事を消す。その場でキャッシュとアプリの中の写真から消える。`deletedAt` は消した時刻で、送ってから消すまでの時間を測る
    case deleteMeal(MealCard, deletedAt: Date)
    /// 食事の画面の「料理を足す」。前後の空白を除いて空の名前は足さない
    case addDish(named: String, to: MealCard)
    /// 料理の名前を直す。空の名前と今と同じ名前は送らない
    case renameDish(Dish, to: String)
    /// 料理の量を直す。材料の量も同じ割合で変わる。範囲の外の量と今と同じ量は送らない
    case correctDishQuantity(Dish, to: Double)
    /// 材料の量を直す。料理の量は変わらない
    case correctIngredientQuantity(Ingredient, to: Double)
    /// 料理を消す（食事の画面で左へ送った、料理の画面の「この料理を削除」。最後の1品でないとき）
    case deleteDish(Dish)
    /// 入力欄から文章を送る。受け付ける範囲の外は送らない
    case sendText(TextDraft)
    /// 文章の食事のカードの「会話として送り直す」。確かめずに、その場でその文章の食事が消える。`deletedMealCount` はその食事の数
    case resendAsConversation(sentTextId: UUID, deletedMealCount: Int)
    /// 作れなかった・回数切れの1行の「送り直す」
    case resendReply(sentTextId: UUID, reason: ClientUsageEvent.ReplyRegenerateReason)

    /// 編集の後始末。種類ごとに、ここにだけ書く
    public var aftermath: Aftermath {
        switch self {
        case .saveWeight(let write):
            let replacedRecordId: UUID? =
                switch write {
                case .create: nil
                case .correct(let record): record.id
                }
            // 直した場所は画面が知っているので、体重を直した利用状況は画面が送る
            return Aftermath(replacing: replacedRecordId, followUp: .weightRecorded, usage: .none)
        case .recordCapturedMeal:
            return Aftermath(
                replacing: nil, followUp: .estimation,
                usage: .mealRecorded(entry: .captured, photoCount: 1),
                requestsNutritionAuthorization: true)
        case .recordPickedMeals(let photos, _):
            return Aftermath(
                replacing: nil, followUp: .estimation,
                usage: .mealRecorded(entry: .picked, photoCount: photos.count),
                requestsNutritionAuthorization: true)
        case .correctMealTime(let card, _):
            // 時刻は送らない
            return Aftermath(
                replacing: card.meal.id, followUp: .sync, usage: .written(.mealTimeCorrected))
        case .deleteMeal(let card, let deletedAt):
            return Aftermath(
                replacing: card.meal.id, followUp: .sync,
                usage: .written(.mealDeleted(card, at: deletedAt)))
        case .addDish:
            // 名前は送らない
            return Aftermath(replacing: nil, followUp: .estimation, usage: .written(.dishAdded))
        case .renameDish(let dish, _):
            return Aftermath(
                replacing: dish.id, followUp: .estimation, usage: .written(.dishCorrected))
        case .correctDishQuantity(let dish, _):
            // 量は送らない
            return Aftermath(replacing: dish.id, followUp: .sync, usage: .written(.dishCorrected))
        case .correctIngredientQuantity(let ingredient, _):
            return Aftermath(
                replacing: ingredient.id, followUp: .sync, usage: .written(.dishCorrected))
        case .deleteDish(let dish):
            return Aftermath(replacing: dish.id, followUp: .sync, usage: .written(.dishDeleted))
        case .sendText(let draft):
            // 本文は送らない
            return Aftermath(replacing: nil, followUp: .replies, usage: .written(draft.sentEvent))
        case .resendAsConversation(let sentTextId, let deletedMealCount):
            return Aftermath(
                replacing: sentTextId, followUp: .replies,
                usage: .written(.resentAsConversation(deletedMealCount: deletedMealCount)))
        case .resendReply(let sentTextId, let reason):
            return Aftermath(
                replacing: sentTextId, followUp: .replies,
                usage: .written(.replyRegenerateTapped(reason)))
        }
    }

    /// 編集の後始末。`replacedRecordId` は書く前に当てる。書いた結果が `Outcome.unwritten` なら、残りはどれもしない。
    /// 書いたら、いつも送り待ちから作る見え方を出す。まだ届いていない記録として、その場で薄く描くため
    public struct Aftermath: Equatable, Sendable {
        /// 書く前に、受け付けなかった1行を消す記録。作る編集は nil
        public let replacedRecordId: UUID?
        public let followUp: FollowUp
        /// 書いたら PostHog に送る出来事
        public let usage: Usage
        /// 撮る・選ぶ画面が閉じてタイムラインに戻ってから、栄養の書き込みの許可を求めるか
        public let requestsNutritionAuthorization: Bool

        init(
            replacing replacedRecordId: UUID?, followUp: FollowUp, usage: Usage,
            requestsNutritionAuthorization: Bool = false
        ) {
            self.replacedRecordId = replacedRecordId
            self.followUp = followUp
            self.usage = usage
            self.requestsNutritionAuthorization = requestsNutritionAuthorization
        }
    }

    /// 書いたあとに続けること。どれも送り終えるのを待たずに返す
    public enum FollowUp: Equatable, Sendable {
        /// 裏で送る
        case sync
        /// 記録忘れの見張りに体重を記録したことを知らせ（答えを積む）、裏で送る
        case weightRecorded
        /// 裏で送り、送れたら推定中の食事か料理があるあいだ取りに行く。サーバーが推定を始める編集（食事を記録した、料理を足した・名前を直した）
        case estimation
        /// 裏で送り、返事を追う（見守る要求をつなぎ、つながらなければ送ってから1分まで取りに行く）
        case replies
    }

    /// 書いたら PostHog に送る出来事。記録の中身（名前、量、時刻、本文）は送らない
    public enum Usage: Equatable, Sendable {
        case none
        case written(ClientUsageEvent)
        /// 書けた食事の数を添えて送る
        case mealRecorded(entry: MealDraft.Entry, photoCount: Int)

        /// `recordCount` は書いた記録の数
        func event(recordCount: Int) -> ClientUsageEvent? {
            switch self {
            case .none: nil
            case .written(let event): event
            case .mealRecorded(let entry, let photoCount):
                .mealRecorded(entry: entry, photoCount: photoCount, mealCount: recordCount)
            }
        }
    }

    /// 編集を書いた結果
    public enum Outcome: Equatable, Sendable {
        /// 書いたものが無い（サインインしていない、空の名前、今と同じ値、受け付ける範囲の外）
        case unwritten
        /// 書いた。`recordCount` は書いた記録の数（食事の記録は食事の数、ほかは 1）
        case written(recordCount: Int)
    }
}
