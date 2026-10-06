// shared/accepted-ranges.json から書き出した。直すときは JSON を直し、scripts/check ios --fix で書き出し直す

public enum AcceptedRange {
    case bodyFatPercentage
    case dishNameTrimmedLength
    case dishQuantity
    case ingredientQuantity
    case mealPhotoCount
    case mealUtcOffsetSeconds
    case weightKilograms

    public var bounds: AcceptedBounds {
        switch self {
        case .bodyFatPercentage:
            AcceptedBounds(
                lowerBound: 1.0, includesLowerBound: true, upperBound: 75.0)
        case .dishNameTrimmedLength:
            AcceptedBounds(
                lowerBound: 1.0, includesLowerBound: true, upperBound: .infinity)
        case .dishQuantity:
            AcceptedBounds(
                lowerBound: 0.0, includesLowerBound: false, upperBound: .infinity)
        case .ingredientQuantity:
            AcceptedBounds(
                lowerBound: 0.0, includesLowerBound: false, upperBound: .infinity)
        case .mealPhotoCount:
            AcceptedBounds(
                lowerBound: 1.0, includesLowerBound: true, upperBound: 4.0)
        case .mealUtcOffsetSeconds:
            AcceptedBounds(
                lowerBound: -43200.0, includesLowerBound: true, upperBound: 50400.0)
        case .weightKilograms:
            AcceptedBounds(
                lowerBound: 20.0, includesLowerBound: true, upperBound: 300.0)
        }
    }
}

/// 下限を含むかは範囲ごとに決まる。上限は含み、無い範囲では無限大
public struct AcceptedBounds: Sendable {
    public let lowerBound: Double
    public let includesLowerBound: Bool
    public let upperBound: Double

    public func contains(_ value: Double) -> Bool {
        (includesLowerBound ? lowerBound <= value : lowerBound < value) && value <= upperBound
    }
}
