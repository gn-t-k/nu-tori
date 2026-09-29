public import Foundation

public struct HealthChanges: Sendable, Equatable {
    public let weights: [WeightSample]
    public let bodyFats: [BodyFatSample]
    public let deletions: [Deletion]
    /// 次の問い合わせの続き。この回の分を取り込み終えたら保存する
    public let anchor: HealthAnchor

    public init(
        weights: [WeightSample],
        bodyFats: [BodyFatSample],
        deletions: [Deletion],
        anchor: HealthAnchor
    ) {
        self.weights = weights
        self.bodyFats = bodyFats
        self.deletions = deletions
        self.anchor = anchor
    }

    public struct WeightSample: Sendable, Equatable {
        public let sampleId: UUID
        public let kilograms: Double
        public let instant: Date
        public let sourceAppName: String
        public let sourceBundleId: String
        /// サンプルの時間帯のメタデータ。書いたアプリが付けていなければ nil
        public let timeZone: TimeZone?

        public init(
            sampleId: UUID,
            kilograms: Double,
            instant: Date,
            sourceAppName: String,
            sourceBundleId: String,
            timeZone: TimeZone?
        ) {
            self.sampleId = sampleId
            self.kilograms = kilograms
            self.instant = instant
            self.sourceAppName = sourceAppName
            self.sourceBundleId = sourceBundleId
            self.timeZone = timeZone
        }
    }

    public struct BodyFatSample: Sendable, Equatable {
        public let sampleId: UUID
        /// ヘルスケアの割合（0.25）
        public let fraction: Double
        public let instant: Date
        public let sourceBundleId: String

        public init(sampleId: UUID, fraction: Double, instant: Date, sourceBundleId: String) {
            self.sampleId = sampleId
            self.fraction = fraction
            self.instant = instant
            self.sourceBundleId = sourceBundleId
        }
    }

    /// 消えたサンプルは UUID しか分からないので、どの種類だったかを層が添える
    public enum Deletion: Sendable, Equatable {
        case weight(sampleId: UUID)
        case bodyFat(sampleId: UUID)
    }
}
