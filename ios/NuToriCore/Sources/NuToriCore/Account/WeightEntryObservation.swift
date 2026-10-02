public import Foundation

/// 体重のシートと、体重の知らせの中の手数。記録の中身と体重の値は送らない
public struct WeightEntryObservation: Sendable, Equatable {
    public private(set) var method: ClientUsageEvent.WeightInputMethod
    public private(set) var stepperPressCount: Int
    public private(set) var showedTypoHint: Bool
    public let openedAt: Date

    /// 体重のシートを開いたとき
    public init(startsWithKeyboard: Bool, openedAt: Date) {
        self.init(method: startsWithKeyboard ? .keyboard : .stepper, openedAt: openedAt)
    }

    /// 体重の知らせの中。所要時間は、カードが見えてから記録までにする
    public static func inNotice(shownAt: Date) -> WeightEntryObservation {
        WeightEntryObservation(method: .notice, openedAt: shownAt)
    }

    public mutating func stepped() {
        switchMethod(to: .stepper)
        stepperPressCount += 1
    }

    public mutating func typed() {
        switchMethod(to: .keyboard)
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

    private init(method: ClientUsageEvent.WeightInputMethod, openedAt: Date) {
        self.method = method
        stepperPressCount = 0
        showedTypoHint = false
        self.openedAt = openedAt
    }

    /// 知らせの中では、ステッパーとキーボードのどちらで入れても、入れ方は知らせの中のままにする
    private mutating func switchMethod(to sheetMethod: ClientUsageEvent.WeightInputMethod) {
        switch method {
        case .notice:
            return
        case .stepper, .keyboard:
            method = sheetMethod
        }
    }
}
