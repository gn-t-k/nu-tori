import NuToriCore
import Testing

@Suite("食べた量と1日の目安の比べ")
struct EatenAgainstGuideTests {
    @Suite("kcal が目安に届かない日")
    struct KilocaloriesBelowGuide {
        let againstGuide = EatenAgainstGuide(eaten: .exactly(550.6), guide: 1750, of: .energyKcal)

        @Test("丸の中に「あと」と、丸めた食べた量から数えた残りを書くこと")
        func remainder() {
            #expect(againstGuide.remainder == .init(lead: "あと", number: "1,199", unit: "kcal"))
        }
    }

    @Suite("kcal が目安を超えた日")
    struct KilocaloriesOverGuide {
        let againstGuide = EatenAgainstGuide(eaten: .exactly(1870), guide: 1750, of: .energyKcal)

        @Test("丸の中に「超過」と超えた kcal を書くこと")
        func remainder() {
            #expect(againstGuide.remainder == .init(lead: "超過", number: "120", unit: "kcal"))
        }
    }

    @Suite("kcal が目安ちょうどの日")
    struct KilocaloriesAtGuide {
        let againstGuide = EatenAgainstGuide(eaten: .exactly(1750), guide: 1750, of: .energyKcal)

        @Test("丸の中を「あと 0 kcal」にすること")
        func remainder() {
            #expect(againstGuide.remainder == .init(lead: "あと", number: "0", unit: "kcal"))
        }
    }

    @Suite("「不明」の材料が混じり、目安に届かない日")
    struct LowerBoundBelowGuide {
        let againstGuide = EatenAgainstGuide(eaten: .atLeast(551), guide: 1750, of: .energyKcal)

        @Test("残りは多くてその値なので「以下」を付けること")
        func remainder() {
            #expect(
                againstGuide.remainder == .init(lead: "あと", number: "1,199", unit: "kcal 以下"))
        }
    }

    @Suite("「不明」の材料が混じり、目安を超えた日")
    struct LowerBoundOverGuide {
        let againstGuide = EatenAgainstGuide(eaten: .atLeast(1870), guide: 1750, of: .energyKcal)

        @Test("超過は少なくてその値なので「以上」を付けること")
        func remainder() {
            #expect(
                againstGuide.remainder == .init(lead: "超過", number: "120", unit: "kcal 以上"))
        }
    }

    @Suite("食べた量が分からない日")
    struct Unknown {
        let againstGuide = EatenAgainstGuide(eaten: .unknown, guide: 90, of: .proteinG)

        @Test("丸の中に語を置かず「—」にすること")
        func remainder() {
            #expect(againstGuide.remainder == .init(lead: nil, number: "—", unit: "g"))
        }

        @Test("バーを満たさないこと")
        func filledFraction() {
            #expect(againstGuide.filledFraction == 0)
        }
    }

    @Suite("P・F・C が目安の半分の日")
    struct GramsHalfOfGuide {
        let againstGuide = EatenAgainstGuide(eaten: .exactly(45), guide: 90, of: .proteinG)

        @Test("目安を右端として、食べた分だけバーを満たすこと")
        func filledFraction() {
            #expect(againstGuide.filledFraction == 0.5)
        }

        @Test("超えたことにしないこと")
        func exceedsGuide() {
            #expect(!againstGuide.exceedsGuide)
        }
    }

    @Suite("P・F・C が目安を超えた日")
    struct GramsOverGuide {
        let againstGuide = EatenAgainstGuide(eaten: .exactly(95), guide: 90, of: .proteinG)

        @Test("バーを右端まで満たすこと")
        func filledFraction() {
            #expect(againstGuide.filledFraction == 1)
        }

        @Test("超えたことを返すこと")
        func exceedsGuide() {
            #expect(againstGuide.exceedsGuide)
        }
    }

    @Suite("P・F・C が目安ちょうどの日")
    struct GramsAtGuide {
        let againstGuide = EatenAgainstGuide(eaten: .exactly(90), guide: 90, of: .proteinG)

        @Test("超えたことにしないこと")
        func exceedsGuide() {
            #expect(!againstGuide.exceedsGuide)
        }
    }

    @Suite("P・F・C が、丸めると目安と同じになる量の日")
    struct GramsRoundedToGuide {
        let againstGuide = EatenAgainstGuide(eaten: .exactly(90.3), guide: 90, of: .proteinG)

        @Test("数の「90 / 90 g」と食い違わないよう、超えたことにしないこと")
        func exceedsGuide() {
            #expect(!againstGuide.exceedsGuide)
        }
    }

    @Suite("目安が 0 の日")
    struct ZeroGuide {
        let againstGuide = EatenAgainstGuide(eaten: .exactly(10), guide: 0, of: .fatG)

        @Test("バーを満たさないこと")
        func filledFraction() {
            #expect(againstGuide.filledFraction == 0)
        }
    }
}
