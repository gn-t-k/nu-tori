import Foundation
import NuToriCore

/// タイムラインの会話の操作。どれも確かめずに、その場で送り待ちに並ぶ
struct ConversationActions {
    /// 文章の食事のカードの「会話として送り直す」。`deletedMealCount` は、その場で消える文章の食事の数
    let resendAsConversation: (_ sentTextId: UUID, _ deletedMealCount: Int) async -> Void
    /// 作れなかった・回数切れの1行の「送り直す」
    let resend: (_ sentTextId: UUID, _ reason: ClientUsageEvent.ReplyRegenerateReason) async -> Void

    /// 会話を描かない見本の画面に渡す
    static let none = ConversationActions(
        resendAsConversation: { _, _ in }, resend: { _, _ in })
}
