import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport

extension SubscriptionPurchases {
    static func fixture(
        store: SubscriptionStoreMock,
        transport: ClientTransportMock,
        applyReportedChanges: @escaping @Sendable ([SyncChange]) async throws -> Void = { _ in },
        newRequestId: @escaping @Sendable () -> UUID = { UUID() }
    ) -> SubscriptionPurchases {
        SubscriptionPurchases(
            store: store,
            client: NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: transport,
                appBuildGate: .sample,
                sessionToken: { "session-1" }
            ),
            applyReportedChanges: applyReportedChanges,
            newRequestId: newRequestId
        )
    }
}
