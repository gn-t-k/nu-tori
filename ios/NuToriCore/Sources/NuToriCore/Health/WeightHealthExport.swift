public protocol WeightHealthExport: Sendable {
    func exportWeightRecord(_ record: WeightRecord) async throws
}
