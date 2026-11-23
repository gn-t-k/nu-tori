import NuToriCore
import Testing

@Suite("触覚を鳴らすとき")
struct HapticMomentTests {
    @Suite("鳴らす型")
    struct Feedback {
        @Test("記録を作る・直す・消す編集が書けたら、success を鳴らすこと")
        func recordWritten() {
            #expect(HapticMoment.recordWritten.feedback == .success)
        }

        @Test("受け付けなかった1行が届いたら、error を鳴らすこと")
        func writeRejected() {
            #expect(HapticMoment.writeRejected.feedback == .error)
        }

        @Test("指でスクロールして日が変わったら、selection を鳴らすこと")
        func dayScrolled() {
            #expect(HapticMoment.dayScrolled.feedback == .selection)
        }

        @Test("待っていた食事の推定ができたら、success を鳴らすこと")
        func mealEstimated() {
            #expect(HapticMoment.mealEstimated.feedback == .success)
        }

        @Test("待っていた食事の推定ができなかったら、error を鳴らすこと")
        func mealEstimationFailed() {
            #expect(HapticMoment.mealEstimationFailed.feedback == .error)
        }

        @Test("待っていた食事の写真に料理が見つからなかったら、warning を鳴らすこと")
        func mealHadNoDishes() {
            #expect(HapticMoment.mealHadNoDishes.feedback == .warning)
        }

        @Test("待っていた返事が届いたら、success を鳴らすこと")
        func replyArrived() {
            #expect(HapticMoment.replyArrived.feedback == .success)
        }

        @Test("待っていた返事を作れなかったら、error を鳴らすこと")
        func replyFailed() {
            #expect(HapticMoment.replyFailed.feedback == .error)
        }

        @Test("目標が決まったら、success を鳴らすこと")
        func goalDecided() {
            #expect(HapticMoment.goalDecided.feedback == .success)
        }
    }
}
