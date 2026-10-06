import NuToriCore
import SwiftUI

struct RootView: View {
    let model: RootModel
    let appLockout: AppLockout

    var body: some View {
        // 締め出されたら、上に重ねずに画面ごと替える。重ねると、開いていたシートや確かめのダイアログが上に残って押せてしまう。
        // 開いたときと前に出たときの同期は、締め出しの画面のあいだも続けて、その結果で確かめ直す
        ZStack {
            if appLockout.isLockedOut {
                AppLockoutScreenContainer()
            } else {
                content
            }
        }
        .task { await model.open() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                model.noteAppBackgrounded()
            case .active:
                model.noteAppActive()
                Task { await model.reopenIfSignedIn() }
            default:
                break
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    /// UI テストは、標準の選ぶ画面を開かずに、決まった写真を選んだことにする
    private var photoSelection: MealPhotoSelection {
        #if DEBUG
            if let count = UITestLaunch.current?.pickedMealPhotoCount {
                return .fixed(record: { pickedAt in
                    await model.recordPickedMeals(
                        originals: UITestMealPhotos.jpegs(count: count), pickedAt: pickedAt)
                })
            }
        #endif
        return .picker
    }

    @ViewBuilder private var content: some View {
        switch model.screen {
        case .opening:
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        case .signIn(let prompt, let status):
            SignInView(prompt: prompt, status: status) { result in
                Task { await model.signIn(with: result) }
            }
        case .loadingTimeline, .timeline:
            TimelineScreenContainer(
                clock: model.clock,
                rejectedLines: model.rejectedLines,
                capture: { await model.capture($0) },
                reminderLanding: model.reminderLanding,
                noteReminderLanded: { model.noteReminderLanded() },
                requestNotificationPermission: {
                    await model.requestNotificationPermissionAfterWeightRecorded()
                },
                prepareWeightEntry: { await model.prepareWeightEntry() },
                saveWeight: { write in
                    await model.saveWeight(write)
                },
                accountActions: AccountActions(
                    signedInAccountId: { await model.signedInAccountId() },
                    turnOnUsageData: { await model.turnOnUsageData() },
                    turnOffUsageData: { await model.turnOffUsageData() },
                    deleteAccount: { await model.deleteAccount() },
                    notificationPermission: { await model.notificationPermission() },
                    openedNotificationSettings: {
                        await model.capture(.notificationSettingsOpened)
                    }
                ),
                mealActions: MealActions(
                    prepareCamera: { await CameraReadiness.prepare() },
                    recordCapturedPhoto: { original, exif, sentAt in
                        await model.recordCapturedMeal(
                            original: original, exif: exif, sentAt: sentAt)
                    },
                    recordPickedPhotos: { items, pickedAt in
                        await model.recordPickedMeals(
                            originals: await PickedMealPhotos.originals(of: items),
                            pickedAt: pickedAt)
                    },
                    photoSelection: photoSelection,
                    loadPhoto: { mealId, photoId in
                        guard
                            let file = await model.mealPhotoFile(mealId: mealId, photoId: photoId)
                        else {
                            return nil
                        }
                        return await MealPhotoImage.thumbnail(at: file)
                    },
                    correctMealTime: { card, eatenAt in
                        await model.correctMealTime(card, eatenAt: eatenAt)
                    },
                    deleteMeal: { card, deletedAt in
                        await model.deleteMeal(card, deletedAt: deletedAt)
                    }
                ),
                holdsMealOriginals: { await model.holdsMealOriginals($0) }
            )
        }
    }
}
