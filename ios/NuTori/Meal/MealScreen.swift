import Foundation
import NuToriCore
import SwiftUI
import UIKit

/// 食事の画面。タイムラインの食事のカードから潜る。この仕様では見るだけで、値は Primary にしない。
/// 写真、時刻、合計と栄養の出どころの1行、料理の一覧、「栄養の出典 ›」、「食事を削除」の順に並べる
struct MealScreen: View {
    let card: MealCard
    /// 描く大きさに縮めた写真。この端末に無ければ取りに行く。取れなければ nil
    let loadPhoto: (_ photoId: UUID) async -> UIImage?
    /// 消した時刻を測るための今
    let now: () -> Date
    let capture: (ClientUsageEvent) async -> Void
    /// その場でキャッシュとアプリの中の写真から消え、消す書き込みが送り待ちに並ぶ。インターネットにつながらなくても消せる
    let deleteMeal: (_ card: MealCard, _ deletedAt: Date) async -> Void

    var body: some View {
        List {
            if !card.meal.photoIds.isEmpty {
                Section {
                    photos
                }
                .listRowInsets(EdgeInsets())
            }
            Section {
                LabeledContent {
                    Text(eatenTimeText)
                        .monospacedDigit()
                } label: {
                    Text("時刻")
                    Text("撮った時刻")
                }
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
            Section {
                Button("食事を削除", role: .destructive) {
                    confirmsDeletion = true
                }
                .accessibilityIdentifier("meal-delete")
                // 押したボタンから、画面の下に確かめを出す
                .confirmationDialog(
                    "この食事と料理がすべて削除されます。ヘルスケアに書き出した分も削除します。",
                    isPresented: $confirmsDeletion,
                    titleVisibility: .visible
                ) {
                    Button("食事を削除", role: .destructive) {
                        let deletedAt = now()
                        // 消すとタイムラインに戻る。戻る途中でカードと1日の丸からその分が減る
                        dismiss()
                        Task { await deleteMeal(card, deletedAt) }
                    }
                    Button("キャンセル", role: .cancel) {}
                }
            }
        }
        .navigationTitle("食事")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: PhotoRequest(photoIds: card.meal.photoIds, state: card.state)) {
            await loadPhotos()
        }
        .onAppear {
            Task { await capture(.screen(.meal)) }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDeletion = false
    /// 読み終えた写真。写真をまだ持っていない端末では、届くまで回る印を出す
    @State private var images: [UUID: UIImage] = [:]

    /// 写真がサーバーに届くと推定の状態が変わるので、状態が変わったら取りに行き直す
    private struct PhotoRequest: Equatable {
        let photoIds: [UUID]
        let state: MealCardState
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
                totals[.energyKcal].isLowerBound ? "kcal 以上" : "kcal"
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
            ForEach(Array(card.contents.dishes.enumerated()), id: \.element.dish.id) {
                index, dish in
                Section {
                    dishRows(dish)
                } header: {
                    if index == 0 {
                        Text("料理")
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

    private var eatenTimeText: String {
        "\(TimelineDayText.label(for: card.meal.day))\(WeightAmountText.clock(card.meal.eatenClockTime))"
    }

    /// 料理の行（名前、量、kcal）の下に材料の行（名前、量）を並べる。この仕様の量はすべて推定したまま
    @ViewBuilder private func dishRows(_ contents: DishContents) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(contents.dish.name)
                .fontWeight(.semibold)
            Text(NutritionText.quantity(contents.dish.quantity, unit: contents.dish.unit))
                .monospacedDigit()
            estimateBadge
            Spacer(minLength: 0)
            Text(NutritionText.amount(contents.totals[.energyKcal], of: .energyKcal))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        ForEach(contents.ingredients, id: \.id) { ingredient in
            HStack(alignment: .firstTextBaseline) {
                Text(ingredient.name)
                Spacer(minLength: 8)
                Text(NutritionText.quantity(ingredient.quantity, unit: ingredient.unit))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.subheadline)
            .padding(.leading, 12)
            .accessibilityElement(children: .combine)
        }
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

    private func loadPhotos() async {
        for photoId in card.meal.photoIds where images[photoId] == nil {
            if let image = await loadPhoto(photoId) {
                images[photoId] = image
            }
        }
    }
}
