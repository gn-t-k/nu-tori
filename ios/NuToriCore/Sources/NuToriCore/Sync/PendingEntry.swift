public import Foundation

/// 送り待ちの1件。「種類の名前＋中身」で持つ。種類を足しても、置き場の形は変わらない
public struct PendingEntry: Sendable, Equatable {
    public let writeId: UUID
    public let enqueuedAt: Date
    /// 記録の種類の名前。登録簿に無い名前の送り待ちを送ろうとすると、`UnknownRecordKindError` になる
    public let kind: String
    /// 種類が決める中身。置き場は読まない
    public let content: Data

    public init(writeId: UUID, enqueuedAt: Date, kind: String, content: Data) {
        self.writeId = writeId
        self.enqueuedAt = enqueuedAt
        self.kind = kind
        self.content = content
    }
}
