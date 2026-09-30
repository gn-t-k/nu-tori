import Foundation

@testable import NuToriAPI

extension NewWeightRecord {
    static func fixture(imported: SyncedWeightRecord.Imported? = nil) -> NewWeightRecord {
        NewWeightRecord(
            id: UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!,
            weightKilograms: 72.4,
            measuredAt: Date(timeIntervalSince1970: 1_767_225_600.123),
            timeZone: TimeZone(identifier: "Asia/Tokyo")!,
            imported: imported
        )
    }
}
