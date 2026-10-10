import Foundation
import NuToriCore
import PhotosUI
import SwiftUI

struct TimelineScreen: View {
    let records: [WeightRecord]
    /// 同期で届いた体重の傾向。体重記録が無ければ nil
    let weightTrend: WeightTrend?
    let initialPull: InitialPull
    let today: CalendarDay
    /// 記録した時刻と、操作にかかった時間を測るための今
    let now: () -> Date
    /// 記録した体重を、どのタイムゾーンの記録にするか
    let timeZone: () -> TimeZone
    let rejectedLines: [RejectedLine]
    let meals: [MealCard]
    /// 答えた知らせも含む
    let notices: [Notice]
    /// まだ届いていない記録（薄く描く）
    let undeliveredRecords: UndeliveredRecords
    let capture: (ClientUsageEvent) async -> Void
    /// 記録忘れの通知を押して開いたときの着き先。着いたら `noteReminderLanded` を呼ぶ
    let reminderLanding: ReminderLanding?
    let noteReminderLanded: () -> Void
    /// 体重を記録したあと。この端末でまだ通知の許可を求めていなければ求める
    let requestNotificationPermission: () async -> Void
    let prepareWeightEntry: () async -> Void
    let saveWeight: (WeightEntry.Write) async -> Void
    /// 入力欄から文章を送る。送れるかは書く欄が決め、送れるときだけ呼ぶ
    let sendText: (TextDraft) async -> Void
    let accountActions: AccountActions
    let mealActions: MealActions
    /// 送った文章・その状態・返事・見守る要求で受け取っている途中の返事
    var conversation = Timeline.Conversation.none
    var conversationActions = ConversationActions.none

    var body: some View {
        let loaded = showsLoading ? nil : timeline()
        let selectedDay = visibleDay ?? loaded?.days.last?.day ?? today
        NavigationStack(path: $navigationPath) {
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
                    .overlay(alignment: .top) {
                        if let card = loaded?.noticeAwaitingAnswer,
                            unansweredNoticeLineVisibility.shows(for: card)
                        {
                            unansweredNoticeLine(card)
                        }
                    }
            }
            .navigationDestination(for: CalendarDay.self) { day in
                WeightScreen(
                    day: day,
                    records: records,
                    firstDay: firstDay,
                    today: today,
                    trendChart: WeightTrendChart(
                        weightRecords: records,
                        trend: weightTrend,
                        firstDay: firstDay,
                        today: today
                    ),
                    rejectedLines: rejectedLines,
                    capture: capture,
                    saveWeight: saveWeight
                )
            }
            .navigationDestination(for: MealRoute.self) { route in
                MealDestination(card: meals.first { $0.meal.id == route.mealId }) { card in
                    MealScreen(
                        card: card,
                        now: now,
                        capture: capture,
                        actions: mealActions,
                        returnToTimeline: {
                            navigationPath = NavigationPath()
                        },
                        rejectedLines: rejectedLines,
                        confirmsDeletion: false,
                        confirmsLastDishDeletion: false,
                        addingDish: false,
                        sentText: card.meal.sentTextId.flatMap { sentTextId in
                            conversation.sentTexts.first { $0.id == sentTextId }
                        }
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
                    DaySummarySheet(
                        timeline: loaded, day: day, weightRecords: records,
                        weightTrend: weightTrend
                    ) { chosen in
                        dayFocus = .scrollingTo(chosen)
                    }
                }
            }
        }
        // 通知の許可は、記録したシートが閉じてから求める。シートの上に重ねない
        .sheet(
            isPresented: showsWeightEntry,
            onDismiss: {
                guard recordedInWeightEntry else { return }
                recordedInWeightEntry = false
                Task { await requestNotificationPermission() }
            }
        ) {
            WeightEntrySheet(
                records: records,
                today: today,
                now: now,
                timeZone: timeZone,
                capture: capture,
                onRecord: { write in
                    recordedInWeightEntry = true
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
        .sensoryFeedback(.success, trigger: noticeRecordedCount)
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
    /// 潜った画面の並び。食事を消したら、料理の画面からでもタイムラインまで戻す
    @State private var navigationPath = NavigationPath()
    @State private var visibleDay: CalendarDay?
    @State private var weightEntryPhase = WeightEntryPhase.closed
    /// 体重のシートで記録したか。シートが閉じたら通知の許可を求める合図
    @State private var recordedInWeightEntry = false
    @State private var dayFocus: DayFocus = .timeline
    @State private var cameraPhase = CameraPhase.closed
    /// カメラを許可していない人に出す知らせ。ほかを押すか、タイムラインを動かすと消える
    @State private var showsCameraNotice = false
    /// 「写真を使用」を押した回数。触覚を鳴らす合図
    @State private var capturedCount = 0
    @State private var showsPhotoPicker = false
    /// 体重の知らせの中で記録した回数。触覚を鳴らす合図
    @State private var noticeRecordedCount = 0
    /// 今日の答えていない知らせの1行を帯の下に出すかを、カードの最後に届いた位置で覚える
    @State private var unansweredNoticeLineVisibility = UnansweredNoticeLineVisibility()
    @State private var pickedPhotos: [PhotosPickerItem] = []
    /// 伸びている返事に合わせて一番下へ追うか。使う人が動かして一番下から離れたら止め、一番下へ戻すか、伸びる返事が無くなったら追う
    @State private var followsGrowingReply = true
    /// タイムラインの一番下が見えているか
    @State private var showsTimelineEnd = true
    /// 返事の最初の文字を出したときの出来事を、送った文章ごとに1回だけ送る
    @State private var replyFirstText = ReplyFirstTextWatch()

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

    /// 体重の画面とタイムラインで同じ日を使う
    private var firstDay: CalendarDay {
        Timeline.firstDay(startedDay: startedDay, weightRecords: records, today: today)
    }

    @ViewBuilder private func content(loaded: Timeline?) -> some View {
        if let loaded {
            timelineList(loaded)
        } else {
            VStack {
                ProgressView()
                Text("記録を読み込んでいます…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func timelineList(_ timeline: Timeline) -> some View {
        GeometryReader { geo in
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
                                daySection(day, in: timeline)
                                    .id(day.day)
                            }
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .bottom)
                }
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .defaultScrollAnchor(.bottom, for: .alignment)
                // 返事が伸びるあいだは一番下へ追う。使う人が上へ動かしたら、追うのを止める
                .defaultScrollAnchor(followsGrowingReply ? .bottom : .top, for: .sizeChanges)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.visibleRect.maxY >= geometry.contentSize.height - 1
                } action: { _, atEnd in
                    showsTimelineEnd = atEnd
                }
                .onScrollPhaseChange { _, phase in
                    if phase != .idle {
                        showsCameraNotice = false
                    }
                    // 動かしているあいだは追わず、止まったときに一番下が見えていれば、また追う
                    if phase == .interacting {
                        followsGrowingReply = false
                    } else if phase == .idle {
                        followsGrowingReply = showsTimelineEnd
                    }
                }
                .onChange(of: timeline.hasGrowingReply) { _, growing in
                    if !growing {
                        followsGrowingReply = true
                    }
                }
                .onChange(of: timeline.days, initial: true) { _, _ in
                    let events = replyFirstText.note(timeline, at: now())
                    for event in events {
                        Task { await capture(event) }
                    }
                }
                .coordinateSpace(.named("timeline"))
                .onPreferenceChange(TimelineDayOffsetsKey.self) { offsets in
                    visibleDay = dayInView(
                        offsets, timeline: timeline, viewportHeight: geo.size.height)
                }
                .onPreferenceChange(AwaitingNoticePositionKey.self) { position in
                    unansweredNoticeLineVisibility.note(position)
                }
                .onChange(of: dayFocus) { _, focus in
                    switch focus {
                    case .scrollingTo(let day):
                        proxy.scrollTo(day, anchor: .top)
                    case .scrollingToItem(let itemId):
                        withAnimation {
                            proxy.scrollTo(itemId, anchor: .top)
                        }
                    case .scrollingToEnd(let day):
                        proxy.scrollTo(day, anchor: .bottom)
                    case .timeline, .summary:
                        return
                    }
                    dayFocus = .timeline
                }
                // 通知を押して開いたら、その日の知らせの位置に、無ければいちばん下に着く
                .onChange(of: reminderLanding, initial: true) { _, landing in
                    guard let landing else { return }
                    dayFocus = DayFocus(timeline.landing(for: landing))
                    noteReminderLanded()
                }
            }
        }
    }

    private func daySection(_ day: Timeline.Day, in timeline: Timeline) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 日の見出しは、タイムライン全体で中央に揃える。上に浮かせて止めない（ナビゲーションバーの題と1日の丸の帯が、いま見ている日を示す）
            Text(TimelineDayText.label(for: day.day))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            ForEach(day.items) { item in
                itemView(item, in: timeline)
                    .padding(.top, Self.gap(before: item, in: day))
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

    /// 会話のまとまりの見た目（仕様 #419「会話のまとまりの見た目」）。隣り合う発言（送った文章と返事、返事と次の送った文章）は 8、
    /// あいだに別の記録か日の見出しがある発言と、発言のすぐあとの記録は 24 空ける。会話の区切りとは結びつけない。
    /// DESIGN.md の Layout は余白を SwiftUI の標準に任せて自前の数値を持たないが、会話のまとまりを余白だけで見せるため、ここは数値で決める。
    /// ほかの項目の間と、吹き出しとその下の文章の食事のカードの間は、VStack の標準の間隔と同じ 8 にする
    private static func gap(before item: Timeline.Item, in day: Timeline.Day) -> CGFloat {
        let adjacent: CGFloat = 8
        let apart: CGFloat = 24
        guard let index = day.items.firstIndex(of: item) else { return adjacent }
        let previous = index > 0 ? day.items[index - 1] : nil
        if item.isUtterance {
            return day.followsUtterance(item) ? adjacent : apart
        }
        if case .meal(let card) = item, let sentTextId = card.meal.sentTextId {
            switch previous {
            case .sentText(let bubble) where bubble.sentText.id == sentTextId:
                return adjacent
            case .meal(let previousCard) where previousCard.meal.sentTextId == sentTextId:
                return adjacent
            default:
                break
            }
        }
        return previous?.isUtterance == true ? apart : adjacent
    }

    @ViewBuilder private func itemView(_ item: Timeline.Item, in timeline: Timeline) -> some View {
        switch item {
        case .weightRecord(let record):
            NavigationLink(value: record.day) {
                WeightRecordRow(record: record)
            }
            .buttonStyle(.plain)
            .undeliveredRecord(timeline.isUndelivered(item))
            .accessibilityIdentifier("weight-row")
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .rejectedWeightLine(let line):
            Text(line.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("rejected-weight-line")
        case .meal(let card) where card.meal.sentTextId != nil:
            writtenMealCard(card, isUndelivered: timeline.isUndelivered(item))
        case .meal(let card):
            // どの状態のカードも、押すと食事の画面へ潜る
            NavigationLink(value: MealRoute(mealId: card.meal.id)) {
                MealCardView(card: card) { photoId in
                    await mealActions.loadPhoto(card.meal.id, photoId)
                }
            }
            .buttonStyle(.plain)
            .undeliveredRecord(timeline.isUndelivered(item))
            .accessibilityIdentifier("meal-card")
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .rejectedMealLine(let line):
            Text(line.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("rejected-meal-line")
        case .sentText(let bubble):
            SentTextBubbleView(
                bubble: bubble, isUndelivered: timeline.isUndelivered(item)
            ) { reason in
                followsGrowingReply = true
                Task { await conversationActions.resend(bubble.sentText.id, reason) }
            }
        case .rejectedSentTextLine(let line):
            Text(line.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("rejected-sent-text-line")
        case .reply(let reply):
            ReplyView(
                reply: reply,
                openMeal: { card in
                    navigationPath.append(MealRoute(mealId: card.meal.id))
                    Task { await capture(.replyMealOpened) }
                },
                loadPhoto: mealActions.loadPhoto
            )
            .id(item.id)
        case .notice(let card):
            WeightNoticeCard(
                card: card,
                records: records,
                today: today,
                now: now,
                timeZone: timeZone,
                capture: capture,
                onRecord: { write in
                    noticeRecordedCount += 1
                    Task {
                        await saveWeight(write)
                        // 知らせの中で記録したときは、記録した直後に通知の許可を求める
                        await requestNotificationPermission()
                    }
                }
            )
            .id(item.id)
            .background {
                if card.form == .awaitingAnswer {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: AwaitingNoticePositionKey.self,
                            value: UnansweredNoticeLineVisibility.CardPosition(
                                noticeId: card.notice.id,
                                maxY: Double(geo.frame(in: .named("timeline")).maxY)))
                    }
                }
            }
        }
    }

    /// 文章の食事のカード。写真の場所を持たず、文章の食事と分かる手がかりは上の吹き出し。
    /// 下に「会話として送り直す」を添える。押しても確かめず、その文章の食事がすべて消える
    private func writtenMealCard(_ card: MealCard, isUndelivered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: MealRoute(mealId: card.meal.id)) {
                MealCardView(card: card, showsCardChrome: false) { photoId in
                    await mealActions.loadPhoto(card.meal.id, photoId)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("meal-card")
            Divider()
            Button("会話として送り直す") {
                guard let sentTextId = card.meal.sentTextId else { return }
                let deletedMealCount = meals.filter { $0.meal.sentTextId == sentTextId }.count
                followsGrowingReply = true
                Task {
                    await conversationActions.resendAsConversation(sentTextId, deletedMealCount)
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.horizontal)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("resend-as-conversation")
        }
        .modifier(OwnRecordCard())
        .undeliveredRecord(isUndelivered)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// 帯の下の1行。押すと、その知らせまで戻る
    private func unansweredNoticeLine(_ card: NoticeCard) -> some View {
        Button {
            dayFocus = .scrollingToItem(Timeline.Item.notice(card).id)
            Task { await capture(.unansweredNoticeLineTapped) }
        } label: {
            HStack(spacing: 12) {
                Text("今日の体重がまだです")
                    .foregroundStyle(.primary)
                Spacer()
                Text("見る")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }
            .font(.footnote)
            .padding(.horizontal)
            .frame(minHeight: 44)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            .overlay(Capsule().stroke(Color(.separator), lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding([.horizontal, .top])
        .accessibilityIdentifier("unanswered-notice-line")
    }

    private func composer() -> some View {
        TimelineComposer(
            weightRecordedToday: records.contains { $0.day == today },
            preparingWeightEntry: weightEntryPhase == .preparing,
            showsCameraNotice: showsCameraNotice,
            initialDraft: TextDraft(),
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
            },
            onPresetTapped: { preset in
                showsCameraNotice = false
                Task { await capture(.presetTapped(preset)) }
            },
            onSendText: { draft in
                showsCameraNotice = false
                followsGrowingReply = true
                Task { await sendText(draft) }
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
                input: Timeline.Input(weightRecords: [], rejectedLines: [], meals: [], notices: []),
                firstDay: monday,
                today: today)
        ).weeks
    }

    private func timeline() -> Timeline {
        Timeline(
            input: Timeline.Input(
                weightRecords: records, rejectedLines: rejectedLines, meals: meals,
                notices: notices, undelivered: undeliveredRecords, conversation: conversation),
            firstDay: firstDay, today: today)
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
    /// 答えていない知らせの1行と、記録忘れの通知から、その知らせのカードへ
    case scrollingToItem(Timeline.Item.ID)
    /// 記録忘れの通知から、その日（今日）のいちばん下へ
    case scrollingToEnd(CalendarDay)

    init(_ landing: Timeline.Landing) {
        switch landing {
        case .item(let itemId): self = .scrollingToItem(itemId)
        case .end(let day): self = .scrollingToEnd(day)
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

/// 今日の答えていない知らせのカードの位置。カードを描いていなければ nil
private struct AwaitingNoticePositionKey: PreferenceKey {
    static let defaultValue: UnansweredNoticeLineVisibility.CardPosition? = nil

    static func reduce(
        value: inout UnansweredNoticeLineVisibility.CardPosition?,
        nextValue: () -> UnansweredNoticeLineVisibility.CardPosition?
    ) {
        value = nextValue() ?? value
    }
}
