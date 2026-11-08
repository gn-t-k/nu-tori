import Foundation
import NuToriCore
import SwiftData

/// 送った文章の状態。送った文章とは別の種類で、送った文章より先に届くこともあるので、送った文章の ID を値で持つ
@Model
nonisolated final class CachedSentTextStatus {
    @Attribute(.unique) var sentTextId: UUID
    var classification: String
    /// 応答の状態（none・awaiting・replied・halted・failed）
    var replyStatus: String
    /// replyStatus が failed のときだけ持つ、作れなかった理由
    var replyFailureReason: String?
    /// replyStatus が halted のときだけ持つ、止めた理由
    var replyHaltReason: String?

    init(_ record: SentTextStatusSyncing.Status) {
        sentTextId = record.sentTextId
        // 値は apply が入れる。欄をすべて埋めるまで apply を呼べない（Swift の init の決まり）ので、省けない欄に仮の値を入れる
        classification = ""
        replyStatus = ""
        apply(record)
    }

    func apply(_ record: SentTextStatusSyncing.Status) {
        let stored = record.status.storedValue
        classification = stored.classification
        replyStatus = stored.replyStatus
        replyFailureReason = stored.replyFailureReason
        replyHaltReason = stored.replyHaltReason
    }

    /// 読めない値の行は nil
    func sentTextStatus() -> SentTextStatus? {
        SentTextStatus(
            storedClassification: classification, replyStatus: replyStatus,
            replyFailureReason: replyFailureReason, replyHaltReason: replyHaltReason)
    }
}
