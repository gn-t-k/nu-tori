public import Foundation

/// 親の ID で引く状態の記録（食事の推定の状態、料理ごとの推定の状態、送った文章の状態）。
/// 親とは別の種類で親より先にも届くので、親の ID を値で持つ
public protocol ParentKeyedStatus {
    associatedtype Value

    var parentId: UUID { get }
    var status: Value { get }
}

extension Sequence where Element: ParentKeyedStatus {
    /// 親の ID ごとの状態。親より先に届いた状態も含む。同じ親の状態が重なっていたら、あとの状態を取る
    public func statusesByParentId() -> [UUID: Element.Value] {
        Dictionary(map { ($0.parentId, $0.status) }, uniquingKeysWith: { _, last in last })
    }
}
