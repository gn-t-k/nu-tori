public import Foundation

/// UI テストは HealthKit を呼ばず、起動の値でこれを差し替える
public protocol HealthStore: Sendable {
    func authorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus

    /// 体重（読む・書く）と体脂肪率（読む）の許可を、iPhone の画面で求める
    func requestAuthorization() async throws

    func isWeightWriteAuthorized() async throws -> Bool

    /// 読み取りの期間の境界。iOS 27 だけが持ち、それより前の版では nil
    func earliestAuthorizedSampleDate() async throws -> Date?

    /// アンカーが nil なら全期間
    func readWeightChanges(after anchor: HealthAnchor?, notBefore: Date?) async throws
        -> HealthChanges

    func writeWeight(_ write: HealthWeightWrite) async throws

    /// 栄養の書き込みの許可を、まだ求めていないか
    func nutritionAuthorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus

    /// 水分を除いた栄養の種類の書き込みの許可を、iPhone の画面で求める
    func requestNutritionAuthorization() async throws

    /// 書き込みを許可された栄養の種類
    func writeAuthorizedNutrients() async throws -> Set<HealthNutrient>

    /// 料理の食品の組を書く。同じ同期 ID があれば、版が大きいときだけ置き換わる
    func writeNutrition(_ write: HealthNutritionWrite) async throws

    /// 同期 ID の食品の組を、中のサンプルごと消す。無ければ何もしない
    func deleteNutrition(syncId: UUID) async throws
}
