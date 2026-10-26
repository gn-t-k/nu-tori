import NuToriCore
import Testing

@Suite("食べた量と1日の目安の比べ")
struct EatenAgainstGuideTests {
    @Suite("丸の中の残り")
    struct Remainder {
        @Test("目安に届かない日は、「あと」と残りの kcal を書くこと")
        func left() {
            let remainder = EatenAgainstGuide(eaten: .exactly(551.4), guide: 1750).remainder
            #expect(remainder == .init(lead: "あと", number: "1,199", unit: "kcal"))
        }

        @Test("残りは、丸めた食べた量から数え、丸の下の「551 / 1,750 kcal」と合うこと")
        func countsFromRoundedEaten() {
            let remainder = EatenAgainstGuide(eaten: .exactly(550.6), guide: 1750).remainder
            #expect(remainder.number == "1,199")
        }

        @Test("目安を超えた日は、「超過」と超えた kcal を書くこと")
        func over() {
            let remainder = EatenAgainstGuide(eaten: .exactly(1870), guide: 1750).remainder
            #expect(remainder == .init(lead: "超過", number: "120", unit: "kcal"))
        }

        @Test("目安ちょうどの日は「あと 0 kcal」にすること")
        func exactlyGuide() {
            let remainder = EatenAgainstGuide(eaten: .exactly(1750), guide: 1750).remainder
            #expect(remainder == .init(lead: "あと", number: "0", unit: "kcal"))
        }

        @Test("「不明」の材料が混じる日は、残りは多くてその値なので「以下」、超過は少なくてその値なので「以上」を付けること")
        func lowerBound() {
            #expect(
                EatenAgainstGuide(eaten: .atLeast(551), guide: 1750).remainder
                    == .init(lead: "あと", number: "1,199", unit: "kcal 以下"))
            #expect(
                EatenAgainstGuide(eaten: .atLeast(1870), guide: 1750).remainder
                    == .init(lead: "超過", number: "120", unit: "kcal 以上"))
        }

        @Test("食べた量が分からない日は、語を置かず「—」にすること")
        func unknown() {
            #expect(
                EatenAgainstGuide(eaten: .unknown, guide: 1750).remainder
                    == .init(lead: nil, number: "—", unit: "kcal"))
        }
    }

    @Suite("P・F・C のバー")
    struct Bar {
        @Test("目安を端として、食べた分だけ満たすこと")
        func fillsEaten() {
            let bar = EatenAgainstGuide(eaten: .exactly(45), guide: 90)
            #expect(bar.filledFraction == 0.5)
            #expect(!bar.exceedsGuide)
        }

        @Test("目安を超えたら端まで満たし、超えたことを返すこと")
        func capsAtGuide() {
            let bar = EatenAgainstGuide(eaten: .exactly(95), guide: 90)
            #expect(bar.filledFraction == 1)
            #expect(bar.exceedsGuide)
        }

        @Test("目安ちょうどは超えたことにしないこと")
        func exactlyGuideIsNotOver() {
            #expect(!EatenAgainstGuide(eaten: .exactly(90), guide: 90).exceedsGuide)
        }

        @Test("丸めると目安と同じになる量は、数の「90 / 90 g」と食い違わないよう、超えたことにしないこと")
        func roundedToGuideIsNotOver() {
            #expect(!EatenAgainstGuide(eaten: .exactly(90.3), guide: 90).exceedsGuide)
        }

        @Test("食べた量が分からない日と、目安が 0 の日は満たさないこと")
        func emptyWhenUnknown() {
            #expect(EatenAgainstGuide(eaten: .unknown, guide: 90).filledFraction == 0)
            #expect(EatenAgainstGuide(eaten: .exactly(10), guide: 0).filledFraction == 0)
        }
    }
}
