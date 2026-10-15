public import Foundation

/// 答えていない知らせの1行を、帯の下に出すか。タイムラインはカードを遠くへ送ると描かなくなり、位置が届かなくなるので、
/// 最後に届いた位置で、上へ流れたかを覚えておく
public struct UnansweredNoticeLineVisibility: Equatable, Sendable {
    public init() {
        noticeIdsAbove = []
    }

    /// 答えていない知らせのカードの位置を受け取る。カードを描いていなければ nil で、覚えた向きを変えない
    public mutating func note(_ position: CardPosition?) {
        guard let position else { return }
        if position.maxY <= 0 {
            noticeIdsAbove.insert(position.noticeId)
        } else {
            noticeIdsAbove.remove(position.noticeId)
        }
    }

    /// その1行の知らせのカードが、画面の上へ流れて見えないか。
    /// カードを置いた日を並べていなければ、上にある（並べるのは新しいほうの日だけで、並べていない日はそれより古い）。
    /// 開き直したときは、何日も前のカードを並べておらず位置が届かないので、こうして決める
    /// - Parameter listedDays: タイムラインに並べている日（`TimelineViewport.listedDays(of:)`）
    public func shows(_ line: UnansweredNoticeLine, listedDays: ArraySlice<Timeline.Day>) -> Bool {
        let noticeId = line.notice.id
        let isListed = listedDays.contains { $0.items.contains { $0.noticeId == noticeId } }
        return !isListed || noticeIdsAbove.contains(noticeId)
    }

    public struct CardPosition: Equatable, Sendable {
        public let noticeId: UUID
        /// カードの下端。タイムラインの見えている範囲の上端から下向きに測る
        public let maxY: Double

        public init(noticeId: UUID, maxY: Double) {
            self.noticeId = noticeId
            self.maxY = maxY
        }
    }

    /// 上へ流れて見えない知らせの ID。体重の知らせと目標を立てる知らせは、別々に流れる
    private var noticeIdsAbove: Set<UUID>
}
