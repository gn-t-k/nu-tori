/// 同期の働きが、取りに行った頁を取り切ったあとと、食事を消したあとに呼ぶ。栄養をヘルスケアに書き、消す
public protocol NutritionHealthExport: Sendable {
    func exportNutrition() async throws
}
