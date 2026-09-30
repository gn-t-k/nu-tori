/// 取りに行って版が上がった手の記録を、ヘルスケアへ書き直す
public protocol WeightHealthExport: Sendable {
    func exportWeightRecord(_ record: WeightRecord) async throws
}
