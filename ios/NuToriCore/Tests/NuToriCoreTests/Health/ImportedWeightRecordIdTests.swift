import Foundation
import NuToriCore
import Testing

@Suite("取り込んだ体重記録の ID")
struct ImportedWeightRecordIdTests {
    @Suite("サンプルの UUID が決まっているとき")
    struct FixedSample {
        let sampleId: UUID

        init() throws {
            sampleId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000C1"))
        }

        @Test("名前空間を分けた UUID v5 になること")
        func isNamespacedVersion5() {
            #expect(
                ImportedWeightRecordId.make(healthKitSampleId: sampleId).uuidString
                    == "B164A537-1E28-5922-B71F-0322B9644277")
        }

        @Test("何度作っても同じになること")
        func isStable() {
            #expect(
                ImportedWeightRecordId.make(healthKitSampleId: sampleId)
                    == ImportedWeightRecordId.make(healthKitSampleId: sampleId))
        }
    }

    @Suite("サンプルの UUID が違うとき")
    struct DifferentSamples {
        let first: UUID
        let second: UUID

        init() throws {
            first = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000C1"))
            second = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000C2"))
        }

        @Test("違う ID になること")
        func differs() {
            #expect(
                ImportedWeightRecordId.make(healthKitSampleId: first)
                    != ImportedWeightRecordId.make(healthKitSampleId: second))
        }
    }
}
