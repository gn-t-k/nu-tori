import Foundation
import NuToriCore
import SwiftUI
import UIKit

/// 食事の画面。タイムラインの食事のカードから潜る。その場で直す値は時刻だけで、料理は料理の画面へ潜って直す。
/// 写真、時刻、合計と栄養の出どころの1行、料理の一覧、「栄養の出典 ›」、「食事を削除」の順に並べる
struct MealScreen: View {
    let card: MealCard
    /// 描く大きさに縮めた写真。この端末に無ければ取りに行く。取れなければ nil
    let loadPhoto: (_ photoId: UUID) async -> UIImage?
    /// 消した時刻を測るための今。直せる時刻の上限にもする
    let now: () -> Date
    let capture: (ClientUsageEvent) async -> Void
    /// その場でキャッシュに当たり、直す書き込みが送り待ちに並ぶ。インターネットにつながらなくても直せる
    let correctMealTime: (_ card: MealCard, _ eatenAt: Date) async -> Void
    /// その場でキャッシュとアプリの中の写真から消え、消す書き込みが送り待ちに並ぶ。インターネットにつながらなくても消せる
    let deleteMeal: (_ card: MealCard, _ deletedAt: Date) async -> Void

    var body: some View {
        list
            .navigationDestination(for: DishRoute.self) { route in
                DishDestination(
                    contents: card.contents.dishes.first { $0.dish.id == route.dishId })
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
        confirmsDeletion: Bool
    ) {
        self.card = card
        self.loadPhoto = loadPhoto
        self.now = now
        self.capture = capture
        self.correctMealTime = correctMealTime
        self.deleteMeal = deleteMeal
        _confirmsDeletion = State(initialValue: confirmsDeletion)
        _eatenAt = State(initialValue: card.meal.eatenAt)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDeletion: Bool
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
                eatenTimePicker
            }
            Section {
                totals
            }
            dishList
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
                Button("食事を削除", role: .destructive) {
                    let deletedAt = now()
                    // 消すとタイムラインに戻る。戻る途中でカードと1日の丸からその分が減る
                    dismiss()
                    Task { await deleteMeal(card, deletedAt) }
                }
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

    /// 状態ごとの料理の一覧の場所。まだ送れていない・写真を待っているあいだと、料理がまだ届いていないときは何も置かない
    @ViewBuilder private var dishList: some View {
        switch card.state {
        case .notSent, .awaitingPhotos:
            EmptyView()
        case .estimating:
            Section("料理") {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("推定しています…")
                        .foregroundStyle(.secondary)
                }
            }
        case .estimated:
            if !card.contents.dishes.isEmpty {
                Section("料理") {
                    ForEach(card.contents.dishes, id: \.dish.id) { dish in
                        NavigationLink(value: DishRoute(dishId: dish.dish.id)) {
                            dishRow(dish)
                        }
                        .accessibilityIdentifier("meal-dish")
                    }
                }
            }
        case .noDishes:
            unestimated(
                title: "写真に料理が見つかりませんでした", detail: "写っていないか、見分けられませんでした。")
        case .deferredToNextDay:
            unestimated(title: "今日はもう推定できません", detail: "明日、この写真を推定します。")
        case .failed:
            unestimated(title: "料理を推定できませんでした", detail: nil)
        }
    }

    /// 料理の行（名前、量、推定の印、kcal）。材料の行は並べず、料理の画面で見せる。量の無い料理（足したばかりの料理）の量は「—」。
    /// 推定の印は、推定したままの量にだけ添える。1行に収まらない大きな文字では、項目ごとに次の行へ送る
    @ViewBuilder private func dishRow(_ contents: DishContents) -> some View {
        let showsEstimateBadge = contents.dish.quantity?.source == .estimated
        let name = Text(contents.dish.name)
            .fontWeight(.semibold)
        let quantity = Text(
            contents.dish.quantity.map { NutritionText.quantity($0.value, unit: $0.unit) } ?? "—"
        )
        .monospacedDigit()
        let dishKilocalories = Text(
            NutritionText.amount(contents.totals[.energyKcal], of: .energyKcal)
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                name.fixedSize()
                quantity.fixedSize()
                if showsEstimateBadge {
                    estimateBadge.fixedSize()
                }
                Spacer(minLength: 0)
                dishKilocalories.fixedSize()
            }
            ItemWrappingLayout(spacing: 8, lineSpacing: 2) {
                name
                quantity
                if showsEstimateBadge {
                    estimateBadge
                }
                dishKilocalories
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// 推定したままの量に添える、枠線だけの小さな印（DESIGN.md の estimate-badge）
    private var estimateBadge: some View {
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

    private func unestimated(title: String, detail: String?) -> some View {
        Section("料理") {
            VStack(spacing: 6) {
                Text(title)
                    .fontWeight(.semibold)
                if let detail {
                    Text(detail)
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
}
