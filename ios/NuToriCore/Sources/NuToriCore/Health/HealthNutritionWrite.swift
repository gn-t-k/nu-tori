public import Foundation

/// ヘルスケアに書く、料理1つ分の食品の組。同じ同期 ID で書くと、版が大きいほうで置き換わる
public struct HealthNutritionWrite: Sendable, Equatable {
    /// 料理の ID
    public let syncId: UUID
    /// 料理の版
    public let syncVersion: Int
    /// 食品名。料理の名前
    public let foodName: String
    /// 食事の撮った時刻
    public let instant: Date
    /// 時間帯のメタデータに付ける名前（`GMT+0900` の形）
    public let timeZoneName: String
    /// 書く値。1つ以上ある
    public let values: [Value]

    public struct Value: Sendable, Equatable {
        public let nutrient: HealthNutrient
        /// `nutrient.unit` の単位での値
        public let amount: Double

        public init(nutrient: HealthNutrient, amount: Double) {
            self.nutrient = nutrient
            self.amount = amount
        }
    }

    public init(
        syncId: UUID,
        syncVersion: Int,
        foodName: String,
        instant: Date,
        timeZoneName: String,
        values: [Value]
    ) {
        self.syncId = syncId
        self.syncVersion = syncVersion
        self.foodName = foodName
        self.instant = instant
        self.timeZoneName = timeZoneName
        self.values = values
    }

    /// 料理の合計のうち、値が分かり、書き込みを許可された種類だけで組を作る。書く値が1つも無ければ nil
    /// （値の無い組は保存できない）
    public init?(dish contents: DishContents, of meal: Meal, authorized: Set<HealthNutrient>) {
        let values = HealthNutrient.allCases.compactMap { nutrient -> Value? in
            guard authorized.contains(nutrient),
                let shown = contents.totals[nutrient.source].value
            else {
                return nil
            }
            return Value(nutrient: nutrient, amount: nutrient.writtenAmount(fromShown: shown))
        }
        guard !values.isEmpty else { return nil }
        self.init(
            syncId: contents.dish.id,
            syncVersion: contents.dish.version,
            foodName: contents.dish.name,
            instant: meal.eatenAt,
            timeZoneName: Self.timeZoneName(utcOffsetSeconds: meal.eatenUtcOffsetSeconds),
            values: values
        )
    }

    /// 食事の時差から作る時間帯の名前。食事は IANA 名を持たないので、`GMT+0900` の形にする。
    /// 時差が 0 のときは `GMT`。分に満たない秒は切り捨てる
    public static func timeZoneName(utcOffsetSeconds: Int) -> String {
        let minutes = abs(utcOffsetSeconds) / 60
        guard minutes > 0 else { return "GMT" }
        let sign = utcOffsetSeconds < 0 ? "-" : "+"
        return "GMT\(sign)\(twoDigits(minutes / 60))\(twoDigits(minutes % 60))"
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
