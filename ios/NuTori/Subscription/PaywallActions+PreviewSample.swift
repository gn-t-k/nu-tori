#if DEBUG
    import NuToriAPI
    import NuToriCore

    extension PaywallActions {
        /// プレビューで使う口。App Store にもサーバーにもつながない
        static var noop: PaywallActions {
            PaywallActions(
                purchases: SubscriptionPurchases(
                    // App Store につながない StoreKit の口と、メモリ上の偽の同期サーバーを、UI テストと同じく使う
                    store: UITestSubscriptionStore(purchaseResult: .cancels),
                    client: NuToriAPIClient(
                        serverURL: APIEnvironment.development.serverURL,
                        transport: FakeSyncServer(.init(records: [], startedOn: "2026-10-01")),
                        appBuildGate: AppBuildGate(build: 0, reportVerdict: { _ in }),
                        sessionToken: { nil }),
                    applyReportedChanges: { _ in }),
                capture: { _ in },
                storefront: .storeKit
            )
        }
    }
#endif
