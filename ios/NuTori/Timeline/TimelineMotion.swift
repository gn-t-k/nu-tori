import NuToriCore
import SwiftUI

/// DESIGN.md の Motion の、タイムラインに記録が出入りする動き（#325）。
/// 記録は同期を通って `@Query` から届き、書いた側で `withAnimation` に包めないので、出入りの替わり目（`Key`）が変わったときに中身ごと動かす
enum TimelineMotion {
    static let animation: Animation = .smooth(duration: 0.35)

    /// 出入りと中身の替わり目。自分の記録（体重の行、食事のカード、送った文章）と体重の知らせの ID、食事の状態、送った文章の応答の1行だけを見る。
    /// 返事の文字が伸びるたびと、開いたときに届く返事や知らせのカード（週の振り返りなど）では変えず、動かさない
    struct Key: Equatable {
        fileprivate let items: [ItemKey]
    }

    fileprivate struct ItemKey: Equatable {
        let id: String
        let meals: [MealKey]
        let replyLine: SentTextBubble.ReplyLine?
    }

    fileprivate struct MealKey: Equatable {
        let id: UUID
        let state: MealCardState
    }

    /// 新しいほうの2日（今日と、前の日の体重の知らせを置く昨日）だけを見る。
    /// さかのぼって古い日を並べたときに動かさないため、並べる日（`drawnDays`）でなく、終わりの日から数える
    static func key(of days: [Timeline.Day]) -> Key {
        Key(items: days.suffix(2).flatMap(\.items).compactMap(itemKey))
    }

    private static func itemKey(_ item: Timeline.Item) -> ItemKey? {
        switch item {
        case .weightRecord, .notice:
            ItemKey(id: item.id, meals: [], replyLine: nil)
        case .meal(let card):
            ItemKey(id: item.id, meals: [mealKey(card)], replyLine: nil)
        case .sentText(let bubble):
            ItemKey(id: item.id, meals: bubble.meals.map(mealKey), replyLine: bubble.replyLine)
        case .rejectedWeightLine, .rejectedMealLine, .goalSetupNotice, .weeklyReviewCard,
            .dailyGuideChangeNotice, .goalNotice, .rejectedSentTextLine, .reply, .subscriptionNotice:
            nil
        }
    }

    private static func mealKey(_ card: MealCard) -> MealKey {
        MealKey(id: card.meal.id, state: card.state)
    }

    /// 項目の出入り。「視差効果を減らす」がオンなら、縮みと上がる動きを外して薄れだけにする。
    /// 出入りを動かすのは、自分の記録と、答えて抜ける体重の知らせだけ。ほかは今のまま、その場に出す
    static func transition(for item: Timeline.Item, reduceMotion: Bool) -> AnyTransition {
        switch item {
        case .weightRecord:
            ownRecord(
                insertion: .scale(scale: 0.97, anchor: .bottomTrailing), reduceMotion: reduceMotion)
        case .meal:
            ownRecord(
                insertion: .scale(scale: 0.98, anchor: .bottomTrailing), reduceMotion: reduceMotion)
        case .sentText:
            // 押した場所（入力欄）から来たと分かるよう、下から上げる
            ownRecord(
                insertion: .offset(y: 16).combined(
                    with: .scale(scale: 0.97, anchor: .bottomTrailing)),
                reduceMotion: reduceMotion)
        case .notice:
            // 開いたときに届く知らせは動かさず、答えた知らせは縮みながら抜けて、体重の行に場所を譲る
            .asymmetric(
                insertion: .identity,
                removal: reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
        case .rejectedWeightLine, .rejectedMealLine, .goalSetupNotice, .weeklyReviewCard,
            .dailyGuideChangeNotice, .goalNotice, .rejectedSentTextLine, .reply, .subscriptionNotice:
            // 返事は1文字ずつ伸びる出方を持つので、重ねて動かさない
            .identity
        }
    }

    /// 自分の記録は、入るときだけ形を動かし、消すときは薄れるだけにする
    private static func ownRecord(insertion: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(insertion: .opacity.combined(with: insertion), removal: .opacity)
    }
}
