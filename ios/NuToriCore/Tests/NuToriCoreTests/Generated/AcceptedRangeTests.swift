import NuToriCore
import Testing

@Suite("受け付ける値の範囲")
struct AcceptedRangeTests {
    @Suite("体重")
    struct WeightKilograms {
        // swiftlint:disable:next no_parameterized_test
        @Test("受け付けるかを決めること", arguments: try TestCases.load().weightKilograms)
        func decidesWhetherToAccept(testCase: TestCase) {
            #expect(
                AcceptedRange.weightKilograms.bounds.contains(testCase.value) == testCase.accepted)
        }
    }

    @Suite("体脂肪率")
    struct BodyFatPercentage {
        // swiftlint:disable:next no_parameterized_test
        @Test("受け付けるかを決めること", arguments: try TestCases.load().bodyFatPercentage)
        func decidesWhetherToAccept(testCase: TestCase) {
            #expect(
                AcceptedRange.bodyFatPercentage.bounds.contains(testCase.value) == testCase.accepted
            )
        }
    }

    @Suite("食事の写真の枚数")
    struct MealPhotoCount {
        // swiftlint:disable:next no_parameterized_test
        @Test("受け付けるかを決めること", arguments: try TestCases.load().mealPhotoCount)
        func decidesWhetherToAccept(testCase: TestCase) {
            #expect(
                AcceptedRange.mealPhotoCount.bounds.contains(testCase.value) == testCase.accepted)
        }
    }

    @Suite("食事の時差")
    struct MealUtcOffsetSeconds {
        // swiftlint:disable:next no_parameterized_test
        @Test("受け付けるかを決めること", arguments: try TestCases.load().mealUtcOffsetSeconds)
        func decidesWhetherToAccept(testCase: TestCase) {
            #expect(
                AcceptedRange.mealUtcOffsetSeconds.bounds.contains(testCase.value)
                    == testCase.accepted)
        }
    }

    @Suite("料理の量")
    struct DishQuantity {
        // swiftlint:disable:next no_parameterized_test
        @Test("受け付けるかを決めること", arguments: try TestCases.load().dishQuantity)
        func decidesWhetherToAccept(testCase: TestCase) {
            #expect(AcceptedRange.dishQuantity.bounds.contains(testCase.value) == testCase.accepted)
        }
    }

    @Suite("材料の量")
    struct IngredientQuantity {
        // swiftlint:disable:next no_parameterized_test
        @Test("受け付けるかを決めること", arguments: try TestCases.load().ingredientQuantity)
        func decidesWhetherToAccept(testCase: TestCase) {
            #expect(
                AcceptedRange.ingredientQuantity.bounds.contains(testCase.value)
                    == testCase.accepted)
        }
    }

    @Suite("料理の名前の、前後の空白を除いた文字数")
    struct DishNameTrimmedLength {
        // swiftlint:disable:next no_parameterized_test
        @Test("受け付けるかを決めること", arguments: try TestCases.load().dishNameTrimmedLength)
        func decidesWhetherToAccept(testCase: TestCase) {
            #expect(
                AcceptedRange.dishNameTrimmedLength.bounds.contains(testCase.value)
                    == testCase.accepted)
        }
    }

    @Suite("送った文章の、前後の空白を除いたコードポイントの数")
    struct SentTextBodyTrimmedLength {
        // swiftlint:disable:next no_parameterized_test
        @Test("受け付けるかを決めること", arguments: try TestCases.load().sentTextBodyTrimmedLength)
        func decidesWhetherToAccept(testCase: TestCase) {
            #expect(
                AcceptedRange.sentTextBodyTrimmedLength.bounds.contains(testCase.value)
                    == testCase.accepted)
        }
    }

    struct TestCases: Decodable {
        let weightKilograms: [TestCase]
        let bodyFatPercentage: [TestCase]
        let mealPhotoCount: [TestCase]
        let mealUtcOffsetSeconds: [TestCase]
        let dishQuantity: [TestCase]
        let ingredientQuantity: [TestCase]
        let dishNameTrimmedLength: [TestCase]
        let sentTextBodyTrimmedLength: [TestCase]

        static func load() throws -> Self {
            try SharedTestCases.decode(Self.self, fromFileNamed: "accepted-ranges.test-cases.json")
        }
    }

    struct TestCase: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let value: Double
        let accepted: Bool

        var testDescription: String { name }
    }
}
