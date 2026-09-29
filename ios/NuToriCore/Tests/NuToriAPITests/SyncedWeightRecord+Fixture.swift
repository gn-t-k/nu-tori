import Foundation

@testable import NuToriAPI

extension SyncedWeightRecord {
    static func fixture(
        weightKilograms: Double = 72.4,
        version: Int = 2,
        imported: Imported? = nil
    ) -> SyncedWeightRecord {
        SyncedWeightRecord(
            id: UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!,
            weightKilograms: weightKilograms,
            measuredAt: Date(timeIntervalSince1970: 1_767_225_600.123),
            timeZone: TimeZone(identifier: "Asia/Tokyo")!,
            version: version,
            imported: imported
        )
    }
}
