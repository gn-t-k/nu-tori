public import Foundation

/// 記録の中身と体重の値は送らない
public struct WeightEntryObservation: Sendable, Equatable {
    public private(set) var method: ClientUsageEvent.WeightInputMethod
    public private(set) var stepperPressCount: Int
    public private(set) var showedTypoHint: Bool
    public let openedAt: Date

    public init(startsWithKeyboard: Bool, openedAt: Date) {
        method = startsWithKeyboard ? .keyboard : .stepper
        stepperPressCount = 0
        showedTypoHint = false
        self.openedAt = openedAt
    }

    public mutating func stepped() {
        method = .stepper
        stepperPressCount += 1
    }

    public mutating func typed() {
        method = .keyboard
    }

    public mutating func noteTypoHintShown() {
        showedTypoHint = true
    }

    public func recordedEvent(at recordedAt: Date) -> ClientUsageEvent {
        let elapsed = max(0, recordedAt.timeIntervalSince(openedAt))
        return .weightRecorded(
            method: method,
            stepperPressCount: stepperPressCount,
            duration: .seconds(elapsed),
            showedTypoHint: showedTypoHint
        )
    }
}
