public import Foundation

public struct SyncWriteResult: Sendable, Equatable {
    public let writeId: UUID
    public let outcome: Outcome
    /// 受け付けなかったときだけ付く、その記録のサーバーの今の値。読めなかったとき、知らない状態のときは nil
    public let current: Current?

    public init(writeId: UUID, outcome: Outcome, current: Current?) {
        self.writeId = writeId
        self.outcome = outcome
        self.current = current
    }

    /// 受け付けなかった書き込みの記録の、サーバーの今の値。要求の書き込みを全部当て終えた時点のもの。
    /// 値と削除の印は、取りに行く変更と同じ形（通し番号を除く）
    public enum Current: Sendable, Equatable {
        case value(SyncChange)
        case deleted(SyncChange)
        /// 記録も削除の印も無い
        case absent
    }

    public enum Outcome: Sendable, Equatable {
        case applied
        case ignoredDuplicate
        case ignoredTombstone
        case keptCorrected
        /// 端末は送り直さない
        case rejected(RejectionReason)
        /// このアプリが知らない結果。サーバーが結果を足しても、古い版のアプリの同期が止まらないように持つ
        case unknown(result: String)
    }

    public enum RejectionReason: Sendable, Equatable {
        case outOfRange
        case invalidTimeZone
        case versionTooLow
        case recordNotFound
        case recordBeforeStartedOn
        case invalidEntryMethod
        /// 1つの書き込みに同じ写真の ID が2つある
        case duplicatePhotoIds
        /// 写真の ID が、ほかの食事の写真か写真の削除の印にある
        case photoAlreadyUsed
        /// 知らせの種類が、サーバーの知らない値
        case invalidNoticeType
        /// 知らせの対象の日付が、日付の形でない
        case invalidTargetOn
        /// 推定し直しで、料理の材料が置き換わっていた（料理の量の書き込みが前の材料を載せていた、前の材料の量を直した）
        case ingredientsReplaced
        /// 推定を待っている食事（写真を待っている・推定中・翌日に推定）に料理を足そうとした、その料理と材料を直そうとした、推定し直しを待っている料理（推定中・翌日に推定）と、その材料を直そうとした
        case awaitingEstimation
        case unknown(reason: String)
    }
}
