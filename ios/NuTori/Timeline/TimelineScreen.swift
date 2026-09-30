import NuToriCore
import SwiftData
import SwiftUI

struct TimelineScreen: View {
    var rejectedLines: [RejectedWeightLine]
    var prepareWeightEntry: () async -> Void
    var saveWeight: (WeightEntry.Write) async -> Void

    var body: some View {
        let today = CalendarDay(containing: .now, in: .current)
        NavigationStack {
            content(today: today)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    composer(today: today)
                }
                .navigationTitle(title(today: today))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // 開く先のアカウントの画面は #123
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                        .accessibilityLabel("アカウント")
                        .accessibilityIdentifier("account")
                    }
                }
        }
        .sheet(isPresented: showsWeightEntry) {
            WeightEntrySheet(records: records) { write in
                weightEntryPhase = .closed
                Task { await saveWeight(write) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline")
    }

    @Query private var cachedRecords: [CachedWeightRecord]
    @Query private var syncStates: [CachedSyncState]
    @State private var visibleDay: CalendarDay?
    @State private var weightEntryPhase = WeightEntryPhase.closed

    private var showsWeightEntry: Binding<Bool> {
        Binding(
            get: { weightEntryPhase == .showing },
            set: { isPresented in
                if !isPresented {
                    weightEntryPhase = .closed
                }
            }
        )
    }

    private enum WeightEntryPhase {
        case closed
        case preparing
        case showing
    }

    private var showsLoading: Bool {
        syncStates.first?.hasCompletedInitialPull != true
    }

    private var records: [WeightRecord] {
        cachedRecords.compactMap { $0.weightRecord() }
    }

    private var startedDay: CalendarDay? {
        syncStates.first?.startedOn.flatMap(TimelineDayText.day(from:))
    }

    @ViewBuilder private func content(today: CalendarDay) -> some View {
        if showsLoading {
            VStack {
                ProgressView()
                Text("記録を読み込んでいます…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            timelineList(today: today)
        }
    }

    private func timelineList(today: CalendarDay) -> some View {
        let timeline = timeline(today: today)
        return GeometryReader { geo in
            ScrollView {
                // 中身が画面より短いときは下に寄せ、長いときは下端から開く
                VStack(alignment: .leading) {
                    Spacer(minLength: 0)
                    LazyVStack(alignment: .leading) {
                        if let startedDay {
                            Text("\(TimelineDayText.label(for: startedDay))から記録しています")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(timeline.days, id: \.day) { day in
                            daySection(day)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .defaultScrollAnchor(.bottom)
            .coordinateSpace(.named("timeline"))
            .onPreferenceChange(TimelineDayOffsetsKey.self) { offsets in
                visibleDay = dayInView(
                    offsets, timeline: timeline, viewportHeight: geo.size.height)
            }
        }
    }

    private func daySection(_ day: Timeline.Day) -> some View {
        VStack(alignment: .leading) {
            Text(TimelineDayText.label(for: day.day))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(rows(on: day)) { row in
                switch row {
                case .record(let record):
                    WeightRecordRow(record: record)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                case .rejection(let line):
                    Text(line.text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("rejected-weight-line")
                }
            }
        }
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: TimelineDayOffsetsKey.self,
                    value: [
                        TimelineDayOffset(
                            day: day.day, minY: geo.frame(in: .named("timeline")).minY)
                    ]
                )
            }
        }
    }

    private func composer(today: CalendarDay) -> some View {
        let unrecorded = !records.contains { $0.day == today }
        return HStack {
            Button {
                guard weightEntryPhase == .closed else { return }
                weightEntryPhase = .preparing
                Task {
                    await prepareWeightEntry()
                    weightEntryPhase = .showing
                }
            } label: {
                Image(systemName: "scalemass.fill")
                    .frame(width: 44, height: 44)
                    .background(
                        unrecorded ? Color.accentColor : Color(.tertiarySystemFill),
                        in: Circle()
                    )
                    .foregroundStyle(unrecorded ? Color.white : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(weightEntryPhase == .preparing)
            .accessibilityLabel("体重")
            .accessibilityIdentifier(unrecorded ? "composer-weight-unrecorded" : "composer-weight")
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func rows(on day: Timeline.Day) -> [TimelineDayRow] {
        var rows = day.weightRecords.map { TimelineDayRow.record($0) }
        let lines = rejectedLines.filter { $0.record.day == day.day }
            .sorted { $0.record.instant < $1.record.instant }
        for line in lines {
            switch line.placement {
            case .belowRecord:
                if let index = rows.firstIndex(where: { row in
                    guard case .record(let record) = row else { return false }
                    return record.id == line.record.id
                }) {
                    rows.insert(.rejection(line), at: index + 1)
                } else {
                    rows.append(.rejection(line))
                }
            case .insteadOfRecord:
                let index =
                    rows.firstIndex { row in
                        guard case .record(let record) = row else { return false }
                        return record.instant > line.record.instant
                    } ?? rows.endIndex
                rows.insert(.rejection(line), at: index)
            }
        }
        return rows
    }

    private func timeline(today: CalendarDay) -> Timeline {
        let first = startedDay ?? records.map(\.day).min() ?? today
        return Timeline(weightRecords: records, firstDay: first, today: today)
    }

    private func title(today: CalendarDay) -> String {
        if showsLoading {
            return TimelineDayText.label(for: today)
        }
        let timeline = timeline(today: today)
        let day = visibleDay ?? timeline.days.last?.day ?? today
        return TimelineDayText.label(for: day)
    }

    /// いちばん新しい日が画面に入っていればその日。遡っているときは、上端にかかっている日
    private func dayInView(
        _ offsets: [TimelineDayOffset], timeline: Timeline, viewportHeight: CGFloat
    ) -> CalendarDay? {
        // 開いた位置は下端。最終日が少し上にはみ出していても、その日を題にする
        let newestStillVisible: CGFloat = -40
        let topEdge: CGFloat = 8
        if let last = timeline.days.last?.day,
            let offset = offsets.first(where: { $0.day == last }),
            offset.minY < viewportHeight, offset.minY > newestStillVisible
        {
            return last
        }
        let atTop = offsets.filter { $0.minY <= topEdge }.max { $0.minY < $1.minY }
        return atTop?.day ?? offsets.min { $0.minY < $1.minY }?.day
    }
}

private enum TimelineDayRow: Identifiable {
    case record(WeightRecord)
    case rejection(RejectedWeightLine)

    var id: String {
        switch self {
        case .record(let record): "record-\(record.id.uuidString)"
        case .rejection(let line): "rejection-\(line.record.id.uuidString)"
        }
    }
}

private struct TimelineDayOffset: Equatable {
    let day: CalendarDay
    let minY: CGFloat
}

private struct TimelineDayOffsetsKey: PreferenceKey {
    static var defaultValue: [TimelineDayOffset] = []

    static func reduce(value: inout [TimelineDayOffset], nextValue: () -> [TimelineDayOffset]) {
        value.append(contentsOf: nextValue())
    }
}
