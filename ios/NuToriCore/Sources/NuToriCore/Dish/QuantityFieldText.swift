import Foundation

/// 料理の画面の、料理と材料の量の数字の欄の文字。単位は欄の外に添えるので、欄には数だけを入れる
public enum QuantityFieldText {
    /// 「2」「1.5」。小数は1桁まで（`NutritionText.quantity` と同じ数）
    public static func text(_ quantity: Double) -> String {
        NutritionText.quantityNumber(quantity)
    }

    /// 打った文字を数として読む。地域の設定で数字のキーボードの小数点が「,」になるので、「.」と同じに読む。
    /// 末尾の小数点は無いものとして読む。空と数でない文字は nil（画面は前の値に戻す）
    public static func value(typed text: String) -> Double? {
        var core = text.replacingOccurrences(of: ",", with: ".")
        if core.hasSuffix(".") { core.removeLast() }
        guard !core.isEmpty else { return nil }
        return Double(core)
    }
}
