#if DEBUG
    import NuToriCore

    extension AccountActions {
        /// プレビューで押しても何もしない操作
        static var noop: AccountActions {
            AccountActions(
                signedInAccountId: { nil },
                turnOnUsageData: {},
                turnOffUsageData: {},
                deleteAccount: { nil },
                notificationPermission: { .permitted },
                openedNotificationSettings: {},
                autoRenewal: { .unknown },
                accountDeletionGuide: { nil },
                rereadAccountDeletionGuide: { $0 },
                openedAccountDeletionGuide: {},
                openedManageSubscriptions: {}
            )
        }
    }
#endif
