public import Foundation

/// 食事の画面と料理の画面に出すもの（料理を足す、料理を消す、名前・量・材料を直す、待ちの1行、受け付けなかった1行）。
/// 食事の推定の状態と料理の待ちから、ここでだけ決める。画面はこれを見て出し、推定の状態を自分で見ない。
/// 出さないのは見せ方だけで、送った書き込みを断るかはサーバーが決める
public struct MealEditOffer: Hashable, Sendable {
    let card: MealCard
    /// 食事が推定を待っているか（まだ送れていない・写真を待っている・推定中・翌日に推定）。
    /// 待っているあいだに料理を足す・直すと、サーバーが断る（`awaiting_estimation`）
    let mealAwaitsEstimation: Bool

    public init(card: MealCard) {
        self.card = card
        mealAwaitsEstimation = card.state.awaitsPhotoEstimation
    }

    /// 食事の画面の料理の一覧の後ろの「料理を足す」を押せない理由。押せるときは nil。推定を待っている食事では押せない
    public var addDishWaitNote: String? {
        mealAwaitsEstimation ? "推定が終わると足せます。" : nil
    }

    /// 食事の画面の料理の行を左へ送ると出す「削除」。推定を待っている食事の料理には出さない
    /// （料理が推定の状態より先に届いた一瞬だけ、行がある）。推定し直しを待っている料理には出す
    public func rowDeletion(of dishId: UUID) -> Deletion {
        mealAwaitsEstimation ? .hidden : removal(of: dishId)
    }

    /// 料理の画面に出すもの。キャッシュに無い料理（消えた料理）は nil。
    /// 推定を待っている食事の料理は、名前と量の欄を押せなくし、材料と栄養も「この料理を削除」も出さない。
    /// 推定し直しを待っている料理（まだ送れていない・推定中・翌日に推定）は、名前と量の欄を押せなくし、「この料理を削除」だけを出す。
    /// 待っているあいだに直すと、サーバーが断る（`awaiting_estimation`）。
    /// `rejectedLines` は受け付けなかった書き込みの1行で、ほかの記録の1行を含んでよい
    public func dishScreen(dishId: UUID, rejectedLines: [RejectedLine]) -> DishScreenOffer? {
        guard let contents = card.contents.dishes.first(where: { $0.dish.id == dishId }) else {
            return nil
        }
        let editable = !mealAwaitsEstimation && !contents.progress.isWaiting
        let quantity = quantityField(of: contents)
        let lines = RejectedLinesOnDishScreen(
            contents: contents, in: card, rejectedLines: rejectedLines)
        return DishScreenOffer(
            contents: contents,
            nameAndQuantity: editable
                ? .editable(quantity: quantity) : .disabled(quantity: quantity),
            progressNote: contents.row.note,
            belowHeader: lines.belowHeader,
            ingredients: !mealAwaitsEstimation && contents.showsIngredientsAndNutrients
                ? lines.ingredients : nil,
            deletion: mealAwaitsEstimation ? .hidden : removal(of: dishId))
    }

    /// 料理を消す操作で出すもの
    public enum Deletion: Hashable, Sendable {
        /// 出さない
        case hidden
        /// 確かめずに、料理を消す書き込みを送る
        case dish
        /// 食事の最後の1品。押したボタンから確かめ、料理を消す書き込みでなく食事を消す書き込みを送る（食事と写真をすべて消す）
        case mealAfterConfirmation
    }

    /// 料理の画面に出すもの
    public struct DishScreenOffer: Hashable, Sendable {
        public let contents: DishContents
        /// 名前と量の見せ方
        public let nameAndQuantity: NameAndQuantity
        /// 名前の下の、食事の画面の料理の行と同じ待ちの1行
        public let progressNote: DishRow.Note?
        /// 名前と量の下に置く、受け付けなかった書き込みの1行
        public let belowHeader: [RejectedMealLine]
        /// 材料の一覧（材料の行の下の1行と、材料の行を外した位置の1行を並べる）。
        /// nil なら材料と栄養のまとまりを出さない。出す材料の量はいつも、押してその場で直せる
        public let ingredients: [RecordListItem<Ingredient>]?
        /// 「この料理を削除」
        public let deletion: Deletion

        /// 名前と量の欄を押してその場で直せるか
        public var editsNameAndQuantity: Bool {
            if case .editable = nameAndQuantity { true } else { false }
        }

        /// 名前と量の下の注記。直せないときは、直したときの注記の代わりに、押せない理由を置く。
        /// 直せるときは、名前の欄を選んでいるか（`editingName`）と、量を直してあるかで替える。
        /// 量の無い料理は量の欄が無いので、名前の欄を選んでいないときは出さない
        public func footerNote(editingName: Bool) -> String? {
            guard editsNameAndQuantity else { return "推定が終わると直せます。" }
            let quantity = contents.dish.quantity
            if editingName {
                return quantity?.source == .corrected
                    ? "名前を変えると、材料を推定し直します。量はそのままです。"
                    : "名前を変えると、量と材料を推定し直します。"
            }
            return quantity == nil ? nil : "量を変えると、材料の量も同じ割合で変わります。"
        }

        /// 名前と量の見せ方。`quantity` は量の欄で、量の無い料理（足したばかりで、推定し直しが一度も当たっていない料理）は nil
        public enum NameAndQuantity: Hashable, Sendable {
            /// 押してその場で直せる欄にする。量の無い料理は量の行を置かない
            case editable(quantity: QuantityField?)
            /// 欄をいつもの場所に置いたまま、押せない表示にする。量の無い料理も量の行を置き、
            /// 食事の画面の料理の行と同じく量を「—」で見せる
            case disabled(quantity: QuantityField?)
        }

        /// 量の数字の欄。単位は欄の右に文字で添え、変えられない
        public struct QuantityField: Hashable, Sendable {
            /// 欄に入れる数。待っている料理の推定したままの量は空にし、置き文字（`placeholder`）を見せる
            public let text: String
            public let unit: String
            public let showsEstimateBadge: Bool

            public var placeholder: String { "—" }
        }
    }

    /// 最後の1品かを、キャッシュの料理で数える。推定中・翌日に推定・まだ送れていない料理と、推定し直しが通らなかった料理も、
    /// キャッシュにある料理として1品に数える。キャッシュに無い料理は、料理だけを消す
    private func removal(of dishId: UUID) -> Deletion {
        let dishes = card.contents.dishes
        return dishes.contains(where: { $0.dish.id == dishId })
            && !dishes.contains(where: { $0.dish.id != dishId })
            ? .mealAfterConfirmation : .dish
    }

    /// 見せない量（待っている料理の推定したままの量）は、欄を空にして置き文字の「—」を見せる
    private func quantityField(of contents: DishContents) -> DishScreenOffer.QuantityField? {
        contents.dish.quantity.map { quantity in
            DishScreenOffer.QuantityField(
                text: contents.shownQuantity.map { QuantityFieldText.text($0.value) } ?? "",
                unit: quantity.unit,
                showsEstimateBadge: contents.row.showsEstimateBadge)
        }
    }
}

/// 料理の画面に、受け付けなかった1行を置いた並び
private struct RejectedLinesOnDishScreen {
    let belowHeader: [RejectedMealLine]
    let ingredients: [RecordListItem<Ingredient>]

    init(contents: DishContents, in card: MealCard, rejectedLines: [RejectedLine]) {
        let dishId = contents.dish.id
        var belowHeader: [RejectedMealLine] = []
        var belowIngredient: [UUID: [RejectedMealLine]] = [:]
        var inList: [(position: Int, line: RejectedMealLine)] = []
        for line in RejectedMealLine.lines(of: card.meal, among: rejectedLines) {
            switch line.placement(in: card) {
            case .belowDish(dishId): belowHeader.append(line)
            case .belowIngredient(let ingredientId):
                belowIngredient[ingredientId, default: []].append(line)
            case .inIngredientList(dishId, let position): inList.append((position, line))
            // ほかの料理の1行
            case .timeline, .belowEatenAt, .belowDish, .inDishList, .inIngredientList:
                break
            }
        }
        self.belowHeader = belowHeader
        ingredients = RecordListItem.interleaving(
            contents.ingredients.map { ($0.positionInDish, $0, belowIngredient[$0.id] ?? []) },
            inList)
    }
}
