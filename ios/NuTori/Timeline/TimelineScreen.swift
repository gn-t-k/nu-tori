import NuToriCore
import SwiftData
import SwiftUI

struct TimelineScreen: View {
    var rejectedLines: [RejectedWeightLine]
    var capture: (ClientUsageEvent) async -> Void
    var prepareWeightEntry: () async -> Void
    var saveWeight: (WeightEntry.Write) async -> Void
    var accountActions: AccountActions

    var body: some View {
        let today = CalendarDay(containing: .now, in: .current)
        let loaded = showsLoading ? nil : timeline(today: today)
        let selectedDay = visibleDay ?? loaded?.days.last?.day ?? today
        NavigationStack {
            VStack(spacing: 0) {
                DayRingStrip(
                    weeks: stripWeeks(today: today, loaded: loaded),
                    selectedDay: selectedDay,
                    today: today,
                    openableDays: loaded?.dayRange
                ) { day in
                    dayFocus = .summary(day)
                }
                Divider()
                content(today: today, loaded: loaded)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationDestination(for: CalendarDay.self) { day in
                WeightScreen(
                    day: day,
                    records: records,
                    firstDay: startedDay ?? records.map(\.day).min() ?? day,
                    today: today,
                    rejectedLines: rejectedLines,
                    capture: capture,
                    saveWeight: saveWeight
                )
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer(today: today)
            }
            .navigationTitle(title(today: today, loaded: loaded))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsAccount = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("アカウント")
                    .accessibilityIdentifier("account")
                }
            }
            .sheet(isPresented: $showsAccount) {
                NavigationStack {
                    AccountScreen(actions: accountActions) {
                        showsAccount = false
                    }
                }
                .accessibilityIdentifier("account-screen")
            }
            .sheet(isPresented: summaryPresented) {
                if case .summary(let day) = dayFocus, let loaded {
                    DaySummarySheet(timeline: loaded, day: day) { chosen in
                        dayFocus = .scrollingTo(chosen)
                    }
                }
            }
        }
        .sheet(isPresented: showsWeightEntry) {
            WeightEntrySheet(
                records: records,
                capture: capture,
                onRecord: { write in
                    weightEntryPhase = .closed
                    Task { await saveWeight(write) }
                }
            )
        }
        .onChange(of: weightEntryPhase) { previous, phase in
            if previous == .showing, phase == .closed {
                Task { await capture(.screen(.timeline)) }
            }
        }
        .onAppear {
            Task { await capture(.screen(.timeline)) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline")
    }

    @Query private var cachedRecords: [CachedWeightRecord]
    @Query private var syncStates: [CachedSyncState]
    @State private var showsAccount = false
    @State private var visibleDay: CalendarDay?
    @State private var weightEntryPhase = WeightEntryPhase.closed
    @State private var dayFocus: DayFocus = .timeline

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

    private var summaryPresented: Binding<Bool> {
        Binding(
            get: { if case .summary = dayFocus { true } else { false } },
            set: { presented in
                if !presented, case .summary = dayFocus {
                    dayFocus = .timeline
                }
            }
        )
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

    @ViewBuilder private func content(today: CalendarDay, loaded: Timeline?) -> some View {
        if loaded == nil {
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
            ScrollViewReader { proxy in
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
                                    .id(day.day)
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
                .onChange(of: dayFocus) { _, focus in
                    guard case .scrollingTo(let day) = focus else { return }
                    proxy.scrollTo(day, anchor: .top)
                    dayFocus = .timeline
                }
            }
        }
    }

    private func daySection(_ day: Timeline.Day) -> some View {
        VStack(alignment: .leading) {
            Text(TimelineDayText.label(for: day.day))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(day.items) { item in
                switch item {
                case .weightRecord(let record):
                    NavigationLink(value: record.day) {
                        WeightRecordRow(record: record)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("weight-row")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                case .rejectedWeightLine(let line):
                    Text(line.text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("rejected-weight-line")
                }
            }
        }
        // 中の行が自分の識別子を保つよう、区切りは入れ物にしてから名前を付ける
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("day-section-\(TimelineDayText.startedOn(for: day.day))")
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

    /// 読み込み中は、今日の週を空の丸にする。使い始めた日は、取り終えてから入る
    private func stripWeeks(today: CalendarDay, loaded: Timeline?) -> [RingStrip.Week] {
        if let loaded {
            return RingStrip(timeline: loaded).weeks
        }
        let monday = today.startOfWeek
        return RingStrip(
            timeline: Timeline(
                input: Timeline.Input(weightRecords: [], rejectedLines: []), firstDay: monday, today: today)
        ).weeks
    }

    private func timeline(today: CalendarDay) -> Timeline {
        let first = startedDay ?? records.map(\.day).min() ?? today
        return Timeline(
            input: Timeline.Input(weightRecords: records, rejectedLines: rejectedLines),
            firstDay: first, today: today)
    }

    private func title(today: CalendarDay, loaded: Timeline?) -> String {
        guard let loaded else {
            return TimelineDayText.label(for: today)
        }
        let day = visibleDay ?? loaded.days.last?.day ?? today
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

private enum WeightEntryPhase: Equatable {
    case closed
    case preparing
    case showing
}

private enum DayFocus: Equatable {
    case timeline
    case summary(CalendarDay)
    case scrollingTo(CalendarDay)
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
