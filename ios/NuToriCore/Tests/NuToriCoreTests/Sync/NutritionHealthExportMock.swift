import Foundation
import NuToriCore

final class NutritionHealthExportMock: NutritionHealthExport, @unchecked Sendable {
    private(set) var exportCount = 0

    static func ok() -> NutritionHealthExportMock {
        NutritionHealthExportMock(failure: nil)
    }

    static func error(_ error: any Error) -> NutritionHealthExportMock {
        NutritionHealthExportMock(failure: error)
    }

    func exportNutrition() async throws {
        exportCount += 1
        if let failure { throw failure }
    }

    private let failure: (any Error)?

    private init(failure: (any Error)?) {
        self.failure = failure
    }
}
