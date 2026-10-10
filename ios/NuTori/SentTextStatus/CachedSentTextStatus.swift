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
        classification = Self.stored(status.classification)
        let reply = Self.stored(status.reply)
        replyStatus = reply.status
        replyFailureReason = reply.failureReason
    }

    func apply(_ status: SentTextStatus) {
        classification = Self.stored(status.classification)
        let reply = Self.stored(status.reply)
        replyStatus = reply.status
        replyFailureReason = reply.failureReason
    }

    /// 読めない値の行は nil
    func sentTextStatus() -> SentTextStatus? {
        let classification: SentTextStatus.Classification? =
            switch classification {
            case "pending": .pending
            case "meal": .meal
            case "conversation": .conversation
            default: nil
            }
        let reply: SentTextStatus.Reply? =
            switch (replyStatus, replyFailureReason) {
            case ("none", _): .notRequested
            case ("awaiting", _): .awaiting
            case ("replied", _): .replied
            case ("halted", _): .halted
            case ("failed", "retries_exhausted"): .failed(.retriesExhausted)
            case ("failed", "bad_request"): .failed(.badRequest)
            default: nil
            }
        guard let classification, let reply else { return nil }
        return SentTextStatus(classification: classification, reply: reply)
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

    private static func stored(_ classification: SentTextStatus.Classification) -> String {
        switch classification {
        case .pending: "pending"
        case .meal: "meal"
        case .conversation: "conversation"
        }
    }

    private static func stored(_ reply: SentTextStatus.Reply) -> (
        status: String, failureReason: String?
    ) {
        switch reply {
        case .notRequested: ("none", nil)
        case .awaiting: ("awaiting", nil)
        case .replied: ("replied", nil)
        case .halted: ("halted", nil)
        case .failed(.retriesExhausted): ("failed", "retries_exhausted")
        case .failed(.badRequest): ("failed", "bad_request")
        }
    }
}
