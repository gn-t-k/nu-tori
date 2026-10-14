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

    /// 目標の設定で使う種類（身長・生年月日・性別・歩数・摂取エネルギーを読む。体重を読む・書く、体脂肪率を読む）に、まだ許可を求めていないものがあるか
    func goalSetupAuthorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus

    /// 目標の設定で使う種類の許可を、iPhone の画面で求める。画面に出るのは、まだ求めていない種類だけ
    func requestGoalSetupAuthorization() async throws

    /// 読み取りの期間の境界。iOS 27 だけが持ち、それより前の版では nil
    func earliestAuthorizedSampleDate(for quantity: HealthDailyQuantity) async throws -> Date?

    /// 摂取エネルギーの、出どころごとの日の合計。日は `timeZone` の日付で区切り、サンプルの無い日と出どころは返さない
    func readDailyDietaryEnergyBySource(days: ClosedRange<CalendarDay>, in timeZone: TimeZone)
        async throws -> [HealthDailySourceEnergy]

    /// 歩数の日の合計（出どころの重なりはヘルスケアがならす）。日は `timeZone` の日付で区切り、サンプルの無い日は返さない
    func readDailyStepCounts(days: ClosedRange<CalendarDay>, in timeZone: TimeZone)
        async throws -> [CalendarDay: Int]

    /// いちばん新しい身長。無ければ nil
    func readLatestHeightCentimeters() async throws -> Double?

    /// 生年月日。入れていない、または許可されていなければ nil
    func readDateOfBirth() async throws -> CalendarDay?

    /// 性別。入れていない、男性と女性のどちらでもない、または許可されていなければ nil
    func readBiologicalSex() async throws -> BiologicalSex?
}
