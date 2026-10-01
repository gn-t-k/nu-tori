import HealthKit
import SwiftUI

/// プレビューの中でヘルスケアの権限を求めたときに何が起きるかを見る
struct HealthProbe: View {
    @State private var result = "not requested"

    var body: some View {
        VStack(spacing: 12) {
            Text("isHealthDataAvailable: \(HKHealthStore.isHealthDataAvailable())")
            Button("Request authorization") {
                Task { await request() }
            }
            Text(result)
                .font(.footnote)
        }
        .padding()
    }

    private func request() async {
        let bodyMass = HKQuantityType(.bodyMass)
        do {
            try await HKHealthStore().requestAuthorization(toShare: [bodyMass], read: [bodyMass])
            result = "returned without error"
        } catch {
            result = "error: \(error.localizedDescription)"
        }
    }
}

#Preview("health") {
    HealthProbe()
}
