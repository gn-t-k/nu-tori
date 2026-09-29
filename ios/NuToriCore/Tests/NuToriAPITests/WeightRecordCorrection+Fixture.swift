import Foundation

@testable import NuToriAPI

extension WeightRecordCorrection {
    static func fixture() -> WeightRecordCorrection {
        WeightRecordCorrection(
            id: UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!,
            weightKilograms: 72.4,
            measuredAt: Date(timeIntervalSince1970: 1_767_225_600.123),
            timeZone: TimeZone(identifier: "Asia/Tokyo")!,
            version: 2
        )
    }
}
