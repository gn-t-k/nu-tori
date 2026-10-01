import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport

extension SyncEngine {
    static let fixtureNow = Date(timeIntervalSince1970: 1_767_225_600)
    static let fixtureAccountId = "5b1f2c1e-3a58-4d5b-9c0e-8f7a6d5c4b3a"

    static func fixture(
        store: SyncBoxMock<RecordCacheMock>,
        transport: ClientTransportMock,
        accountId: String = fixtureAccountId,
        readableKinds: Set<RecordKindName> = [.weightRecord],
        errorReporting: ErrorReportingSessionMock = .ok(),
        weightHealthExport: any WeightHealthExport = WeightHealthExportMock.ok(),
        mealPhotos: MealPhotos = .fixture()
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
            readableKinds: readableKinds,
            errorReporting: errorReporting,
            weightHealthExport: weightHealthExport,
            mealPhotos: mealPhotos
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

    static func correcting(_ record: WeightRecord) -> PendingWrite {
        PendingWrite(
            writeId: UUID(),
            enqueuedAt: SyncEngine.fixtureNow,
            operation: .correctWeightRecord(record)
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
        readableKinds: Set<RecordKindName> = [.weightRecord]
    ) -> SyncState {
        SyncState(
            afterSequence: afterSequence,
            hasCompletedInitialPull: hasCompletedInitialPull,
            readableKinds: readableKinds,
            startedOn: nil
        )
    }
}
