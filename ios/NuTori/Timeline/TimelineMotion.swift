import NuToriCore
import SwiftUI

/// DESIGN.md の Motion の、タイムラインに記録が出入りする動き（#325）。
/// 記録は同期を通って `@Query` から届き、書いた側で `withAnimation` に包めないので、出入りの替わり目（`Key`）が変わったときに中身ごと動かす
enum TimelineMotion {
    static let animation: Animation = .smooth(duration: 0.35)

    /// 出入りと中身の替わり目。自分の記録（体重の行、食事のカード、送った文章）の ID、食事の状態、送った文章の応答の1行と、目標が決まったかだけを見る。
    /// 答えた体重の知らせは体重の行と同時に抜ける（`Timeline` が、体重記録のある日の知らせを並べない）ので、知らせは見ない。
    /// 返事の文字が伸びるたびと、開いたときに届く返事や知らせのカード（体重の知らせ、週の振り返りなど）では変えず、まわりも動かさない
    struct Key: Equatable {
        fileprivate let items: [ItemKey]
        /// 目標を立てる知らせのカードが、決まったカードに替わって高さが変わるのに、まわりをついていかせる
        fileprivate let hasGoal: Bool
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
    static func key(of days: [Timeline.Day], hasGoal: Bool) -> Key {
        Key(items: days.suffix(2).flatMap(itemKeys), hasGoal: hasGoal)
    }

    private static func itemKeys(of day: Timeline.Day) -> [ItemKey] {
        day.items.compactMap { item in
            switch role(of: item) {
            case .ownRecord(let record):
                ItemKey(id: item.id, meals: meals(of: record), replyLine: replyLine(of: record))
            case .answerableNotice, .still:
                nil
            }
        }
    }

    private static func meals(of record: OwnRecord) -> [MealKey] {
        let cards: [MealCard] =
            switch record {
            case .weight: []
            case .meal(let card): [card]
            case .sentText(let bubble): bubble.meals
            }
        return cards.map { MealKey(id: $0.meal.id, state: $0.state) }
    }

    private static func replyLine(of record: OwnRecord) -> SentTextBubble.ReplyLine? {
        switch record {
        case .weight, .meal: nil
        case .sentText(let bubble): bubble.replyLine
        }
    }

    /// 項目の出入り。「視差効果を減らす」がオンなら、縮みと上がる動きを外して薄れだけにする
    static func transition(for item: Timeline.Item, reduceMotion: Bool) -> AnyTransition {
        switch role(of: item) {
        case .ownRecord(let kind):
            // 自分の記録は、入るときだけ形を動かし、消すときは薄れるだけにする
            guard !reduceMotion else { return .opacity }
            return .asymmetric(
                insertion: .opacity.combined(with: insertion(of: kind)), removal: .opacity)
        case .answerableNotice:
            // 届いた知らせはその場に出し、答えた知らせは縮みながら抜けて、体重の行に場所を譲る
            return .asymmetric(
                insertion: .identity,
                removal: reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
        case .still:
            return .identity
        }
    }

    private static func insertion(of kind: OwnRecord) -> AnyTransition {
        switch kind {
        case .weight: .scale(scale: 0.97, anchor: .bottomTrailing)
        case .meal: .scale(scale: 0.98, anchor: .bottomTrailing)
        // 押した場所（入力欄）から来たと分かるよう、下から上げる
        case .sentText: .offset(y: 16).combined(with: .scale(scale: 0.97, anchor: .bottomTrailing))
        }
    }

    /// 項目が出入りの動きで受け持つ役。動かす項目の分け方はここだけに書く
    private enum Role {
        case ownRecord(OwnRecord)
        case answerableNotice
        /// 今のまま、その場に出す。返事は1文字ずつ伸びる出方を持つので、重ねて動かさない
        case still
    }

    private enum OwnRecord {
        case weight
        case meal(MealCard)
        case sentText(SentTextBubble)
    }

    private static func role(of item: Timeline.Item) -> Role {
        switch item {
        case .weightRecord: .ownRecord(.weight)
        case .meal(let card): .ownRecord(.meal(card))
        case .sentText(let bubble): .ownRecord(.sentText(bubble))
        case .notice: .answerableNotice
        case .rejectedWeightLine, .rejectedMealLine, .goalSetupNotice, .weeklyReviewCard,
            .dailyGuideChangeNotice, .goalNotice, .rejectedSentTextLine, .reply,
            .subscriptionNotice:
            .still
        }
    }
}
