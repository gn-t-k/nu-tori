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

extension DailyGuidePlan {
    init(_ wire: Components.Schemas.DailyGuidePlan) {
        self.init(
            energyKilocalories: wire.energyKcal, proteinGrams: wire.proteinG, fatGrams: wire.fatG,
            carbohydrateGrams: wire.carbohydrateG)
    }
}

extension Components.Schemas.DailyGuidePlan {
    init(_ plan: DailyGuidePlan) {
        self.init(
            energyKcal: plan.energyKilocalories, proteinG: plan.proteinGrams, fatG: plan.fatGrams,
            carbohydrateG: plan.carbohydrateGrams)
    }
}
