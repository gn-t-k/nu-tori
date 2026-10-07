/// 食事の画面と料理の画面に出す操作（料理を足す、料理を消す、名前・量・材料を直す）と、料理の画面の待ちの1行。
/// 食事の推定の状態と料理の待ちから、ここでだけ決める。画面はこれを見て出し、推定の状態を自分で見ない。
/// 出さないのは見せ方だけで、送った書き込みを断るかはサーバーが決める
public struct MealEditOffer: Hashable, Sendable {
    /// 食事のカードの状態
    let mealState: MealCardState

    public init(card: MealCard) {
        mealState = card.state
    }

    /// 食事の画面の料理の一覧の最後に、「料理を足す」を出すか
    public var addsDish: Bool { true }

    /// 食事の画面の料理の行に、左へ送る「削除」を出すか
    public func deletesDishBySwipe(_ contents: DishContents) -> Bool {
        true
    }

    /// `contents` の料理の画面に出すもの
    public func dishScreen(_ contents: DishContents) -> DishScreenOffer {
        DishScreenOffer(
            editsNameAndQuantity: true,
            showsIngredientsAndNutrients: contents.showsIngredientsAndNutrients,
            deletesDish: true,
            progressNote: contents.row.note)
    }

    /// 料理の画面に出すもの
    public struct DishScreenOffer: Hashable, Sendable {
        /// 名前と量を、押してその場で直せる欄にするか。直せないときは文字で見せる
        public let editsNameAndQuantity: Bool
        /// 材料（量をその場で直せる）と栄養のまとまりを出すか
        public let showsIngredientsAndNutrients: Bool
        /// 「この料理を削除」を出すか
        public let deletesDish: Bool
        /// 名前の下の、食事の画面の料理の行と同じ待ちの1行
        public let progressNote: DishRow.Note?
    }
}
