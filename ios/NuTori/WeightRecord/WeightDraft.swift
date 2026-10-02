import NuToriCore

/// 入れている途中の体重の値。前回の値から始め、ステッパーとキーボードで変える
struct WeightDraft {
    var initialTenths: Int?
    var text: String
    var replacesOnNextInput: Bool

    init(_ entry: WeightEntry) {
        switch entry.initialValue {
        case .empty:
            initialTenths = nil
            text = ""
            replacesOnNextInput = false
        case .previous(let kilograms, _):
            let tenths = Int((kilograms * 10).rounded())
            initialTenths = tenths
            text = Self.decimal(tenths)
            replacesOnNextInput = false
        }
    }

    var tenths: Int? {
        Self.tenths(parsing: text)
    }

    var kilograms: Double? {
        guard let tenths else { return nil }
        return Double(tenths) / 10
    }

    var startsWithKeyboard: Bool {
        initialTenths == nil
    }

    mutating func beginTyping() {
        replacesOnNextInput = tenths != nil
    }

    mutating func applyTyped(previous: String, next: String) {
        let raw: String
        if replacesOnNextInput {
            replacesOnNextInput = false
            raw = next.count > previous.count ? Self.inserted(from: previous, to: next) : next
        } else {
            raw = next
        }
        let sanitized = WeightDecimalText.sanitized(raw)
        if text != sanitized {
            text = sanitized
        }
    }

    mutating func step(by delta: Int) {
        guard let tenths else { return }
        let next = tenths + delta
        if next < Self.minimumTenths && delta < 0 { return }
        if next > Self.maximumTenths && delta > 0 { return }
        replacesOnNextInput = false
        text = Self.decimal(next)
    }

    static var minimumTenths: Int {
        Int(AcceptedRange.weightKilograms.bounds.lowerBound * 10)
    }

    static var maximumTenths: Int {
        Int(AcceptedRange.weightKilograms.bounds.upperBound * 10)
    }

    private static func decimal(_ tenths: Int) -> String {
        let absolute = abs(tenths)
        return "\(absolute / 10).\(absolute % 10)"
    }

    private static func tenths(parsing text: String) -> Int? {
        let core = text.hasSuffix(".") ? String(text.dropLast()) : text
        guard !core.isEmpty, let value = Double(core) else { return nil }
        return Int((value * 10).rounded())
    }

    /// 先頭か末尾に足した文字。選択を置き換えたときは、増えた部分だけを返す
    private static func inserted(from previous: String, to next: String) -> String {
        let previousCharacters = Array(previous)
        let nextCharacters = Array(next)
        var prefix = 0
        while prefix < previousCharacters.count && prefix < nextCharacters.count
            && previousCharacters[prefix] == nextCharacters[prefix]
        {
            prefix += 1
        }
        var suffix = 0
        while suffix < previousCharacters.count - prefix && suffix < nextCharacters.count - prefix
            && previousCharacters[previousCharacters.count - 1 - suffix]
                == nextCharacters[nextCharacters.count - 1 - suffix]
        {
            suffix += 1
        }
        return String(nextCharacters[prefix..<(nextCharacters.count - suffix)])
    }
}
