public import Foundation
public import NuToriAPI

/// 見守る要求で受け取っている途中の返事。記録に残らず、同じ ID の返事が届いたら置き換わる
public struct ReplyStream: Hashable, Sendable {
    /// 返事の ID。生成を始めるまで nil
    public private(set) var replyId: UUID?
    /// できた分をつないだ文。最初の文字が届くまでと、流し直しの知らせのあとは空
    public private(set) var text: String

    public init() {
        replyId = nil
        text = ""
    }

    public mutating func receive(_ event: ReplyStreamEvent) {
        switch event {
        case .replyStarted(let replyId):
            // つなぎ直したときは、このあとにそこまでの分がまとめて届く
            self.replyId = replyId
            text = ""
        case .textDelta(let delta):
            text += delta
        case .textDiscarded:
            text = ""
        case .replied(let replyId):
            self.replyId = replyId
        case .classifiedAsMeal, .replyHalted, .replyFailed:
            text = ""
        }
    }

    /// タイムラインに置く伸びている返事。最初の文字が届くまでは nil
    func growingReply(sentTextId: UUID) -> TimelineReply? {
        guard let replyId, !text.isEmpty else { return nil }
        return TimelineReply(
            id: replyId, sentTextId: sentTextId, body: text, isGrowing: true, referencedMeals: [])
    }
}
