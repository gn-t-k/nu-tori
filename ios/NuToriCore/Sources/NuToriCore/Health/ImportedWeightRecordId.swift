public import Foundation

/// ヘルスケアから取り込んだ体重記録の ID。サンプルの UUID から決まるので、全期間を読み直しても二重にならない
public enum ImportedWeightRecordId {
    public static func make(healthKitSampleId: UUID) -> UUID {
        UUIDv5.make(namespace: namespace, name: healthKitSampleId.uuidString.lowercased())
    }

    // 体重記録の ID にだけ使う名前空間。変えると、取り込み済みの記録が別の ID で二重に入る
    static let namespace = UUID(uuidString: "8845A3FB-2EB2-4CE0-9086-6EAC6AE6D610")!
}
