import NuToriCore
import Testing

@Suite("触覚を鳴らすときの本番の型")
struct HapticMomentTests {
    @Suite("今の本番で鳴らしているとき")
    struct Sounding {
        @Test("「写真を使用」を押したら、success を鳴らすこと")
        func photoUsed() {
            #expect(HapticMoment.photoUsed.standard == .success)
        }

        @Test("体重の知らせの中で記録したら、success を鳴らすこと")
        func weightRecordedInNotice() {
            #expect(HapticMoment.weightRecordedInNotice.standard == .success)
        }

        @Test("待っていた食事の推定ができたら、success を鳴らすこと")
        func mealEstimated() {
            #expect(HapticMoment.mealEstimated.standard == .success)
        }

        @Test("目標が決まったら、success を鳴らすこと")
        func goalDecided() {
            #expect(HapticMoment.goalDecided.standard == .success)
        }
    }

    @Suite("「動きの見本」で試すだけのとき")
    struct TrialOnly {
        @Test("写真を選んで記録しても、鳴らさないこと")
        func photosPicked() {
            #expect(HapticMoment.photosPicked.standard == .silent)
        }

        @Test("プリセットを押しても、鳴らさないこと")
        func presetTapped() {
            #expect(HapticMoment.presetTapped.standard == .silent)
        }

        @Test("帯の1日の丸を押しても、鳴らさないこと")
        func dayTapped() {
            #expect(HapticMoment.dayTapped.standard == .silent)
        }

        @Test("食事を削除しても、鳴らさないこと")
        func mealDeleted() {
            #expect(HapticMoment.mealDeleted.standard == .silent)
        }

        @Test("体重のシートで記録しても、鳴らさないこと")
        func weightRecordedInSheet() {
            #expect(HapticMoment.weightRecordedInSheet.standard == .silent)
        }

        @Test("文章を送っても、鳴らさないこと")
        func textSent() {
            #expect(HapticMoment.textSent.standard == .silent)
        }

        @Test("体重の − ＋ で値が動いても、鳴らさないこと")
        func weightStepped() {
            #expect(HapticMoment.weightStepped.standard == .silent)
        }

        @Test("待っていた食事の推定ができなくても、鳴らさないこと")
        func mealEstimationFailed() {
            #expect(HapticMoment.mealEstimationFailed.standard == .silent)
        }

        @Test("待っていた食事の写真に料理が見つからなくても、鳴らさないこと")
        func mealHadNoDishes() {
            #expect(HapticMoment.mealHadNoDishes.standard == .silent)
        }
    }
}
