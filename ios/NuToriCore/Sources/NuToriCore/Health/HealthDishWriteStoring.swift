public import Foundation

/// ヘルスケアに書いた料理の控え。書いた料理を書き直さず、消えた料理をヘルスケアから消すために持つ。
/// 料理の写しと同じキャッシュの置き場に持ち、移行は持たない（キャッシュを作り直すと、取り直した料理を改めて書く）
public protocol HealthDishWriteStoring: Sendable {
    /// 料理の ID ごとの、書いた版
    func dishVersionsWrittenToHealth() async throws -> [UUID: Int]

    func markDishWrittenToHealth(dishId: UUID, version: Int) async throws

    func unmarkDishWrittenToHealth(dishId: UUID) async throws
}
