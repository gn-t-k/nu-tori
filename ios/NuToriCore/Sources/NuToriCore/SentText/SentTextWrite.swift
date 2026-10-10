public import Foundation

/// 送った文章の書き込み。送り待ちの置き場には、送った文章の種類の名前と、この中身の JSON で入る。
/// 送り直す2つは、断られたときに控えから見分けて1行を選べるよう、直す書き込みにせず操作ごとに分ける
public enum SentTextWrite: PendingWriteBody {
    case create(SentText)
    /// 食事と読み分けた文章を、会話として送り直す
    case resendAsConversation(sentTextId: UUID)
    /// 返事を作れなかった・回数切れの文章を送り直す
    case resend(sentTextId: UUID)

    public static var kindName: RecordKindName { SentTextSyncing.kindName }

    public var stored: Stored { Stored(self) }

    public init?(stored: Stored) {
        guard let write = stored.write() else { return nil }
        self = write
    }

    /// 書き込みが指す送った文章
    public var sentTextId: UUID {
        switch self {
        case .create(let sentText): sentText.id
        case .resendAsConversation(let sentTextId), .resend(let sentTextId): sentTextId
        }
    }

    /// 送り待ちに保存する JSON。キーを足すときは、無くても読める形にする（`docs/agents/sync.md`「置き場の約束」）
    public enum Stored: Codable {
        case create(StoredSentText)
        case resendAsConversation(sentTextId: UUID)
        case resend(sentTextId: UUID)

        init(_ write: SentTextWrite) {
            switch write {
            case .create(let sentText): self = .create(StoredSentText(sentText))
            case .resendAsConversation(let sentTextId):
                self = .resendAsConversation(sentTextId: sentTextId)
            case .resend(let sentTextId): self = .resend(sentTextId: sentTextId)
            }
        }

        func write() -> SentTextWrite? {
            switch self {
            case .create(let stored): stored.sentText().map { .create($0) }
            case .resendAsConversation(let sentTextId):
                .resendAsConversation(sentTextId: sentTextId)
            case .resend(let sentTextId): .resend(sentTextId: sentTextId)
            }
        }
    }

    public struct StoredSentText: Codable {
        let id: UUID
        let body: String
        let sentAt: Date
        let timeZoneIdentifier: String

        init(_ sentText: SentText) {
            id = sentText.id
            body = sentText.body
            sentAt = sentText.sentAt
            timeZoneIdentifier = sentText.timeZone.identifier
        }

        func sentText() -> SentText? {
            TimeZone(identifier: timeZoneIdentifier).map {
                SentText(id: id, body: body, sentAt: sentAt, timeZone: $0)
            }
        }
    }
}

/// 送った文章の送り待ち
public typealias PendingSentTextWrite = Pending<SentTextWrite>
