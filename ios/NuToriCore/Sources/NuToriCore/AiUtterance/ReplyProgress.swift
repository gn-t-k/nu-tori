public import Foundation

/// 返事を待っている送った文章と、結果が出た送った文章。待っていた返事の結果が出た瞬間に触覚で知らせる合図にする。送り直した返事も同じ。
/// どの判定も、前に待っていなかった文章（開いたときに最初から結果が出ていた）では合図にしない。食事と読み分けた文章は、返事の結果にしない（食事の推定の結果で知らせる）
public struct ReplyProgress: Equatable, Sendable {
    /// `items` はタイムラインに置くもの。送った文章の吹き出しと返事だけを見る
    public init(items: [Timeline.Item]) {
        var waiting: Set<UUID> = []
        var failed: Set<UUID> = []
        for case .sentText(let bubble) in items {
            switch bubble.replyLine {
            case .reading: waiting.insert(bubble.sentText.id)
            case .halted, .failed: failed.insert(bubble.sentText.id)
            case nil: break
            }
        }
        self.waiting = waiting
        self.failed = failed
        replied = Set(
            items.compactMap { item in
                if case .reply(let reply) = item, !reply.body.isEmpty {
                    reply.sentTextId
                } else {
                    nil
                }
            })
    }

    /// 前に待っていた文章のうち、返事の最初の文字が届いたものがあるか
    public func hasReplied(since earlier: ReplyProgress) -> Bool {
        !earlier.waiting.isDisjoint(with: replied)
    }

    /// 前に待っていた文章のうち、返事を作れなかった・止めたものがあるか
    public func hasFailed(since earlier: ReplyProgress) -> Bool {
        !earlier.waiting.isDisjoint(with: failed)
    }

    private let waiting: Set<UUID>
    private let replied: Set<UUID>
    private let failed: Set<UUID>
}
