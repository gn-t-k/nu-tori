public import Foundation

/// writeId は書き込みごとに振る冪等の鍵
public enum SyncWrite: Sendable, Equatable {
    case createWeightRecord(writeId: UUID, record: NewWeightRecord)
    case updateWeightRecord(writeId: UUID, correction: WeightRecordCorrection)
    /// 消すかどうかはサーバーが決める。直した記録は残る
    case sourceDeletedWeightRecord(writeId: UUID, weightRecordId: UUID)
    /// アカウントの設定は、記録が無くても直す書き込みで送る。サーバーが無ければ作る
    case updateAccountSettings(writeId: UUID, settings: SyncedAccountSettings)
    /// 写真の宣言を含む。写真のファイルは別の経路で送る
    case createMeal(writeId: UUID, meal: SyncedMeal)
    /// 直すのは撮った時刻だけ。時差・送った時刻・入口は変えない
    case updateMeal(writeId: UUID, mealId: UUID, eatenAt: Date)
    /// サーバーは受け付けないことが無い。知らない ID でも削除の印を残す
    case deleteMeal(writeId: UUID, mealId: UUID)
    /// 料理を足す。食事が無い、範囲の外の名前は、サーバーが受け付けない。食事が消えていれば、サーバーは料理の削除の印を残して捨てる
    case createDish(writeId: UUID, dish: NewDish)
    /// サーバーは受け付けないことが無い。知らない ID でも削除の印を残す。料理のすべての材料も消える
    case deleteDish(writeId: UUID, dishId: UUID)
    /// 消えていた料理、範囲の外の名前と量、推定し直しで置き換わった前の材料を載せた量の直しは、サーバーが受け付けない
    case updateDish(writeId: UUID, correction: DishCorrection)
    /// 料理ごと消えていた材料、範囲の外の量、推定し直しで置き換わった前の材料は、サーバーが受け付けない
    case updateIngredient(writeId: UUID, ingredientId: UUID, quantity: Double)
    /// 同じ ID の知らせがすでにあれば、サーバーは捨てる
    case createNotice(writeId: UUID, notice: NewNotice)
    /// すでに答えがあれば、サーバーは捨てる（先に受け取ったほうが残る）
    case respondNotice(writeId: UUID, noticeId: UUID, response: SyncedNotice.Response)
}
