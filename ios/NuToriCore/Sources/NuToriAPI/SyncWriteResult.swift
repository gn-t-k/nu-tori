public import Foundation

public struct SyncWriteResult: Sendable, Equatable {
    public let writeId: UUID
    public let outcome: Outcome

    public init(writeId: UUID, outcome: Outcome) {
        self.writeId = writeId
        self.outcome = outcome
    }

    public enum Outcome: Sendable, Equatable {
        case applied
        case ignoredDuplicate
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
        case unknown(reason: String)
    }
}
