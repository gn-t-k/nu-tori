public import Foundation

/// ヘルスケアに触れる層。本物（HealthKit）は #121 でつなぎ、ここでは差し替えられる形だけを決める
public protocol HealthStore: Sendable {
    func authorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus

    /// 体重（読む・書く）と体脂肪率（読む）の許可を、iPhone の画面で求める
    func requestAuthorization() async throws

    func isWeightWriteAuthorized() async throws -> Bool

    /// 読み取りの期間の境界。iOS 27 だけが持ち、それより前の版では nil
    func earliestAuthorizedSampleDate() async throws -> Date?

    /// 前回のアンカーの続きから、増えた分と消えた分を読む。アンカーが nil なら全期間
    /// - Parameter notBefore: nil でなければ、これより前のサンプルは読まない
    func readWeightChanges(after anchor: HealthAnchor?, notBefore: Date?) async throws
        -> HealthChanges

    func writeWeight(_ write: HealthWeightWrite) async throws
}
