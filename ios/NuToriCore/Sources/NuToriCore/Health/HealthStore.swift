public import Foundation

/// ヘルスケアに触れる層。HealthKit の実装と、UI テストの起動の値による差し替えが、これを実装する
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
}
