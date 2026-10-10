public import Foundation

/// 見守る要求で届く出来事（`GET /v1/sent-texts/{sentTextId}/reply-stream` の data の1つ）
public enum ReplyStreamEvent: Sendable, Equatable {
    /// 返事の生成を始めた。返事の記録の ID と同じで、試みをまたいで変わらない。つなぎ直したときは、すぐあとにそこまでの分が1つで届く
    case replyStarted(replyId: UUID)
    /// できた分。届いた順につなぐ
    case textDelta(String)
    /// 流している途中で試みが失敗した。つないだ分を捨てる。次の試みで初めから流し直す
    case textDiscarded
    /// 返事を記録に書いた。このあと閉じる
    case replied(replyId: UUID)
    /// 食事と読み分けた。このあと閉じる
    case classifiedAsMeal
    /// その日の回数切れ。このあと閉じる
    case replyHalted
    /// 作れなかった。このあと閉じる
    case replyFailed(SyncedSentTextStatus.FailureReason)

    /// 閉じる前に1つだけ届く結果か
    public var isOutcome: Bool {
        switch self {
        case .replyStarted, .textDelta, .textDiscarded: false
        case .replied, .classifiedAsMeal, .replyHalted, .replyFailed: true
        }
    }

    init(_ event: Components.Schemas.ReplyStreamEvent) throws {
        switch event {
        case .replyStarted(let started):
            self = .replyStarted(replyId: try Self.uuid(started.replyId))
        case .textDelta(let delta):
            self = .textDelta(delta.text)
        case .textDiscarded:
            self = .textDiscarded
        case .replied(let replied):
            self = .replied(replyId: try Self.uuid(replied.replyId))
        case .classifiedAsMeal:
            self = .classifiedAsMeal
        case .replyHalted:
            self = .replyHalted
        case .replyFailed(let failed):
            let reason: SyncedSentTextStatus.FailureReason =
                switch failed.failureReason {
                case .retriesExhausted: .retriesExhausted
                case .badRequest: .badRequest
                }
            self = .replyFailed(reason)
        }
    }

    private static func uuid(_ text: String) throws -> UUID {
        guard let id = UUID(uuidString: text) else {
            throw NuToriAPIClient.MalformedResponseError(reason: "返事の ID が UUID でない: \(text)")
        }
        return id
    }
}
