public import Foundation

/// 送り待ちの中身。種類の名前と、送り待ちの置き場に入れる JSON を決める。
/// JSON の形は、置き場の版を上げずに読めるよう `docs/agents/sync.md` の「置き場の約束」に従う
public protocol PendingWriteBody: Sendable, Equatable {
    /// この中身を入れる送り待ちの種類の名前
    var kindName: RecordKindName { get }

    func content() throws -> Data

    /// 送り待ちの中身を読む。読めなければ `PendingEntry.InvalidContentError`
    init(kind: RecordKindName, content: Data) throws
}
