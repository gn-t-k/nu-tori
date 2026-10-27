import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@MainActor
@Suite("アプリの流れ")
struct RootModelTests {
    @MainActor
    @Suite("開いている途中で記録忘れの通知を押したとき")
    struct ReminderTappedWhileOpening {
        let device: RootModelDevice
        let notice: Notice

        init() async throws {
            let notice = try Notice.missedWeightRecord(issuedAt: "2026-09-21T08:00:00+09:00")
            self.notice = notice
            device = try RootModelDevice { cache in cache.noticeCache.upsert(notice) }
            await device.model.openFromReminder(noticeId: notice.id)
        }

        @Test("観測を始めるまでは、着き先を決めず PostHog にも送らないこと")
        func waitsForObservation() {
            #expect(device.model.reminderLanding == nil)
            #expect(device.analytics.captured.isEmpty)
        }

        @Test("開き終えて観測を始めてから、その知らせへ着き、着いたことを PostHog に送ること")
        func landsOnNoticeAfterOpening() async {
            await device.model.open()

            #expect(device.model.reminderLanding == .notice(id: notice.id))
            #expect(device.analytics.identifiedAccountIds == [FakeSyncServer.accountId])
            #expect(device.analytics.captured == [.missedWeightReminderOpened(hadNotice: true)])
        }
    }

    @MainActor
    @Suite("開いたときに規約への同意が要るとき")
    struct TermsAgreementRequired {
        let device: RootModelDevice

        init() async throws {
            device = try RootModelDevice(termsAgreementRequired: true)
            await device.model.open()
        }

        @Test("同意のシートを出すこと")
        func showsSheet() {
            #expect(device.model.termsAgreementSheet == TermsAgreementSheet(termsVersion: "1"))
        }

        @Test("同意を受け付けられたら、シートを消すこと")
        func dismissesSheetWhenAgreed() async {
            let outcome = await device.model.agreeToTerms()

            #expect(outcome == .agreed)
            #expect(device.model.termsAgreementSheet == nil)
        }
    }

    @MainActor
    @Suite("体重記録と食事の書き込みを受け付けなかったとき")
    struct Rejected {
        let device: RootModelDevice
        let record: WeightRecord
        let card: MealCard
        let corrected: WeightRecord
        let deletedAt: Date

        init() async throws {
            let record = try WeightRecord.manual(
                72.4, at: "2026-09-21T07:12:00+09:00", in: "Asia/Tokyo")
            let card = try MealCard.fixture(status: .estimated)
            self.record = record
            self.card = card
            corrected = try #require(record.correction(replacingKilograms: 72.0))
            deletedAt = try Date("2026-09-22T07:00:00+09:00", strategy: .iso8601)
            device = try RootModelDevice { cache in
                cache.weightRecordCache.upsert(record)
                cache.mealCache.upsert(card.meal)
            }
            await device.reject(.weightRecord(record, serverHasValue: true))
            await device.reject(.meal(card.meal))
        }

        @Test("その体重記録を直すと、その記録の1行だけを消すこと")
        func dropsWeightLineOnCorrection() async {
            await device.model.perform(.saveWeight(.correct(corrected)))

            #expect(device.model.rejectedLines.map(\.recordId) == [card.meal.id])
        }

        @Test("その食事を消すと、その食事の1行だけを消し、消したことを PostHog に送ること")
        func dropsMealLineOnDeletion() async {
            await device.model.perform(.deleteMeal(card, deletedAt: deletedAt))

            #expect(device.model.rejectedLines.map(\.recordId) == [record.id])
            #expect(device.analytics.captured == [.mealDeleted(card, at: deletedAt)])
        }
    }

    @MainActor
    @Suite("料理の名前を直すとき")
    struct RenameDish {
        let device: RootModelDevice
        let dish: Dish

        init() throws {
            let card = try MealCard.fixture(status: .estimated)
            let dish = Dish.fixture(mealId: card.meal.id, name: "親子丼")
            self.dish = dish
            device = try RootModelDevice { cache in
                cache.mealCache.upsert(card.meal)
                cache.dishCache.upsert(dish)
            }
        }

        @Test("今と同じ名前なら、送り待ちに並べず、PostHog にも送らないこと")
        func skipsSameName() async {
            await device.model.perform(.renameDish(dish, to: " 親子丼 "))

            #expect(device.store.entries.isEmpty)
            #expect(device.analytics.captured.isEmpty)
        }

        @Test("違う名前なら、送り待ちに並べ、料理を直したことを PostHog に送ること")
        func capturesRenamed() async {
            await device.model.perform(.renameDish(dish, to: "カツ丼"))

            #expect(device.store.entries.map(\.kind) == [.dish])
            #expect(device.analytics.captured == [.dishCorrected])
        }
    }

    @MainActor
    @Suite("目標の設定を開き、受け付けなかった1行と同意のシートがあるあいだにアカウントを消したとき")
    struct DeletedAccount {
        let device: RootModelDevice

        init() async throws {
            let record = try WeightRecord.manual(
                72.4, at: "2026-09-21T07:12:00+09:00", in: "Asia/Tokyo")
            device = try RootModelDevice(termsAgreementRequired: true) { cache in
                cache.weightRecordCache.upsert(record)
            }
            await device.model.open()
            await device.model.goalSetup.open(from: .noticeCard, on: .timeline)
            await device.reject(.weightRecord(record, serverHasValue: true))
            try #require(device.model.goalSetup.flow != nil)
            try #require(device.model.rejectedLines.count == 1)
            try #require(device.model.termsAgreementSheet != nil)
        }

        @Test("サインインの画面に替え、目標の設定の流れと受け付けなかった1行と同意のシートを片づけること")
        func clearsPreviousAccount() async {
            let failure = await device.model.deleteAccount()

            #expect(failure == nil)
            #expect(device.model.screen == .signIn(.introduction, .ready))
            #expect(device.model.goalSetup.flow == nil)
            #expect(device.model.rejectedLines.isEmpty)
            #expect(device.model.termsAgreementSheet == nil)
        }
    }
}
