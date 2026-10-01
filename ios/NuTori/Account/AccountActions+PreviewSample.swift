#if DEBUG
    extension AccountActions {
        /// プレビューで押しても何もしない操作
        static var noop: AccountActions {
            AccountActions(
                signedInAccountId: { nil },
                turnOnUsageData: {},
                turnOffUsageData: {},
                deleteAccount: { nil }
            )
        }
    }
#endif
