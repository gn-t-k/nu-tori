import Foundation
import NuToriAPI
import NuToriCore
import SwiftUI
import UIKit

/// TestFlight で入れた版だけに出す「動きの見本」（#325）。本物のタイムラインに見本の記録を流し、記録の出入りの動き（`TimelineMotion`）と帯の1日の丸の動きを、場面を作り直さずに実機で見る。
/// 触覚は、鳴らすときごとに型を選び直して試せる（`HapticTrialSheet`）。選んだ型は見本の中だけで効く
/// 上の場面のボタンで記録を流すほか、下の入力欄（体重・写真・文章）もそのまま使える。記録は画面の中だけに持ち、保存も送信もしない
struct MotionGalleryScreen: View {
    /// タイムラインの右上のアカウントと課金画面に渡す。見本の記録には使わない
    let accountActions: AccountActions
    let paywallActions: PaywallActions
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            TimelineScreen(
                snapshot: records.snapshot(now: clock.now(), timeZone: clock.timeZone()),
                now: clock.now,
                timeZone: clock.timeZone,
                capture: { _ in },
                reminderLanding: nil,
                noteReminderLanded: {},
                requestNotificationPermission: {},
                prepareWeightEntry: {},
                performEdit: perform,
                accountActions: accountActions,
                paywallActions: paywallActions,
                mealActions: mealActions,
                goalSetupFlow: goalSetupFlow,
                goalScreenGoalSetupFlow: .notStarted,
                openGoalSetupFlow: { _, _ in }
            )
            // 見本の中でアカウントを開いたときに、見本の上に見本を重ねない
            .environment(\.isInMotionGallery, true)
            .environment(\.hapticTrial, hapticTrial)
        }
        .sheet(isPresented: $showsHapticTrial) {
            HapticTrialSheet(trial: $hapticTrial)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 枠のない文字のボタンが隣り合うので、間を 24 空ける
            HStack(spacing: 24) {
                Text("動きの見本")
                    .font(.headline)
                Spacer()
                Button {
                    showsHapticTrial = true
                } label: {
                    Text("触覚を試す")
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                Button("閉じる", action: onClose)
            }
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Scenario.allCases) { scenario in
                        Button(scenario.title) {
                            play(scenario)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .scrollIndicators(.hidden)
            Text("下の入力欄の体重・写真・文章も試せます。記録は保存しません。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }

    /// 上に並べる場面。押すと、その場面の前の形から記録を流す
    private enum Scenario: CaseIterable, Identifiable {
        /// 今日の体重の知らせを出す。知らせの中で体重を記録すると、体重の行が入り、知らせが抜ける
        case weightNotice
        /// 写真を撮った食事が入り、推定が終わって料理の名前と kcal が出て、帯の丸が塗られる
        case photoMeal
        /// 写真を撮った食事が入り、推定できずに終わる
        case photoMealFailed
        /// 写真を撮った食事が入り、写真に料理が見つからずに終わる
        case photoMealWithoutDishes
        /// 文章を送り、「読んでいます…」のあとに文章の食事が出て、推定が終わる
        case sentText
        /// 目標を立てる知らせを出し、少しして目標が決まる
        case goalDecided
        /// 目標を立てる知らせを出し、足りない値のページまで広げる。身長・今の体重・生まれた年はホイールのシートで選ぶ。「次へ」で目標が決まる
        case missingValues
        /// 今日の記録をすべて消して、昨日までの記録だけにする
        case reset

        var id: Self { self }

        var title: String {
            switch self {
            case .weightNotice: "体重の知らせ"
            case .photoMeal: "写真の食事"
            case .photoMealFailed: "推定できない"
            case .photoMealWithoutDishes: "料理なし"
            case .sentText: "文章の食事"
            case .goalDecided: "目標が決まる"
            case .missingValues: "足りない値"
            case .reset: "最初から"
            }
        }
    }

    private func play(_ scenario: Scenario) {
        switch scenario {
        case .weightNotice:
            records.showWeightNotice(now: clock.now(), timeZone: clock.timeZone())
        case .photoMeal:
            estimate(meal(.captured, photoIds: [UUID()], at: clock.now()))
        case .photoMealFailed:
            estimate(meal(.captured, photoIds: [UUID()], at: clock.now()), endingAs: .failed)
        case .photoMealWithoutDishes:
            estimate(meal(.captured, photoIds: [UUID()], at: clock.now()), endingAs: .noDishes)
        case .sentText:
            send("昼は親子丼と味噌汁")
        case .goalDecided:
            missingValues = nil
            records.showGoalSetupNotice(now: clock.now(), timeZone: clock.timeZone())
            later(seconds: 1.5) {
                // 待つあいだに「足りない値」でページを開いていたら、決めない
                guard missingValues == nil else { return }
                records.decideGoal(at: clock.now(), timeZone: clock.timeZone())
            }
        case .missingValues:
            records.showGoalSetupNotice(now: clock.now(), timeZone: clock.timeZone())
            // ヘルスケアから何も読めず、体重の記録も無い人。5つの欄がすべて出る
            missingValues = GoalSetupMissingValues(
                health: HealthBodyData(heightCentimeters: nil, age: nil, sex: nil, dailySteps: [:]),
                asksCurrentWeight: true,
                today: CalendarDay(containing: clock.now(), in: clock.timeZone()))
        case .reset:
            generation += 1
            missingValues = nil
            photos = [:]
            records = MotionGalleryRecords(now: clock.now(), timeZone: clock.timeZone())
        }
    }

    /// タイムラインが渡す編集を、見本の記録に当てる。食事の中身を直す編集は見本では受けない
    private func perform(_ edit: UserEdit) async {
        switch edit {
        case .saveWeight(let write):
            records.save(write)
            later(seconds: 0.5) {
                records.answerWeightNotices(at: clock.now(), timeZone: clock.timeZone())
            }
        case .recordCapturedMeal(let original, let sentAt):
            estimate(meal(.captured, photoIds: keep([original]), at: sentAt))
        case .recordPickedMeals(let originals, let pickedAt):
            estimate(meal(.picked, photoIds: keep(originals), at: pickedAt))
        case .deleteMeal(let card, _):
            records.delete(mealId: card.meal.id)
        case .sendText(let draft):
            send(draft.text.trimmingCharacters(in: .whitespacesAndNewlines))
        case .correctMealTime, .addDish, .renameDish, .correctDishQuantity,
            .correctIngredientQuantity, .deleteDish, .resendAsConversation, .resendReply:
            break
        }
    }

    /// まだ送っていない食事のカードを置き、送って推定の途中になり、推定できて終わる
    private func estimate(_ meal: Meal) {
        estimate(meal, endingWith: MotionGallerySample.estimated(meal))
    }

    /// 推定の途中まで同じに進み、料理の無い結果（推定できなかった、料理なし）で終わる
    private func estimate(_ meal: Meal, endingAs status: MealEstimationStatus) {
        estimate(
            meal, endingWith: MealCard(meal: meal, status: status, recordedOnThisDevice: true))
    }

    private func estimate(_ meal: Meal, endingWith card: MealCard) {
        records.put(MealCard(meal: meal, status: nil, recordedOnThisDevice: true))
        later(seconds: 0.8) {
            records.put(MealCard(meal: meal, status: .estimating, recordedOnThisDevice: true))
        }
        later(seconds: 3) {
            records.put(card)
        }
    }

    private func send(_ body: String) {
        let sentText = SentText(
            id: UUID(), body: body, sentAt: clock.now(), timeZone: clock.timeZone())
        records.send(sentText)
        let writtenMeal = meal(
            .written(sentTextId: sentText.id), photoIds: [], at: sentText.sentAt)
        later(seconds: 2) {
            records.readAsMeal(sentText, meal: writtenMeal)
        }
        later(seconds: 4) {
            records.put(MotionGallerySample.estimated(writtenMeal))
        }
    }

    private func meal(_ entry: Meal.Entry, photoIds: [UUID], at instant: Date) -> Meal {
        MotionGallerySample.meal(entry, photoIds: photoIds, at: instant, timeZone: clock.timeZone())
    }

    /// 撮った・選んだ写真を、カードに出すために画面の中だけに持つ
    private func keep(_ originals: [MealPhotoOriginal]) -> [UUID] {
        originals.map { original in
            let photoId = UUID()
            photos[photoId] = UIImage(data: original.data)
            return photoId
        }
    }

    /// 少しあとに記録を変える。「最初から」を押したあとに残った変更は当てない
    private func later(seconds: Double, _ change: @escaping @MainActor () -> Void) {
        let startedGeneration = generation
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard generation == startedGeneration else { return }
            change()
        }
    }

    /// 「足りない値」の場面で、目標を立てる知らせのカードを足りない値のページまで広げる。ほかのページへは進まない
    private var goalSetupFlow: GoalSetupNoticeCard.Flow {
        guard let missingValues else { return .notStarted }
        let today = CalendarDay(containing: clock.now(), in: clock.timeZone())
        let deadlineChoices = GoalDeadlineChoices(startDay: today)
        let content = GoalSetupFlowContent(
            // 減らす向きで逆算できない人の手順（向き・期限・足りない値・目標案）の3つ目
            page: .missingValues, progress: .init(count: 4, index: 2), direction: .lose,
            deadline: deadlineChoices.initialDay, deadlineChoices: deadlineChoices,
            missingValues: missingValues, proposals: nil, selectedPace: nil,
            customTargetWeight: nil, decision: .idle, unreachableRequest: nil,
            showsRecalculated: false, usedValues: nil, pastWeightRecordDay: nil)
        let close = { self.missingValues = nil }
        let actions = GoalSetupFlowActions(
            close: close, chooseDirection: { _ in }, chooseDeadline: { _ in },
            proceedFromDeadline: {},
            enterMissingValues: { entry in self.missingValues = self.missingValues?.entering(entry)
            },
            proceedFromMissingValues: {
                close()
                records.decideGoal(at: clock.now(), timeZone: clock.timeZone())
            },
            goBack: close, reviseMissingValues: {}, retry: {}, selectPace: { _ in },
            openCustomTargetWeight: {}, setCustomTargetWeight: { _ in },
            chooseMaintainInstead: {}, decide: {})
        return .expanded(content, actions)
    }

    /// 写真は撮った・選んだものを出し、場面のボタンで入れた食事は無地の見本にする
    private var mealActions: MealActions {
        MealActions(
            prepareCamera: CameraReadiness.prepare,
            photoSelection: .picker,
            loadPhoto: { [photos] _, photoId in
                photos[photoId] ?? MotionGallerySample.photo(for: photoId)
            }
        )
    }

    private let clock = Self.clock
    private static let clock = DeviceClock.live
    @State private var records = MotionGalleryRecords(
        now: Self.clock.now(), timeZone: Self.clock.timeZone())
    @State private var photos: [UUID: UIImage] = [:]
    /// 「最初から」を押した回数。押す前に始めた変更を当てないための印
    @State private var generation = 0
    /// 見本の中だけで効く、選び直した触覚の型。見本を閉じると捨てる
    @State private var hapticTrial = HapticTrial.standard
    @State private var showsHapticTrial = false
    /// 「足りない値」の場面で入れている値。場面を始めていなければ nil
    @State private var missingValues: GoalSetupMissingValues?
}
