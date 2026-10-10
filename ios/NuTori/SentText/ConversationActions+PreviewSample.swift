#if DEBUG
    extension ConversationActions {
        /// プレビューで押しても何もしない操作
        static let noop = ConversationActions(
            resendAsConversation: { _, _ in }, resend: { _, _ in })
    }
#endif
