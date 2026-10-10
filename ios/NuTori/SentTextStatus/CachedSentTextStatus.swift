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

    init(sentTextId: UUID, status: SentTextStatus) {
        self.sentTextId = sentTextId
        let stored = status.storedValue
        classification = stored.classification
        replyStatus = stored.replyStatus
        replyFailureReason = stored.replyFailureReason
    }

    func apply(_ status: SentTextStatus) {
        let stored = status.storedValue
        classification = stored.classification
        replyStatus = stored.replyStatus
        replyFailureReason = stored.replyFailureReason
    }

    /// 読めない値の行は nil
    func sentTextStatus() -> SentTextStatus? {
        SentTextStatus(
            storedClassification: classification, replyStatus: replyStatus,
            replyFailureReason: replyFailureReason)
    }

    /// 送った文章の ID ごとの状態。読めない値の行は入れない
    static func statuses(of rows: [CachedSentTextStatus]) -> [UUID: SentTextStatus] {
        var statuses: [UUID: SentTextStatus] = [:]
        for row in rows {
            statuses[row.sentTextId] = row.sentTextStatus()
        }
        return statuses
    }

    /// 保存は呼び出し側が行う
    static func write(
        _ status: SentTextStatus, forSentTextId sentTextId: UUID, in context: ModelContext
    ) throws {
        var descriptor = FetchDescriptor<CachedSentTextStatus>(
            predicate: #Predicate { $0.sentTextId == sentTextId })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.apply(status)
        } else {
            context.insert(CachedSentTextStatus(sentTextId: sentTextId, status: status))
        }
    }
}
