import Foundation

/// 料理の画面のいちばん上の、名前と量のまとまりに出すもの（値の欄と、その下の注記）
public struct DishScreenHeader: Hashable, Sendable {
    let quantity: Dish.Quantity?
    /// 量の欄。量の無い料理（足したばかりで、推定し直しが一度も当たっていない料理）は nil
    public let quantityField: QuantityField?

    public init(_ contents: DishContents) {
        let quantity = contents.dish.quantity
        self.quantity = quantity
        // 見せない量（待っている料理の推定したままの量）は、欄を空にして置き文字の「—」を見せる
        quantityField = quantity.map { quantity in
            QuantityField(
                text: contents.shownQuantity.map { QuantityFieldText.text($0.value) } ?? "",
                unit: quantity.unit,
                showsEstimateBadge: contents.row.showsEstimateBadge)
        }
    }

    /// 量の数字の欄。単位は欄の右に文字で添え、変えられない
    public struct QuantityField: Hashable, Sendable {
        /// 欄に入れる数。待っている料理の推定したままの量は空にし、置き文字（`placeholder`）を見せる
        public let text: String
        public let unit: String
        public let showsEstimateBadge: Bool

        public var placeholder: String { "—" }
    }

    /// 名前と量の下の注記。名前の欄を選んでいるか（`editingName`）と、量を直してあるかで替える。
    /// 量の無い料理は量の欄が無いので、名前の欄を選んでいないときは出さない
    public func note(editingName: Bool) -> String? {
        if editingName {
            return quantity?.source == .corrected
                ? "名前を変えると、材料を推定し直します。量はそのままです。"
                : "名前を変えると、量と材料を推定し直します。"
        }
        return quantity == nil ? nil : "量を変えると、材料の量も同じ割合で変わります。"
    }
}
