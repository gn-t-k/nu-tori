public import Foundation

/// 送り待ちの中身。種類の名前と、送り待ちの置き場に入れる JSON の形（`Stored`）を決める。
/// JSON への変換と、読めないときのエラーは、ここの既定の実装だけが持つ。
/// JSON の形は、置き場の版を上げずに読めるよう `docs/agents/sync.md` の「置き場の約束」に従う
public protocol PendingWriteBody: Sendable, Equatable {
    /// 置き場に入れる JSON の形。中身は NuToriCore の中でだけ読む
    associatedtype Stored: Codable

    /// この中身を入れる送り待ちの種類の名前
    var kindName: RecordKindName { get }

    var stored: Stored { get }

    /// 読めた JSON の形を中身にする。この種類の書き込みとして読めなければ nil
    init?(stored: Stored)
}

extension PendingWriteBody {
    public func content() throws -> Data {
        try JSONEncoder().encode(stored)
    }

    /// 送り待ちの中身を読む。読めなければ `PendingEntry.InvalidContentError`
    public init(kind: RecordKindName, content: Data) throws {
        guard let stored = try? JSONDecoder().decode(Stored.self, from: content),
            let write = Self(stored: stored)
        else {
            throw PendingEntry.InvalidContentError(kind: kind)
        }
        self = write
    }
}
