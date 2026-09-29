public enum WeightDecimalText {
    /// 小数第1位まで。整数は4桁まで。それ以外の文字は落とす
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

    private static func isSeparator(_ character: Character) -> Bool {
        character == "." || character == "," || character == "．" || character == "，"
    }
}
