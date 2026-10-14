/// 目標を決める前に見せる1日の目安（kcal と P・F・C の g）
public struct DailyGuidePlan: Sendable, Equatable {
    public let energyKilocalories: Int
    public let proteinGrams: Int
    public let fatGrams: Int
    public let carbohydrateGrams: Int

    public init(energyKilocalories: Int, proteinGrams: Int, fatGrams: Int, carbohydrateGrams: Int) {
        self.energyKilocalories = energyKilocalories
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.carbohydrateGrams = carbohydrateGrams
    }
}
