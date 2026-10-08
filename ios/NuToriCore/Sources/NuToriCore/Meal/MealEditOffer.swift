/// 食事の画面と料理の画面に出す操作（料理を足す、料理を消す、名前・量・材料を直す）と、料理の画面の待ちの1行。
/// 食事の推定の状態と料理の待ちから、ここでだけ決める。画面はこれを見て出し、推定の状態を自分で見ない。
/// 出さないのは見せ方だけで、送った書き込みを断るかはサーバーが決める
public struct MealEditOffer: Hashable, Sendable {
    /// 食事が推定を待っているか（まだ送れていない・写真を待っている・推定中・翌日に推定）。
    /// 待っているあいだに料理を足す・直すと、サーバーが断る（`awaiting_estimation`）
    let mealAwaitsEstimation: Bool

    public init(card: MealCard) {
        mealAwaitsEstimation = card.state.awaitsPhotoEstimation
    }

    /// 食事の画面の料理の一覧の後ろの「料理を足す」。推定を待っている食事では押せない
    public var dishAddition: DishAddition {
        mealAwaitsEstimation ? .disabled(note: "推定が終わると足せます。") : .offered
    }

    /// 食事の画面の料理の行に、左へ送る「削除」を出すか。推定を待っている食事の料理には出さない
    /// （料理が推定の状態より先に届いた一瞬だけ、行がある）。推定し直しを待っている料理には出す
    public var deletesDishBySwipe: Bool { !mealAwaitsEstimation }

    /// `contents` の料理の画面に出すもの。推定を待っている食事の料理は、名前と量の欄を押せなくし、材料と栄養も「この料理を削除」も出さない。
    /// 推定し直しを待っている料理（まだ送れていない・推定中・翌日に推定）は、名前と量の欄を押せなくし、「この料理を削除」だけを出す。
    /// 待っているあいだに直すと、サーバーが断る（`awaiting_estimation`）
    public func dishScreen(_ contents: DishContents) -> DishScreenOffer {
        let quantity = DishScreenHeader(contents).quantityField
        return DishScreenOffer(
            nameAndQuantity: !mealAwaitsEstimation && !contents.progress.isWaiting
                ? .editable(quantity: quantity) : .disabled(quantity: quantity),
            showsIngredientsAndNutrients: !mealAwaitsEstimation
                && contents.showsIngredientsAndNutrients,
            deletesDish: !mealAwaitsEstimation,
            progressNote: contents.row.note)
    }

    /// 食事の画面の料理の一覧の後ろの「料理を足す」
    public enum DishAddition: Hashable, Sendable {
        /// 押せる
        case offered
        /// 押せない表示にし、その下の注記に押せない理由（`note`）を置く
        case disabled(note: String)
    }

    /// 料理の画面に出すもの
    public struct DishScreenOffer: Hashable, Sendable {
        /// 名前と量の見せ方
        public let nameAndQuantity: NameAndQuantity
        /// 材料（量をその場で直せる）と栄養のまとまりを出すか
        public let showsIngredientsAndNutrients: Bool
        /// 「この料理を削除」を出すか
        public let deletesDish: Bool
        /// 名前の下の、食事の画面の料理の行と同じ待ちの1行
        public let progressNote: DishRow.Note?

        /// 名前と量の欄を押してその場で直せるか
        public var editsNameAndQuantity: Bool {
            if case .editable = nameAndQuantity { true } else { false }
        }

        /// 名前と量を直せないときに、その下へ添える押せない理由
        public var waitNote: String? {
            editsNameAndQuantity ? nil : "推定が終わると直せます。"
        }

        /// 名前と量の見せ方。`quantity` は量の欄で、量の無い料理（足したばかりで、推定し直しが一度も当たっていない料理）は nil
        public enum NameAndQuantity: Hashable, Sendable {
            /// 押してその場で直せる欄にする。量の無い料理は量の行を置かない
            case editable(quantity: DishScreenHeader.QuantityField?)
            /// 欄をいつもの場所に置いたまま、押せない表示にする。量の無い料理も量の行を置き、
            /// 食事の画面の料理の行と同じく量を「—」で見せる
            case disabled(quantity: DishScreenHeader.QuantityField?)
        }
    }
}
