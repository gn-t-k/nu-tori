public import Foundation

/// 答えていない知らせの1行を、帯の下に出すか。タイムラインはカードを遠くへ送ると描かなくなり、位置が届かなくなるので、
/// 最後に届いた位置で、上へ流れたかを覚えておく
public struct UnansweredNoticeLineVisibility: Equatable, Sendable {
    public init() {
        noticeIdAbove = nil
    }

    /// 今日の答えていない知らせのカードの位置を受け取る。カードを描いていなければ nil で、覚えた向きを変えない
    public mutating func note(_ position: CardPosition?) {
        guard let position else { return }
        noticeIdAbove = position.maxY <= 0 ? position.noticeId : nil
    }

    /// そのカードが答えていない形で、画面の上へ流れて見えないか
    public func shows(for card: NoticeCard) -> Bool {
        card.form == .awaitingAnswer && card.notice.id == noticeIdAbove
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

    /// 上へ流れて見えない知らせの ID
    private var noticeIdAbove: UUID?
}
