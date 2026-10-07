import Foundation
import NuToriCore
import SwiftUI

/// 料理の画面。食事の画面の料理の行からプッシュで潜る。題は料理の名前で、戻るは「‹ 食事」。
/// 名前と量（下に注記）、材料、主な栄養・ミネラル・ビタミン、「以上」と「不明」の注記、「この料理を削除」の順に並べる。
/// 直す状態に入る操作は無く、値を押せばその場で直せる（iOS の設定のアプリの詳細の画面と同じ）
struct DishScreen: View {
    let contents: DishContents
    /// 出す操作と待ちの1行。推定の状態はこの画面で見ず、これだけで決める
    let offer: MealEditOffer.DishScreenOffer
    /// 受け付けなかった書き込みの1行の置き場（名前と量の下、材料の行の下と材料の行を外した位置）
    let list: DishScreenList
    /// 消すと食事の料理が無くなるか。最後の1品なら、料理でなく食事を消すかを確かめる
    let removal: DishRemoval
    let actions: DishActions
    /// 最後の1品の確かめで「食事を削除」を押したとき。タイムラインに戻り、食事を消す
    let deleteMeal: () -> Void

    var body: some View {
        List {
            nameAndQuantity
            if offer.showsIngredientsAndNutrients {
                if !list.ingredients.isEmpty {
                    Section("材料") {
                        ForEach(list.ingredients, id: \.rowId) { item in
                            switch item {
                            case .record(let ingredient, let below):
                                VStack(alignment: .leading, spacing: 4) {
                                    ingredientRow(ingredient)
                                    RejectedMealLinesText(lines: below)
                                }
                            case .rejected(let line):
                                RejectedMealLinesText(lines: [line])
                            }
                        }
                    }
                }
                nutrientBreakdown
            }
            if offer.deletesDish {
                deletionSection
            }
        }
        .navigationTitle(contents.dish.name)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("dish-screen")
        .toolbar {
            // 数字のキーボードには改行のキーが無いので、上に「完了」を置く。文字の欄は改行のキーで確定する
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil && focusedField != .name {
                    Spacer()
                    Button("完了") {
                        focusedField = nil
                    }
                }
            }
        }
        .onChange(of: focusedField) { previous, _ in
            // 欄を離れたら（改行のキー、「完了」、ほかの欄を押した）確定する
            if let previous {
                commit(previous)
            }
        }
        .onDisappear {
            // 打っている途中で「‹ 食事」で戻ると、欄を離れる前に画面が消えて上の onChange が呼ばれないので、ここで確定する
            if let focusedField {
                commit(focusedField)
            }
        }
    }

    /// confirmsMealDeletion は開いたときに、最後の1品を消すかの確かめを出しているか
    init(
        contents: DishContents,
        offer: MealEditOffer.DishScreenOffer,
        list: DishScreenList,
        removal: DishRemoval,
        actions: DishActions,
        deleteMeal: @escaping () -> Void,
        confirmsMealDeletion: Bool
    ) {
        self.contents = contents
        self.offer = offer
        self.list = list
        self.removal = removal
        self.actions = actions
        self.deleteMeal = deleteMeal
        _confirmsMealDeletion = State(initialValue: confirmsMealDeletion)
    }

    /// 打っている欄。欄を離れたら確定する
    @FocusState private var focusedField: Field?
    /// 打ちかけの文字。打っていない欄は、キャッシュの今の値を見せる
    @State private var drafts: [Field: String] = [:]
    @State private var confirmsMealDeletion: Bool

    private enum Field: Hashable {
        case name
        case quantity
        case ingredient(UUID)
    }

    private var header: DishScreenHeader { DishScreenHeader(contents) }

    /// 名前と量。待っている料理と通らなかった料理は、名前の下に食事の画面の料理の行と同じ状態の1行を出す
    private var nameAndQuantity: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text("名前")
                    if offer.editsNameAndQuantity {
                        TextField("料理の名前", text: draft(.name, shown: contents.dish.name))
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Color.accentColor)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .name)
                            .accessibilityIdentifier("dish-name")
                    } else {
                        Spacer()
                        Text(contents.dish.name)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("dish-name")
                    }
                }
                if let note = offer.progressNote {
                    DishProgressNoteText(note: note)
                        .accessibilityIdentifier("dish-progress")
                }
                RejectedMealLinesText(lines: list.belowHeader)
            }
            if let field = header.quantityField {
                quantityRow(field)
            }
        } footer: {
            // 直せないときは、直したときの注記の代わりに、推定が終わると直せることを置く
            if let note = offer.waitNote ?? header.note(editingName: focusedField == .name) {
                Text(note)
            }
        }
    }

    /// 量の数字の欄。単位は欄の右に文字で添え（変えられない）、推定したままの量には推定の印を添える。
    /// 直せないときは、欄でなく文字で見せる（空なら置き文字）
    private func quantityRow(_ field: DishScreenHeader.QuantityField) -> some View {
        HStack(spacing: 8) {
            Text("量")
            if offer.editsNameAndQuantity {
                TextField(field.placeholder, text: draft(.quantity, shown: field.text))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                    .focused($focusedField, equals: .quantity)
                    .accessibilityIdentifier("dish-quantity")
            } else {
                Spacer()
                Text(field.text.isEmpty ? field.placeholder : field.text)
                    .monospacedDigit()
                    .accessibilityIdentifier("dish-quantity")
            }
            Text(field.unit)
                .foregroundStyle(.secondary)
            if field.showsEstimateBadge {
                EstimateBadge()
            }
        }
    }

    /// 材料の名前と量。量は Primary で、押すとその場で数字のキーボードが出る。材料の名前は直せない
    private func ingredientRow(_ ingredient: Ingredient) -> some View {
        HStack(spacing: 8) {
            Text(ingredient.name)
            TextField(
                "",
                text: draft(
                    .ingredient(ingredient.id), shown: QuantityFieldText.text(ingredient.quantity))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .foregroundStyle(Color.accentColor)
            .focused($focusedField, equals: .ingredient(ingredient.id))
            .accessibilityLabel("\(ingredient.name)の量")
            .accessibilityIdentifier("dish-ingredient-quantity")
            Text(ingredient.unit)
                .foregroundStyle(.secondary)
        }
    }

    /// 主な栄養・ミネラル・ビタミン。最後のまとまりの下に、「以上」と「不明」の意味を1回だけ書く
    @ViewBuilder private var nutrientBreakdown: some View {
        let groups = DishNutrientBreakdown(contents).groups
        ForEach(Array(groups.enumerated()), id: \.element.title) { index, group in
            Section {
                ForEach(group.rows, id: \.nutrient) { row in
                    LabeledContent(row.name) {
                        Text(row.text)
                            .monospacedDigit()
                            .foregroundStyle(row.isUnknown ? Color(.secondaryLabel) : Color(.label))
                    }
                }
            } header: {
                Text(group.title)
            } footer: {
                if index == groups.count - 1 {
                    Text(DishNutrientBreakdown.note)
                }
            }
        }
    }

    /// 料理を消すと、キャッシュから消えた料理を `DishDestination` が見て食事の画面に戻る。
    /// 最後の1品のときだけ、押したボタンから確かめ、「食事を削除」で食事ごと消してタイムラインに戻る
    private var deletionSection: some View {
        Section {
            Button("この料理を削除", role: .destructive) {
                focusedField = nil
                switch removal {
                case .dish:
                    Task { await actions.delete(contents.dish) }
                case .meal:
                    confirmsMealDeletion = true
                }
            }
            .accessibilityIdentifier("dish-delete")
            .modifier(
                LastDishDeletionConfirmation(
                    isPresented: $confirmsMealDeletion, deleteMeal: deleteMeal))
        }
    }

    /// 打っているあいだは打ちかけの文字を、打っていないときはキャッシュの今の値（`shown`）を見せる
    private func draft(_ field: Field, shown: String) -> Binding<String> {
        Binding(
            get: { drafts[field] ?? shown },
            set: { drafts[field] = $0 })
    }

    /// 打ちかけの文字を送る。名前は前後の空白を除いて空か今と同じなら、量は数でないか範囲の外か今と同じなら、
    /// 送らずに今の値に戻す（送るかは `SyncEngine` が決める）。キャッシュに当たってから打ちかけを捨て、前の値がちらつかないようにする
    private func commit(_ field: Field) {
        guard let typed = drafts[field] else { return }
        let dish = contents.dish
        let ingredients = contents.ingredients
        Task {
            switch field {
            case .name:
                await actions.rename(dish, typed)
            case .quantity:
                if let value = QuantityFieldText.value(typed: typed) {
                    await actions.correctQuantity(dish, value)
                }
            case .ingredient(let ingredientId):
                if let ingredient = ingredients.first(where: { $0.id == ingredientId }),
                    let quantity = QuantityFieldText.value(typed: typed)
                {
                    await actions.correctIngredientQuantity(ingredient, quantity)
                }
            }
            // 送っているあいだにまた打ち始めていたら、その打ちかけは残す
            if drafts[field] == typed {
                drafts[field] = nil
            }
        }
    }
}
