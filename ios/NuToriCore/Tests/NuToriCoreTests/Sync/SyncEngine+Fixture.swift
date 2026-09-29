import Foundation
import NuToriCore

@testable import NuToriAPI

extension SyncEngine {
    static let fixtureNow = Date(timeIntervalSince1970: 1_767_225_600)
    static let fixtureAccountId = "5b1f2c1e-3a58-4d5b-9c0e-8f7a6d5c4b3a"

    static func fixture(
        store: SyncStoreMock,
        transport: ClientTransportMock,
        accountId: String = fixtureAccountId,
        readableKindsVersion: Int = 1
    ) -> SyncEngine {
        SyncEngine(
            store: store,
            client: NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: transport,
                sessionToken: { "session-1" }
            ),
            accountId: accountId,
            device: SyncDevice(
                deviceId: UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!,
                appVersion: "1.0.0",
                osVersion: "26.0"
            ),
            timeZone: { TimeZone(identifier: "Asia/Tokyo")! },
            now: { fixtureNow },
            readableKindsVersion: readableKindsVersion
        )
    }
}

extension PendingWrite {
    static func creating(_ record: WeightRecord, ageSeconds: TimeInterval = 0) -> PendingWrite {
        PendingWrite(
            writeId: UUID(),
            enqueuedAt: SyncEngine.fixtureNow.addingTimeInterval(-ageSeconds),
            operation: .createWeightRecord(record)
        )
    }

    static func correcting(
        _ record: WeightRecord,
        previous: WeightRecord
    ) -> PendingWrite {
        PendingWrite(
            writeId: UUID(),
            enqueuedAt: SyncEngine.fixtureNow,
            operation: .correctWeightRecord(record, previous: previous)
        )
    }
}

extension AccountSettings {
    static func fixture(sendsUsageData: Bool) -> AccountSettings {
        AccountSettings(
            id: AccountSettings.id(forAccountId: SyncEngine.fixtureAccountId),
            sendsUsageData: sendsUsageData
        )
    }
}

extension SyncState {
    static func fixture(
        afterSequence: Int = 0,
        hasCompletedInitialPull: Bool = false,
        readableKindsVersion: Int = 1
    ) -> SyncState {
        SyncState(
            afterSequence: afterSequence,
            hasCompletedInitialPull: hasCompletedInitialPull,
            readableKindsVersion: readableKindsVersion,
            startedOn: nil
        )
    }
}
