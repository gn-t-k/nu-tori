/// 食事の画面と料理の画面に出す操作（料理を足す、料理を消す、名前・量・材料を直す）と、料理の画面の待ちの1行。
/// 食事の推定の状態と料理の待ちから、ここでだけ決める。画面はこれを見て出し、推定の状態を自分で見ない。
/// 出さないのは見せ方だけで、送った書き込みを断るかはサーバーが決める
public struct MealEditOffer: Hashable, Sendable {
    /// 食事のカードの状態
    let mealState: MealCardState

    public init(card: MealCard) {
        mealState = card.state
    }

    /// 食事の画面の料理の一覧の最後に、「料理を足す」を出すか。推定を待っている食事には出さない
    public var addsDish: Bool { !mealAwaitsEstimation }

    /// 「料理を足す」を出さないときに、その場所に置く1行
    public var addDishWaitNote: String? {
        addsDish ? nil : "推定が終わると、料理を足せます。"
    }

    /// 食事の画面の料理の行に、左へ送る「削除」を出すか。推定を待っている食事の料理には出さない
    /// （料理が推定の状態より先に届いた一瞬だけ、行がある）
    public func deletesDishBySwipe(_ contents: DishContents) -> Bool {
        !mealAwaitsEstimation
    }

    /// `contents` の料理の画面に出すもの。推定を待っている食事の料理は、名前と量を文字で見せ、「この料理を削除」も出さない
    public func dishScreen(_ contents: DishContents) -> DishScreenOffer {
        DishScreenOffer(
            editsNameAndQuantity: !mealAwaitsEstimation,
            showsIngredientsAndNutrients: contents.showsIngredientsAndNutrients,
            deletesDish: !mealAwaitsEstimation,
            progressNote: contents.row.note)
    }

    /// 食事が推定を待っているか（まだ送れていない・写真を待っている・推定中・翌日に推定）。
    /// 待っているあいだに料理を足す・直すと、サーバーが断る（`awaiting_estimation`）
    private var mealAwaitsEstimation: Bool {
        switch mealState {
        case .notSent, .awaitingPhotos, .estimating, .deferredToNextDay: true
        case .estimated, .noDishes, .failed: false
        }
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

        /// 名前と量を直せないときに、その下へ添える1行
        public var waitNote: String? {
            editsNameAndQuantity ? nil : "推定が終わると直せます。"
        }
    }
}
