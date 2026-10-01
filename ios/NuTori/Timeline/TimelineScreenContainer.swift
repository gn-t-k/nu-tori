import NuToriCore
import SwiftData
import SwiftUI

/// キャッシュの記録と同期の状態、今日の日付を読んで、タイムラインの画面に渡す
struct TimelineScreenContainer: View {
    let rejectedLines: [RejectedWeightLine]
    let capture: (ClientUsageEvent) async -> Void
    let prepareWeightEntry: () async -> Void
    let saveWeight: (WeightEntry.Write) async -> Void
    let accountActions: AccountActions

    var body: some View {
        TimelineScreen(
            records: cachedRecords.compactMap { $0.weightRecord() },
            initialPull: initialPull,
            today: CalendarDay(containing: .now, in: .current),
            rejectedLines: rejectedLines,
            capture: capture,
            prepareWeightEntry: prepareWeightEntry,
            saveWeight: saveWeight,
            accountActions: accountActions
        )
    }

    @Query private var cachedRecords: [CachedWeightRecord]
    @Query private var syncStates: [CachedSyncState]

    private var initialPull: TimelineScreen.InitialPull {
        guard let state = syncStates.first, state.hasCompletedInitialPull else {
            return .inProgress
        }
        return .completed(startedDay: state.startedOn.flatMap(TimelineDayText.day(from:)))
    }
}
