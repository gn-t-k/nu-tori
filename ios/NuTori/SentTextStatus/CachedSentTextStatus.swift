import Foundation
import NuToriCore
import SwiftData

/// 送った文章の状態。送った文章とは別の種類で、送った文章より先に届くこともあるので、送った文章の ID を値で持つ
@Model
nonisolated final class CachedSentTextStatus {
    @Attribute(.unique) var sentTextId: UUID
    var classification: String

    init(sentTextId: UUID, status: SentTextStatus) {
        self.sentTextId = sentTextId
        classification = Self.stored(status.classification)
    }

    func apply(_ status: SentTextStatus) {
        classification = Self.stored(status.classification)
    }

    /// 読めない値の行は nil
    func sentTextStatus() -> SentTextStatus? {
        let read: SentTextStatus.Classification? =
            switch classification {
            case "pending": .pending
            case "meal": .meal
            case "conversation": .conversation
            default: nil
            }
        return read.map { SentTextStatus(classification: $0) }
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
}
