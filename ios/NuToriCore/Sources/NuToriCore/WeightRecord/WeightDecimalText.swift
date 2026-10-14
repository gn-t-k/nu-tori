public enum WeightDecimalText {
    public static func sanitized(_ text: String) -> String {
        var whole = ""
        var fraction = ""
        var separated = false
        for character in text {
            if character.isNumber {
                if separated {
                    if fraction.isEmpty {
                        fraction.append(character)
                    }
                } else if whole.count < 4 {
                    whole.append(character)
                }
            } else if isSeparator(character), !separated, !whole.isEmpty {
                separated = true
            }
        }
        if separated {
            return whole + "." + fraction
        }
        return whole
    }

    /// 欄の文字（`sanitized` を通したもの）を kg の値として読む。末尾の小数点は無いものとし、空なら nil
    public static func kilograms(_ text: String) -> Double? {
        let core = text.hasSuffix(".") ? String(text.dropLast()) : text
        guard !core.isEmpty else { return nil }
        return Double(core)
    }

    private static func isSeparator(_ character: Character) -> Bool {
        character == "." || character == "," || character == "．" || character == "，"
    }
}
