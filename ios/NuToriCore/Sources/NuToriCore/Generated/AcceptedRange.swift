// shared/accepted-ranges.json から書き出した。直すときは JSON を直し、scripts/check ios --fix で書き出し直す

public enum AcceptedRange {
    case bodyFatPercentage
    case weightKilograms

    public var bounds: ClosedRange<Double> {
        switch self {
        case .bodyFatPercentage: 1.0...75.0
        case .weightKilograms: 20.0...300.0
        }
    }
}
