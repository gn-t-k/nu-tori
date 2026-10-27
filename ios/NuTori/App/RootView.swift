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
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    private var isShowingTermsAgreementSheet: Binding<Bool> {
        Binding(
            get: { model.termsAgreementSheet != nil },
            // 下へ送って閉じることはできないので、閉じたことを受け取らない
            set: { _ in }
        )
    }

    /// UI テストは、標準の選ぶ画面を開かずに、決まった写真を選んだことにする
    private var photoSelection: MealPhotoSelection {
        #if DEBUG
            if let picked = UITestLaunch.current?.pickedPhotos {
                return .fixed(
                    photoCount: picked.count,
                    record: { pickedAt in
                        try? await Task.sleep(for: .seconds(picked.loadingSeconds))
                        await model.perform(
                            .recordPickedMeals(
                                UITestMealPhotos.jpegs(count: picked.count).map(
                                    PhotoMetadata.mealPhotoOriginal(readingExifOf:)),
                                pickedAt: pickedAt))
                    })
            }
        #endif
        return .picker
    }

    /// UI テストは、本物の StoreKit で買う `SubscriptionStoreView` を出さず、StoreKit の口の偽物で月額を買う
    private var paywallStorefront: PaywallStorefront {
        #if DEBUG
            if let store = UITestLaunch.current?.subscriptionStore {
                return .fixed(purchase: { store.purchaseMonthly(appAccountToken: $0) })
            }
        #endif
        return .storeKit
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
                pendingAppearance: model.pendingAppearance,
                capture: { await model.capture($0) },
                reminderLanding: model.reminderLanding,
                noteReminderLanded: { model.noteReminderLanded() },
                requestNotificationPermission: {
                    await model.requestNotificationPermissionAfterWeightRecorded()
                },
                prepareWeightEntry: { await model.prepareWeightEntry() },
                performEdit: { await model.perform($0) },
                replyStreams: model.replyStreams,
                goalSetup: model.goalSetup,
                accountActions: AccountActions(
                    signedInAccountId: { await model.signedInAccountId() },
                    turnOnUsageData: { await model.turnOnUsageData() },
                    turnOffUsageData: { await model.turnOffUsageData() },
                    deleteAccount: { await model.deleteAccount() },
                    notificationPermission: { await model.notificationPermission() },
                    openedNotificationSettings: {
                        await model.capture(.notificationSettingsOpened)
                    },
                    autoRenewal: { await model.subscriptionPurchases.autoRenewal() },
                    accountDeletionGuide: { await model.accountDeletionGuide() },
                    rereadAccountDeletionGuide: { await model.rereadAccountDeletionGuide($0) },
                    openedAccountDeletionGuide: {
                        await model.capture(.accountDeletionGuideOpened)
                    },
                    openedManageSubscriptions: {
                        await model.capture(.manageSubscriptionsOpened)
                    }
                ),
                paywallActions: PaywallActions(
                    purchases: model.subscriptionPurchases,
                    capture: { await model.capture($0) },
                    storefront: paywallStorefront
                ),
                mealActions: MealActions(
                    prepareCamera: { await CameraReadiness.prepare() },
                    photoSelection: photoSelection,
                    loadPhoto: { mealId, photoId in
                        guard
                            let file = await model.mealPhotoFile(mealId: mealId, photoId: photoId)
                        else {
                            return nil
                        }
                        return await MealPhotoImage.thumbnail(at: file)
                    }
                ),
                holdsMealOriginals: { await model.holdsMealOriginals($0) }
            )
            // 閉じられないシート。同意を受け付けられたら、モデルが消して閉じる
            .sheet(isPresented: isShowingTermsAgreementSheet) {
                TermsAgreementSheetView(progress: .ready) { await model.agreeToTerms() }
                    .task { await model.termsAgreementSheetPresented() }
            }
        }
    }
}
