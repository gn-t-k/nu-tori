import Foundation
import NuToriCore

final class WeightHealthExportMock: WeightHealthExport, @unchecked Sendable {
    private(set) var writes: [WeightRecord] = []
    private let failure: (any Error)?

    static func ok() -> WeightHealthExportMock {
        WeightHealthExportMock(failure: nil)
    }

    static func error(_ error: any Error) -> WeightHealthExportMock {
        WeightHealthExportMock(failure: error)
    }

    func exportWeightRecord(_ record: WeightRecord) async throws {
        if let failure { throw failure }
        writes.append(record)
    }

    private init(failure: (any Error)?) {
        self.failure = failure
    }
}
