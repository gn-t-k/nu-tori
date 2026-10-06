import Foundation
import NuToriCore
import SwiftUI
import UIKit

/// 食事の画面。タイムラインの食事のカードから潜る。その場で直す値は時刻だけで、料理は料理の画面へ潜って直す。
/// 写真、時刻、合計と栄養の出どころの1行、料理の一覧、「料理を足す」、「栄養の出典 ›」、「食事を削除」の順に並べる
struct MealScreen: View {
    let card: MealCard
    /// 受け付けなかった書き込みの1行。この食事の1行を、時刻の下と料理の一覧（料理の画面では材料の一覧）に置く
    let rejectedLines: [RejectedLine]
    /// 描く大きさに縮めた写真。この端末に無ければ取りに行く。取れなければ nil
    let loadPhoto: (_ photoId: UUID) async -> UIImage?
    /// 消した時刻を測るための今。直せる時刻の上限にもする
    let now: () -> Date
    let capture: (ClientUsageEvent) async -> Void
    /// その場でキャッシュに当たり、直す書き込みが送り待ちに並ぶ。インターネットにつながらなくても直せる
    let correctMealTime: (_ card: MealCard, _ eatenAt: Date) async -> Void
    /// その場でキャッシュとアプリの中の写真から消え、消す書き込みが送り待ちに並ぶ。インターネットにつながらなくても消せる
    let deleteMeal: (_ card: MealCard, _ deletedAt: Date) async -> Void
    /// その場でキャッシュに入り、作る書き込みが送り待ちに並ぶ。インターネットにつながらなくても足せる
    let addDish: (_ card: MealCard, _ typedName: String) async -> Void
    /// 料理の画面と、料理の行を左へ送る操作
    let dishActions: DishActions
    /// 料理の画面にいても、タイムラインまで戻る（食事を消したとき）
    let returnToTimeline: () -> Void

    var body: some View {
        list
            .navigationDestination(for: DishRoute.self) { route in
                DishDestination(
                    contents: card.contents.dishes.first { $0.dish.id == route.dishId }
                ) { contents in
                    DishScreen(
                        contents: contents,
                        list: DishScreenList(
                            contents: contents, in: card, rejectedLines: rejectedLines),
                        removal: removal(of: contents),
                        actions: dishActions,
                        deleteMeal: deleteMealAndReturn)
                }
            }
    }

    /// confirmsDeletion は開いたときに、消す確かめを出しているか
    init(
        card: MealCard,
        loadPhoto: @escaping (_ photoId: UUID) async -> UIImage?,
        now: @escaping () -> Date,
        capture: @escaping (ClientUsageEvent) async -> Void,
        correctMealTime: @escaping (_ card: MealCard, _ eatenAt: Date) async -> Void,
        deleteMeal: @escaping (_ card: MealCard, _ deletedAt: Date) async -> Void,
        addDish: @escaping (_ card: MealCard, _ typedName: String) async -> Void,
        dishActions: DishActions,
        returnToTimeline: @escaping () -> Void,
        rejectedLines: [RejectedLine],
        confirmsDeletion: Bool
    ) {
        self.card = card
        self.rejectedLines = rejectedLines
        self.loadPhoto = loadPhoto
        self.now = now
        self.capture = capture
        self.correctMealTime = correctMealTime
        self.deleteMeal = deleteMeal
        self.addDish = addDish
        self.dishActions = dishActions
        self.returnToTimeline = returnToTimeline
        _confirmsDeletion = State(initialValue: confirmsDeletion)
        _eatenAt = State(initialValue: card.meal.eatenAt)
    }

    @State private var confirmsDeletion: Bool
    /// 最後の1品の行を左へ送り、食事ごと消すかを確かめている
    @State private var confirmsLastDishDeletion = false
    /// 「料理を足す」を押して、名前の欄を出している
    @State private var addingDish = false
    @State private var newDishName = ""
    @FocusState private var focusesNewDishName: Bool
    /// 日付と時刻のボタンが選んでいる撮った時刻。送ってキャッシュに当たるまでのあいだも、選んだ値のまま見せる
    @State private var eatenAt: Date
    /// 読み終えた写真。写真をまだ持っていない端末では、届くまで回る印を出す
    @State private var images: [UUID: UIImage] = [:]

    private var list: some View {
        List {
            if !card.meal.photoIds.isEmpty {
                Section {
                    photos
                }
                .listRowInsets(EdgeInsets())
            }
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    eatenTimePicker
                    RejectedMealLinesText(lines: screenList.belowEatenAt)
                }
            }
            Section {
                totals
            }
            dishList
            addDishSection
            if card.contents.showsNutrientCitation {
                Section {
                    NavigationLink("栄養の出典") {
                        NutrientCitationScreen(capture: capture)
                    }
                    .accessibilityIdentifier("nutrient-citation")
                }
            }
            deletionSection
        }
        .navigationTitle("食事")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(
            MealPhotosLoading(
                photoIds: card.meal.photoIds, state: card.state, images: $images,
                loadPhoto: loadPhoto)
        )
        .onAppear {
            Task { await capture(.screen(.meal)) }
        }
        .modifier(
            LastDishDeletionConfirmation(
                isPresented: $confirmsLastDishDeletion, deleteMeal: deleteMealAndReturn))
    }

    private var screenList: MealScreenList {
        MealScreenList(card: card, rejectedLines: rejectedLines)
    }

    /// 消すと食事の料理が無くなるか。待っている・まだ送れていない・通らなかった料理も1品に数える
    private func removal(of contents: DishContents) -> DishRemoval {
        DishRemoval(removing: contents.dish.id, among: card.contents.dishes.map(\.dish))
    }

    /// 消すとタイムラインに戻る。戻る途中でカードと1日の丸からその分が減る
    private func deleteMealAndReturn() {
        let deletedAt = now()
        returnToTimeline()
        Task { await deleteMeal(card, deletedAt) }
    }

    /// 「食事を削除」を押すと、画面の下から確かめる（`confirmationDialog`）
    private var deletionSection: some View {
        Section {
            Button("食事を削除", role: .destructive) {
                confirmsDeletion = true
            }
            .accessibilityIdentifier("meal-delete")
            .confirmationDialog(
                "この食事と料理がすべて削除されます。ヘルスケアに書き出した分も削除します。",
                isPresented: $confirmsDeletion, titleVisibility: .visible
            ) {
                Button("食事を削除", role: .destructive, action: deleteMealAndReturn)
                    .accessibilityIdentifier("meal-delete-confirm")
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    /// 日付と時刻の2つの小さなボタン。撮った時刻に食事の時差を足した時計の時刻を出し、今より先は選べない。
    /// 直したら、時刻を直す書き込みを送る。日をまたいでも、カードは送った時刻の位置のまま動かない
    private var eatenTimePicker: some View {
        // 端末の時計が遅れていて撮った時刻が今より先のときも、範囲に収めるために値を動かして送らないよう、撮った時刻までは含める
        DatePicker(
            selection: $eatenAt, in: ...max(now(), card.meal.eatenAt),
            displayedComponents: [.date, .hourAndMinute]
        ) {
            Text("時刻")
            Text("撮った時刻")
        }
        .datePickerStyle(.compact)
        // 端末のタイムゾーンでなく食事の時差の時計で見せ、選んだ値もその時計の時刻として受け取る。
        // 地と文字の色は iOS の compact の見た目に任せ、Primary は押したときの tint（AccentColor）で出る
        .environment(\.timeZone, card.meal.eatenTimeZone)
        .accessibilityIdentifier("meal-time")
        .onChange(of: eatenAt) { _, chosen in
            guard chosen != card.meal.eatenAt else { return }
            Task { await correctMealTime(card, chosen) }
        }
        .onChange(of: card.meal.eatenAt) { _, synced in
            // ほかの端末で直した時刻が届いたときも、ボタンの値をそろえる
            eatenAt = synced
        }
    }

    /// 切り抜かずに出し、2枚以上なら横に送る。押しても何も起きない
    private var photos: some View {
        TabView {
            ForEach(card.meal.photoIds, id: \.self) { photoId in
                Color(.tertiarySystemFill)
                    .overlay {
                        if let image = images[photoId] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        } else {
                            ProgressView()
                        }
                    }
                    .accessibilityHidden(true)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: card.meal.photoIds.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .aspectRatio(4 / 3, contentMode: .fit)
    }

    /// kcal と P・F・C。まとまりの中の下に、栄養の出どころの1行を置く
    private var totals: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(kilocalories.number)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(kilocalories.unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if case .estimated(let mealTotals) = card.nutrition {
                HStack(spacing: 8) {
                    ForEach(PFC.allCases, id: \.self) { pfc in
                        HStack(spacing: 4) {
                            pfc.key
                            Text(
                                "\(pfc.letter) \(NutritionText.amount(mealTotals[pfc.nutrient], of: pfc.nutrient))"
                            )
                            .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(.footnote)
                if let line = card.contents.nutrientSourceLine {
                    Text(NutritionText.sourceLine(line))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("meal-totals")
    }

    /// 合計の kcal。まだ出せなければ「—」、料理なし・推定できなかったは 0 kcal
    private var kilocalories: (number: String, unit: String) {
        switch card.nutrition {
        case .pending:
            ("—", "kcal")
        case .noFood:
            (NutritionText.number(.exactly(0), of: .energyKcal), "kcal")
        case .estimated(let totals):
            (
                NutritionText.number(totals[.energyKcal], of: .energyKcal),
                NutritionText.unit(totals[.energyKcal], of: .energyKcal)
            )
        }
    }

    /// 料理の一覧の場所。写真の推定の状態の1行（推定中・翌日に推定は写真の推定が済むまで、料理なし・推定できなかったは料理が無いあいだ）の下に、
    /// 料理の行と受け付けなかった1行を並べる。まだ送れていない・写真を待っているあいだで料理が無ければ、何も置かない
    @ViewBuilder private var dishList: some View {
        let note = card.dishListNote
        let items = screenList.dishes
        if note != nil || !items.isEmpty {
            Section("料理") {
                if let note {
                    dishListNote(note)
                }
                ForEach(items, id: \.rowId) { item in
                    switch item {
                    case .record(let contents, let below):
                        NavigationLink(value: DishRoute(dishId: contents.dish.id)) {
                            dishRow(contents, rejected: below)
                        }
                        .accessibilityIdentifier("meal-dish")
                        .swipeActions(edge: .trailing) {
                            dishDeletionButton(contents)
                        }
                    case .rejected(let line):
                        RejectedMealLinesText(lines: [line])
                    }
                }
            }
        }
    }

    /// 写真の推定の状態。推定中は回る印と並べ、料理なし・推定できなかったは理由の下に、料理を足せることを添える
    @ViewBuilder private func dishListNote(_ note: MealCard.DishListNote) -> some View {
        switch note {
        case .estimating:
            HStack(spacing: 8) {
                ProgressView()
                Text(note.title)
                    .foregroundStyle(.secondary)
            }
        case .deferredToNextDay, .noDishes, .failed:
            VStack(spacing: 6) {
                Text(note.title)
                    .fontWeight(.semibold)
                ForEach([note.detail, note.addDishHint].compactMap(\.self), id: \.self) { line in
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
        }
    }

    /// 料理の行を左へ送ると出る「削除」。最後の1品でなければ確かめずに消し、最後の1品なら食事ごと消すかを確かめる
    @ViewBuilder private func dishDeletionButton(_ contents: DishContents) -> some View {
        switch removal(of: contents) {
        case .dish:
            Button(role: .destructive) {
                Task { await dishActions.delete(contents.dish) }
            } label: {
                Label("削除", systemImage: "trash")
            }
        case .meal:
            // 破壊的な役割のボタンは、押すと行を消す動きをする。確かめて料理を残すこともあるので、役割を付けず色だけ付ける
            Button {
                confirmsLastDishDeletion = true
            } label: {
                Label("削除", systemImage: "trash")
            }
            .tint(.red)
        }
    }

    /// 料理の一覧の最後の「料理を足す」。押すとその場に名前の欄が出る。改行のキーか、欄を離れたときに足し、空なら何も足さない
    private var addDishSection: some View {
        Section {
            if addingDish {
                TextField("料理の名前", text: $newDishName)
                    // 改行のキーの文字は iOS の決まった種類からしか選べず、仕様の「足す」は無い。いちばん近い「完了」にする
                    .submitLabel(.done)
                    .focused($focusesNewDishName)
                    .accessibilityIdentifier("meal-add-dish-name")
                    .onSubmit(finishAddingDish)
                    .onAppear {
                        focusesNewDishName = true
                    }
                    .onChange(of: focusesNewDishName) { _, focused in
                        if !focused {
                            finishAddingDish()
                        }
                    }
            } else {
                Button("料理を足す") {
                    addingDish = true
                }
                .accessibilityIdentifier("meal-add-dish")
            }
        }
    }

    /// 改行のキーと欄を離れたときの両方から呼ばれるので、1回だけ足す
    private func finishAddingDish() {
        guard addingDish else { return }
        addingDish = false
        let typed = newDishName
        newDishName = ""
        guard !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task { await addDish(card, typed) }
    }

    /// 料理の行（名前、量、推定の印、kcal と、行の下の待ちの1行）。材料の行は並べず、料理の画面で見せる。
    /// 待っている料理の量と kcal は「—」で、推定の印は推定したままの量にだけ添える。1行に収まらない大きな文字では、項目ごとに次の行へ送る
    private func dishRow(_ contents: DishContents, rejected: [RejectedMealLine]) -> some View {
        let row = contents.row
        let name = Text(contents.dish.name)
            .fontWeight(.semibold)
        let quantity = Text(row.quantity)
            .monospacedDigit()
        let dishKilocalories = Text(row.kilocalories)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        return VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    name.fixedSize()
                    quantity.fixedSize()
                    if row.showsEstimateBadge {
                        EstimateBadge().fixedSize()
                    }
                    Spacer(minLength: 0)
                    dishKilocalories.fixedSize()
                }
                ItemWrappingLayout(spacing: 8, lineSpacing: 2) {
                    name
                    quantity
                    if row.showsEstimateBadge {
                        EstimateBadge()
                    }
                    dishKilocalories
                }
            }
            if let note = row.note {
                HStack(spacing: 8) {
                    // 推定の待っている表示。サーバーが処理しているあいだだけ出す
                    if note.showsSpinner {
                        ProgressView()
                    }
                    Text(note.text)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            RejectedMealLinesText(lines: rejected)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 推定したままの量に添える、枠線だけの小さな印（DESIGN.md の estimate-badge）。食事の画面の料理の行と、料理の画面の量に添える
struct EstimateBadge: View {
    var body: some View {
        Text("推定")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.secondary, lineWidth: 1)
            }
    }
}
