public import Foundation

/// 送った書き込み1件の結果
public struct SyncWriteResult: Sendable, Equatable {
    public let writeId: UUID
    public let outcome: Outcome

    public init(writeId: UUID, outcome: Outcome) {
        self.writeId = writeId
        self.outcome = outcome
    }

    public enum Outcome: Sendable, Equatable {
        case applied
        /// 同じ ID か同じサンプルの記録がすでにあって、サーバーが捨てた
        case ignoredDuplicate
        /// サーバーが受け付けなかった。端末は送り直さない
        case rejected(RejectionReason)
    }

    public enum RejectionReason: Sendable, Equatable {
        case outOfRange
        case invalidTimeZone
        case versionTooLow
        case recordNotFound
        case recordBeforeStartedOn
    }
}
