import Foundation
import NuToriCore
import PhotosUI
import SwiftUI

struct TimelineScreen: View {
    let records: [WeightRecord]
    let initialPull: InitialPull
    let today: CalendarDay
    /// 記録した時刻と、操作にかかった時間を測るための今
    let now: () -> Date
    let rejectedLines: [RejectedLine]
    let meals: [MealCard]
    let capture: (ClientUsageEvent) async -> Void
    let prepareWeightEntry: () async -> Void
    let saveWeight: (WeightEntry.Write) async -> Void
    let accountActions: AccountActions
    let mealActions: MealActions

    var body: some View {
        let loaded = showsLoading ? nil : timeline()
        let selectedDay = visibleDay ?? loaded?.days.last?.day ?? today
        NavigationStack {
            VStack(spacing: 0) {
                DayRingStrip(
                    weeks: stripWeeks(loaded: loaded),
                    selectedDay: selectedDay,
                    today: today,
                    openableDays: loaded?.dayRange
                ) { day in
                    showsCameraNotice = false
                    dayFocus = .summary(day)
                }
                Divider()
                content(loaded: loaded)
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
            .navigationDestination(for: MealRoute.self) { route in
                MealDestination(card: meals.first { $0.meal.id == route.mealId }) { card in
                    MealScreen(
                        card: card,
                        loadPhoto: { photoId in
                            await mealActions.loadPhoto(card.meal.id, photoId)
                        },
                        now: now,
                        capture: capture,
                        deleteMeal: mealActions.deleteMeal,
                        confirmsDeletion: false
                    )
                }
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer()
            }
            // 体重や食事の画面から戻ったときも、タイムラインを見たとして送る
            .onAppear {
                Task { await capture(.screen(.timeline)) }
            }
            // 体重の画面に潜ったら、戻ったときには知らせを残さない
            .onDisappear {
                showsCameraNotice = false
            }
            .navigationTitle(title(loaded: loaded))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: hidingCameraNotice { showsAccount = true }) {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("アカウント")
                    .accessibilityIdentifier("account")
                }
            }
            .sheet(isPresented: $showsAccount) {
                NavigationStack {
                    AccountScreenContainer(actions: accountActions) {
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
                today: today,
                now: now,
                capture: capture,
                onRecord: { write in
                    weightEntryPhase = .closed
                    Task { await saveWeight(write) }
                }
            )
        }
        .fullScreenCover(isPresented: showsCamera) {
            MealCamera(
                onUse: { original, exif in
                    let sentAt = now()
                    capturedCount += 1
                    cameraPhase = .closed
                    Task { await mealActions.recordCapturedPhoto(original, exif, sentAt) }
                },
                onCancel: {
                    cameraPhase = .closed
                    Task { await capture(.cameraCancelled) }
                }
            )
            .ignoresSafeArea()
        }
        // 「写真を使用」で、カメラを閉じながら触覚で知らせる
        .sensoryFeedback(.success, trigger: capturedCount)
        .photosPicker(
            isPresented: $showsPhotoPicker,
            selection: $pickedPhotos,
            maxSelectionCount: MealDraft.maxPhotosPerSelection,
            matching: .images,
            // 撮影時刻と時差を読むため、付帯情報つきの元の形式で受け取る
            preferredItemEncoding: .current
        )
        .onChange(of: pickedPhotos) { _, items in
            guard !items.isEmpty else { return }
            let pickedAt = now()
            pickedPhotos = []
            Task { await mealActions.recordPickedPhotos(items, pickedAt) }
        }
        .onChange(of: weightEntryPhase) { previous, phase in
            if previous == .showing, phase == .closed {
                Task { await capture(.screen(.timeline)) }
            }
        }
        .onChange(of: cameraPhase) { previous, phase in
            if previous == .showing, phase == .closed {
                Task { await capture(.screen(.timeline)) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline")
    }

    /// 初回の取得を終えるまでは、記録がそろっていないので並べない
    enum InitialPull {
        case inProgress
        /// 使い始めた日は、サーバーで決まるまで無い
        case completed(startedDay: CalendarDay?)
    }

    @State private var showsAccount = false
    @State private var visibleDay: CalendarDay?
    @State private var weightEntryPhase = WeightEntryPhase.closed
    @State private var dayFocus: DayFocus = .timeline
    @State private var cameraPhase = CameraPhase.closed
    /// カメラを許可していない人に出す知らせ。ほかを押すか、タイムラインを動かすと消える
    @State private var showsCameraNotice = false
    /// 「写真を使用」を押した回数。触覚を鳴らす合図
    @State private var capturedCount = 0
    @State private var showsPhotoPicker = false
    @State private var pickedPhotos: [PhotosPickerItem] = []

    private var showsCamera: Binding<Bool> {
        Binding(
            get: { cameraPhase == .showing },
            set: { isPresented in
                if !isPresented {
                    cameraPhase = .closed
                }
            }
        )
    }

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
        switch initialPull {
        case .inProgress: true
        case .completed: false
        }
    }

    private var startedDay: CalendarDay? {
        switch initialPull {
        case .inProgress: nil
        case .completed(let startedDay): startedDay
        }
    }

    @ViewBuilder private func content(loaded: Timeline?) -> some View {
        if loaded == nil {
            VStack {
                ProgressView()
                Text("記録を読み込んでいます…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            timelineList()
        }
    }

    private func timelineList() -> some View {
        let timeline = timeline()
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
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .bottom)
                }
                .defaultScrollAnchor(.bottom)
                .onScrollPhaseChange { _, phase in
                    if phase != .idle {
                        showsCameraNotice = false
                    }
                }
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
                case .meal(let card):
                    // どの状態のカードも、押すと食事の画面へ潜る
                    NavigationLink(value: MealRoute(mealId: card.meal.id)) {
                        MealCardView(card: card) { photoId in
                            await mealActions.loadPhoto(card.meal.id, photoId)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("meal-card")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                case .rejectedMealLine(let line):
                    Text(line.text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("rejected-meal-line")
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

    private func composer() -> some View {
        TimelineComposer(
            weightRecordedToday: records.contains { $0.day == today },
            preparingWeightEntry: weightEntryPhase == .preparing,
            showsCameraNotice: showsCameraNotice,
            onCapture: hidingCameraNotice(openCamera),
            onPickPhotos: hidingCameraNotice {
                switch mealActions.photoSelection {
                case .picker:
                    showsPhotoPicker = true
                #if DEBUG
                    case .fixed(let record):
                        let pickedAt = now()
                        Task { await record(pickedAt) }
                #endif
                }
            },
            onWeight: hidingCameraNotice {
                guard weightEntryPhase == .closed else { return }
                weightEntryPhase = .preparing
                Task {
                    await prepareWeightEntry()
                    weightEntryPhase = .showing
                }
            }
        )
    }

    /// ほかを押したら、カメラの許可の知らせを消してから動く
    private func hidingCameraNotice(_ action: @escaping () -> Void) -> () -> Void {
        {
            showsCameraNotice = false
            action()
        }
    }

    /// 初めてのときは、カメラを開く前に iOS の許可の画面で求める。許可していなければ、開かずに知らせる
    private func openCamera() {
        guard cameraPhase == .closed else { return }
        cameraPhase = .preparing
        Task {
            switch await mealActions.prepareCamera() {
            case .ready:
                cameraPhase = .showing
            case .notPermitted:
                cameraPhase = .closed
                showsCameraNotice = true
                await capture(.cameraPermissionNoticeShown)
            case .noCamera:
                cameraPhase = .closed
            }
        }
    }

    /// 読み込み中は、今日の週を空の丸にする。使い始めた日は、取り終えてから入る
    private func stripWeeks(loaded: Timeline?) -> [RingStrip.Week] {
        if let loaded {
            return RingStrip(timeline: loaded).weeks
        }
        let monday = today.startOfWeek
        return RingStrip(
            timeline: Timeline(
                input: Timeline.Input(weightRecords: [], rejectedLines: [], meals: []),
                firstDay: monday,
                today: today)
        ).weeks
    }

    private func timeline() -> Timeline {
        let first = startedDay ?? records.map(\.day).min() ?? today
        return Timeline(
            input: Timeline.Input(
                weightRecords: records, rejectedLines: rejectedLines, meals: meals),
            firstDay: first, today: today)
    }

    private func title(loaded: Timeline?) -> String {
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

/// 食事の画面へ潜る行き先。画面は、そのときのカードを食事の ID で引いて描く
nonisolated private struct MealRoute: Hashable {
    let mealId: UUID
}

/// 開いている食事が消えたら（ほかの端末で消して同期で届いた）、タイムラインに戻る
private struct MealDestination: View {
    let card: MealCard?
    let screen: (MealCard) -> MealScreen

    var body: some View {
        if let card {
            screen(card)
        } else {
            Color(.systemGroupedBackground)
                .onAppear {
                    dismiss()
                }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

private enum WeightEntryPhase: Equatable {
    case closed
    case preparing
    case showing
}

private enum CameraPhase: Equatable {
    case closed
    /// 許可を確かめている（初めてなら、iOS の許可の画面を出している）
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
