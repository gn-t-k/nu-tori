import Foundation
import NuToriCore
import SwiftUI
import UIKit

/// TestFlight で入れた版だけに出す「動きの見本」（#325）。本物のタイムラインに見本の記録を流し、記録の出入りの動き（`TimelineMotion`）と帯の1日の丸の動きを、場面を作り直さずに実機で見る。
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
                goalSetupFlow: .notStarted,
                goalScreenGoalSetupFlow: .notStarted,
                openGoalSetupFlow: { _, _ in }
            )
            // 見本の中でアカウントを開いたときに、見本の上に見本を重ねない
            .environment(\.isInMotionGallery, true)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("動きの見本")
                    .font(.headline)
                Spacer()
                Picker("丸の強調", selection: $ringEmphasis) {
                    ForEach(RingEmphasis.allCases) { emphasis in
                        Text(emphasis.title).tag(emphasis)
                    }
                }
                .pickerStyle(.menu)
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
        /// 文章を送り、「読んでいます…」のあとに文章の食事が出て、推定が終わる
        case sentText
        /// 目標を立てる知らせを出し、少しして目標が決まる
        case goalDecided
        /// 今日の記録をすべて消して、昨日までの記録だけにする
        case reset

        var id: Self { self }

        var title: String {
            switch self {
            case .weightNotice: "体重の知らせ"
            case .photoMeal: "写真の食事"
            case .sentText: "文章の食事"
            case .goalDecided: "目標が決まる"
            case .reset: "最初から"
            }
        }
    }

    private func play(_ scenario: Scenario) {
        let today = clock.today()
        switch scenario {
        case .weightNotice:
            records.showWeightNotice(today: today)
        case .photoMeal:
            estimate(meal(.captured, photoIds: [UUID()], at: clock.now()))
        case .sentText:
            send("昼は親子丼と味噌汁")
        case .goalDecided:
            records.showGoalSetupNotice(today: today)
            later(seconds: 1.5) {
                records.decideGoal(today: today, at: clock.now(), timeZone: clock.timeZone())
            }
        case .reset:
            generation += 1
            photos = [:]
            records = MotionGalleryRecords(today: today)
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

    /// まだ送っていない食事のカードを置き、送って推定の途中になり、推定が終わる
    private func estimate(_ meal: Meal) {
        records.put(MealCard(meal: meal, status: nil, recordedOnThisDevice: true))
        later(seconds: 0.8) {
            records.put(MealCard(meal: meal, status: .estimating, recordedOnThisDevice: true))
        }
        later(seconds: 3) {
            records.put(.sampleEstimated(meal))
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
            records.put(.sampleEstimated(writtenMeal))
        }
    }

    private func meal(_ entry: Meal.Entry, photoIds: [UUID], at instant: Date) -> Meal {
        let timeZone = clock.timeZone()
        return Meal(
            id: UUID(), eatenAt: instant,
            eatenUtcOffsetSeconds: timeZone.secondsFromGMT(for: instant), sentAt: instant,
            sentTimeZone: timeZone, entry: entry, photoIds: photoIds)
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

    /// 写真は撮った・選んだものを出し、場面のボタンで入れた食事は無地の見本にする
    private var mealActions: MealActions {
        MealActions(
            prepareCamera: CameraReadiness.prepare,
            photoSelection: .picker,
            loadPhoto: { [photos] _, photoId in photos[photoId] ?? .sampleMealPhoto(for: photoId) }
        )
    }

    private let clock = Self.clock
    private static let clock = DeviceClock.live
    @State private var records = MotionGalleryRecords(today: Self.clock.today())
    @State private var photos: [UUID: UIImage] = [:]
    /// 「最初から」を押した回数。押す前に始めた変更を当てないための印
    @State private var generation = 0
    @AppStorage(RingEmphasis.storageKey) private var ringEmphasis = RingEmphasis.defaultValue
}
