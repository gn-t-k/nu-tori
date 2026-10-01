import NuToriCore
import SwiftUI

/// たんぱく質・脂質・炭水化物。1日の丸と、合計の P・F・C の並び（この順）に使う。
/// 色はアセットカタログに High Contrast の版と一緒に持つ（DESIGN.md の Colors）
enum PFC: CaseIterable {
    case protein
    case fat
    case carbohydrate

    var nutrient: Nutrient {
        switch self {
        case .protein: .proteinG
        case .fat: .fatG
        case .carbohydrate: .carbohydrateG
        }
    }

    /// 色だけで示さないよう、いつも添える1文字
    var letter: String {
        switch self {
        case .protein: "P"
        case .fat: "F"
        case .carbohydrate: "C"
        }
    }

    var name: String {
        switch self {
        case .protein: "たんぱく質"
        case .fat: "脂質"
        case .carbohydrate: "炭水化物"
        }
    }

    var color: Color {
        switch self {
        case .protein: Color("Protein")
        case .fat: Color("Fat")
        case .carbohydrate: Color("Carbohydrate")
        }
    }

    /// 丸を一周した長さのうち、この栄養が占める割合
    func share(of shares: PFCShares) -> Double {
        switch self {
        case .protein: shares.protein
        case .fat: shares.fat
        case .carbohydrate: shares.carbohydrate
        }
    }

    /// 名前の前に置く色の四角（DESIGN.md の nutrient-key）
    var key: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 9, height: 9)
            .accessibilityHidden(true)
    }
}
