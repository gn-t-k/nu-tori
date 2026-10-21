#if DEBUG
    import NuToriAPI
    import NuToriCore

    extension PaywallActions {
        /// プレビューで使う口。App Store にもサーバーにもつながない
        static var noop: PaywallActions {
            PaywallActions(
                clock: .live,
                purchases: SubscriptionPurchases(
                    store: UITestSubscriptionStore(),
                    client: NuToriAPIClient(
                        environment: .development,
                        appBuildGate: AppBuildGate(build: 0, reportVerdict: { _ in }),
                        sessionToken: { nil }),
                    applyReportedChanges: { _ in }),
                capture: { _ in }
            )
        }
    }
#endif
