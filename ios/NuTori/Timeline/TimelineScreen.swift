import Foundation
import NuToriCore
import PhotosUI
import SwiftUI
import UIKit

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
    /// 閉じた目標も含む。1日の丸と日のまとめを、その日の1日の目安と比べるために引く
    let goals: [Goal]
    /// 目標がまだ届いていない1日の目安も含む
    let dailyGuides: [DailyGuide]
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
    let conversation: Timeline.Conversation
    let conversationActions: ConversationActions
    /// 目標を立てる知らせのカードが広げる、目標の設定の流れ
    let goalSetup: GoalSetupSession

    var body: some View {
        let loaded = showsLoading ? nil : timeline()
        let shownDay = loaded.flatMap { viewport.shownDay(newestDay: $0.newestDay) } ?? today
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                DayRingStrip(
                    weeks: stripWeeks(loaded: loaded),
                    selectedDay: shownDay,
                    today: today,
                    openableDays: loaded?.dayRange
                ) { day in
                    showsCameraNotice = false
                    summaryDay = day
                }
                Divider()
                content(loaded: loaded)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .top) {
                        if let loaded {
                            unansweredNoticeLines(in: loaded)
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
                    saveWeight: saveWeight,
                    startGoalSetup: loaded.flatMap(goalSetupStarter(in:)).map { start in
                        { start(.weightScreen) }
                    }
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
            .navigationTitle(TimelineDayText.label(for: shownDay))
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
                if let summaryDay, let loaded {
                    DaySummarySheet(
                        timeline: loaded, day: summaryDay, weightRecords: records,
                        weightTrend: weightTrend, goalProgress: goalProgress, today: today,
                        startGoalSetup: goalSetupStarter(in: loaded).map { start in
                            { start(.daySummary) }
                        }
                    ) { chosen in
                        self.summaryDay = nil
                        waitingInstructions += viewport.dayChosen(chosen, in: loaded.days)
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
    @State private var weightEntryPhase = WeightEntryPhase.closed
    /// 体重のシートで記録したか。シートが閉じたら通知の許可を求める合図
    @State private var recordedInWeightEntry = false
    /// 日のまとめを出している日
    @State private var summaryDay: CalendarDay?
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
    /// 見える範囲の規則は NuToriCore の TimelineViewport が持つ。規則は前の出来事を覚えて決めるので、描き直しをまたいで持つために @State に置く
    @State private var viewport = TimelineViewport()
    /// 実行を待っている指示。動かす口（ScrollViewProxy）は ScrollViewReader の中にしか無く、通知から開いた直後のカードと、足したばかりの項目は、並んでからでないと着けないので、次の更新まで持ってから実行する
    @State private var waitingInstructions: [TimelineViewport.Instruction] = []
    /// 返事の最初の文字を出したときの出来事を、送った文章ごとに1回だけ送る
    @State private var replyFirstText = ReplyFirstTextWatch()
    /// 目標を立てる知らせのカードまで送って広げるよう頼まれた回数。開いているページが同じでも送り直す合図
    @State private var goalSetupScrollRequests = 0

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
            get: { summaryDay != nil },
            set: { presented in
                if !presented {
                    summaryDay = nil
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
        let listedDays = viewport.listedDays(of: timeline.days)
        return GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    // 中身が画面より短いときは下に寄せ、長いときは下端から開く
                    VStack(alignment: .leading) {
                        Spacer(minLength: 0)
                        // 並べる日を新しいほうに絞り、遅れて読む並び（LazyVStack）にしない。理由は TimelineViewport
                        VStack(alignment: .leading) {
                            if let startedDay, listedDays.first?.day == timeline.days.first?.day {
                                Text("\(TimelineDayText.label(for: startedDay))から記録しています")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            ForEach(listedDays, id: \.day) { day in
                                daySection(day, in: timeline)
                                    .id(day.day)
                            }
                        }
                        .padding()
                        .id(Self.contentId)
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .bottom)
                    // 余白や文を押したら、キーボードを下げる。押せるもの（記録の行、カード、知らせの中の欄）は自分の動きをする
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }
                }
                // 送ったあともキーボードを残すので、下げる手立てはタイムラインを動かすか押すこと。動かしたときに下げるかは見える範囲の指示で決まるので、ScrollView には下げさせない
                .scrollDismissesKeyboard(.never)
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .defaultScrollAnchor(.bottom, for: .alignment)
                .defaultScrollAnchor(
                    viewport.followsSizeChanges ? .bottom : .top, for: .sizeChanges
                )
                .onScrollGeometryChange(for: TimelineViewport.EndPosition.self) { geometry in
                    // 見えている所（visibleRect）は、下の入力欄に隠れた分（contentInsets.bottom）まで含む
                    TimelineViewport.EndPosition(
                        visibleMaxY: geometry.visibleRect.maxY,
                        hiddenByComposer: geometry.contentInsets.bottom,
                        contentHeight: geometry.contentSize.height)
                } action: { _, position in
                    viewport.endPositionChanged(to: position)
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    // 位置は小数で届くので、1 までのずれは上端ちょうどとみなす
                    geometry.contentOffset.y <= 1 - geometry.contentInsets.top
                } action: { _, isAtStart in
                    viewport.startReachedChanged(isAtStart: isAtStart)
                }
                .onScrollPhaseChange { oldPhase, phase in
                    if phase != .idle {
                        showsCameraNotice = false
                    }
                    perform(
                        viewport.scrollPhaseChanged(
                            from: TimelineViewport.ScrollPhase(oldPhase),
                            to: TimelineViewport.ScrollPhase(phase)),
                        in: timeline, with: proxy)
                }
                // 開いたときにも渡して、並べる日を決める
                .onChange(of: timeline.days, initial: true) { old, new in
                    let returning = viewport.daysChanged(from: old, to: new, now: now())
                    guard !returning.isEmpty else { return }
                    // 日のまとめを開いていても、足した項目を見せる
                    summaryDay = nil
                    waitingInstructions += returning
                }
                .onChange(of: timeline.hasGrowingReply) { _, growing in
                    viewport.growingReplyChanged(isGrowing: growing)
                }
                .onChange(of: timeline.days, initial: true) { _, _ in
                    let events = replyFirstText.note(timeline, at: now())
                    for event in events {
                        Task { await capture(event) }
                    }
                }
                .coordinateSpace(.named("timeline"))
                .onPreferenceChange(TimelineDayPositionsKey.self) { positions in
                    // 位置は動かすたびに届くので、出す日が変わらないあいだは描き直させない
                    var moved = viewport
                    moved.dayPositionsChanged(
                        positions, newestDay: timeline.newestDay,
                        viewportHeight: Double(geo.size.height))
                    if moved != viewport {
                        viewport = moved
                    }
                }
                .onPreferenceChange(AwaitingNoticePositionKey.self) { positions in
                    for position in positions {
                        unansweredNoticeLineVisibility.note(position)
                    }
                }
                .onChange(of: waitingInstructions) { _, instructions in
                    guard !instructions.isEmpty else { return }
                    waitingInstructions = []
                    perform(instructions, in: timeline, with: proxy)
                }
                // 目標の設定を広げた・ページを送ったら、カードの下端（塗ったボタン）が入力欄の上に見えるところまで、タイムラインごと送る
                .onChange(of: goalSetupScrollKey) { _, key in
                    guard key.page != nil, let notice = timeline.goalSetupNotice else { return }
                    let cardId = Timeline.Item.goalSetupNotice(notice).id
                    // 並べていない日のカードなら、その日が並んでから送り直す
                    guard viewport.revealItem(cardId, in: timeline.days) else {
                        goalSetupScrollRequests += 1
                        return
                    }
                    withAnimation {
                        proxy.scrollTo(cardId, anchor: .bottom)
                    }
                }
                // 通知を押して開いたら、その日の知らせの位置に、無ければいちばん下に着く
                .onChange(of: reminderLanding, initial: true) { _, landing in
                    guard let landing else { return }
                    summaryDay = nil
                    waitingInstructions += viewport.landingRequested(
                        timeline.landing(for: landing), in: timeline.days)
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
                    key: TimelineDayPositionsKey.self,
                    value: [
                        TimelineViewport.DayPosition(
                            day: day.day, minY: Double(geo.frame(in: .named("timeline")).minY))
                    ]
                )
            }
        }
    }

    /// タイムラインの中身の全体。下の余白まで含めた下端へ動かすときに名指しする
    private static let contentId = "timeline-content"

    /// 話し手の替わり目の見た目（#449 の解決コメント）。詰めるか空けるかは `Timeline.Day.spacing(before:)` が決める。
    /// DESIGN.md の Layout は余白を SwiftUI の標準に任せて自前の数値を持たないが、話し手の替わり目を余白だけで見せるため、ここは数値で決める。
    /// 詰めるのは VStack の標準の間隔と同じ 8、空けるのは DESIGN.md のまとまりの間（section-gap）の 24
    private static func gap(before item: Timeline.Item, in day: Timeline.Day) -> CGFloat {
        switch day.spacing(before: item) {
        case .close: 8
        case .apart: 24
        }
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
            RejectedLineText(text: line.text, subject: .weightRecord)
        case .meal(let card):
            // どの状態のカードも、押すと食事の画面へ潜る
            NavigationLink(value: MealRoute(mealId: card.meal.id)) {
                MealCardView(card: card) { photoId in
                    await mealActions.loadPhoto(card.meal.id, photoId)
                }
                .modifier(OwnRecordCard())
            }
            .buttonStyle(.plain)
            .undeliveredRecord(timeline.isUndelivered(item))
            .accessibilityIdentifier("meal-card")
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .rejectedMealLine(let line):
            RejectedLineText(text: line.text, subject: .meal)
        case .sentText(let bubble):
            SentTextBubbleView(
                bubble: bubble, isUndelivered: timeline.isUndelivered(item),
                resend: { reason in
                    viewport.textResent()
                    Task { await conversationActions.resend(bubble.sentText.id, reason) }
                },
                resendAsConversation: {
                    viewport.textResent()
                    Task {
                        await conversationActions.resendAsConversation(
                            bubble.sentText.id, bubble.meals.count)
                    }
                },
                isMealUndelivered: { timeline.isUndelivered(.meal($0)) },
                openMeal: { navigationPath.append(MealRoute(mealId: $0.meal.id)) },
                loadPhoto: mealActions.loadPhoto
            )
        case .rejectedSentTextLine(let line):
            RejectedLineText(text: line.text, subject: .sentText)
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
                            value: [
                                UnansweredNoticeLineVisibility.CardPosition(
                                    noticeId: card.notice.id,
                                    maxY: Double(geo.frame(in: .named("timeline")).maxY))
                            ])
                    }
                }
            }
        case .goalSetupNotice(let notice):
            GoalSetupNoticeCard(
                notice: notice,
                goal: currentGoal,
                dailyGuide: currentGoal.flatMap(dailyGuide(of:)),
                session: goalSetup,
                timeZone: timeZone,
                open: { entry in openGoalSetup(from: entry) }
            )
            .id(item.id)
            .background {
                if notice.response == nil {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: AwaitingNoticePositionKey.self,
                            value: [
                                UnansweredNoticeLineVisibility.CardPosition(
                                    noticeId: notice.id,
                                    maxY: Double(geo.frame(in: .named("timeline")).maxY))
                            ])
                    }
                }
            }
        }
    }

    /// 帯の下の1行。カードが画面の上へ流れて見えない、答えていない知らせだけを、出した時刻の古い順に出す
    private func unansweredNoticeLines(in timeline: Timeline) -> some View {
        VStack(spacing: 0) {
            ForEach(
                timeline.unansweredNoticeLines.filter { unansweredNoticeLineVisibility.shows($0) },
                id: \.self
            ) { line in
                switch line {
                case .missedWeightRecord(let card):
                    unansweredNoticeLine(card, in: timeline.days)
                case .goalSetup:
                    unansweredGoalSetupLine
                }
            }
        }
    }

    /// 帯の下の1行「目標を立てる ›」。押すとカードまで送って広げる
    private var unansweredGoalSetupLine: some View {
        Button {
            openGoalSetup(from: .unansweredNoticeLine)
        } label: {
            HStack(spacing: 12) {
                Text("目標を立てる")
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
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
        .accessibilityLabel("目標を立てる")
        .accessibilityIdentifier("unanswered-goal-setup-line")
    }

    /// 帯の下の1行。押すと、その知らせまで戻る
    private func unansweredNoticeLine(_ card: NoticeCard, in days: [Timeline.Day]) -> some View {
        Button {
            waitingInstructions += viewport.landingRequested(
                .item(Timeline.Item.notice(card).id), in: days)
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
            expandsGoalSetup: goalSetup.isOpen && currentGoal == nil,
            preparingWeightEntry: weightEntryPhase == .preparing,
            showsCameraNotice: showsCameraNotice,
            initialDraft: TextDraft.empty,
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
                Task { await sendText(draft) }
            }
        )
    }

    private func perform(
        _ instructions: [TimelineViewport.Instruction], in timeline: Timeline,
        with proxy: ScrollViewProxy
    ) {
        for instruction in instructions {
            switch instruction {
            case .scroll(let target, let animated):
                if animated {
                    withAnimation {
                        scroll(to: target, with: proxy)
                    }
                } else {
                    scroll(to: target, with: proxy)
                }
            case .dismissKeyboard:
                dismissKeyboard()
            case .listOlderDays:
                // 足した日が並んでから、見ていた日を上端に置き直す
                waitingInstructions += viewport.listOlderDays(of: timeline.days)
            }
        }
    }

    private func scroll(to target: TimelineViewport.ScrollTarget, with proxy: ScrollViewProxy) {
        switch target {
        case .end: proxy.scrollTo(Self.contentId, anchor: .bottom)
        case .day(let day): proxy.scrollTo(day, anchor: .top)
        case .item(let itemId): proxy.scrollTo(itemId, anchor: .top)
        }
    }

    /// 書く欄と知らせの中の欄のどちらにカーソルがあっても下げる
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                input: Timeline.Input(
                    weightRecords: [], rejectedLines: [], meals: [], notices: [],
                    undelivered: .none, conversation: .none),
                firstDay: monday,
                today: today)
        ).weeks
    }

    private func timeline() -> Timeline {
        Timeline(
            input: Timeline.Input(
                weightRecords: records, rejectedLines: rejectedLines, meals: meals,
                notices: notices, undelivered: undeliveredRecords, conversation: conversation,
                goals: goals, dailyGuides: dailyGuides),
            firstDay: firstDay, today: today)
    }

    /// 今の目標。今日を含む目標が無ければ（西へ移ったあと）、閉じていない目標
    private var currentGoal: Goal? {
        DailyGuideForDay(on: today, goals: goals, dailyGuides: dailyGuides)?.goal
            ?? goals.first { $0.closure == nil }
    }

    /// その目標の、当てる始まりの日が今日以前で最も遅い1日の目安。今日より後に始まる目標なら、最も早いもの
    private func dailyGuide(of goal: Goal) -> DailyGuide? {
        let guides = dailyGuides.filter { $0.goalId == goal.id }.sorted {
            $0.effectiveDay < $1.effectiveDay
        }
        return guides.last { $0.effectiveDay <= today } ?? guides.first
    }

    /// 日のまとめと体重の画面の「目標を立てる」。目標が無く、知らせのカードがタイムラインにあるときだけ置く
    private func goalSetupStarter(in timeline: Timeline)
        -> ((GoalSetupObservation.Entry) -> Void)?
    {
        guard currentGoal == nil, timeline.goalSetupNotice != nil else { return nil }
        return { entry in openGoalSetup(from: entry) }
    }

    /// シートを閉じ、潜った画面から戻って、知らせのカードまで送って広げる。途中まで進めていれば同じページから
    private func openGoalSetup(from entry: GoalSetupObservation.Entry) {
        showsCameraNotice = false
        summaryDay = nil
        navigationPath = NavigationPath()
        Task {
            await goalSetup.open(from: entry)
            goalSetupScrollRequests += 1
        }
    }

    /// 目標の設定を広げているあいだのページ。変わったら、カードの下端まで送る
    private var goalSetupScrollKey: GoalSetupScrollKey {
        GoalSetupScrollKey(
            requests: goalSetupScrollRequests,
            page: goalSetup.flow.flatMap { $0.isOpen ? GoalSetupPageKey($0.page) : nil })
    }

    /// 日のまとめの進行中の要約。今日を含む目標で出す
    private var goalProgress: GoalProgress? {
        DailyGuideForDay(on: today, goals: goals, dailyGuides: dailyGuides).flatMap {
            GoalProgress(goal: $0.goal, today: today, weightTrend: weightTrend)
        }
    }
}

extension TimelineViewport.ScrollPhase {
    fileprivate init(_ phase: SwiftUI.ScrollPhase) {
        switch phase {
        case .idle: self = .idle
        case .tracking: self = .tracking
        case .interacting: self = .interacting
        case .decelerating: self = .decelerating
        case .animating: self = .animating
        // 知らない相は、使う人が触っていない動きとして扱う
        @unknown default: self = .animating
        }
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

private struct TimelineDayPositionsKey: PreferenceKey {
    static let defaultValue: [TimelineViewport.DayPosition] = []

    static func reduce(
        value: inout [TimelineViewport.DayPosition],
        nextValue: () -> [TimelineViewport.DayPosition]
    ) {
        value.append(contentsOf: nextValue())
    }
}

/// 答えていない知らせのカード（今日の体重の知らせと、目標を立てる知らせ）の位置。描いていないカードの位置は無い
private struct AwaitingNoticePositionKey: PreferenceKey {
    static let defaultValue: [UnansweredNoticeLineVisibility.CardPosition] = []

    static func reduce(
        value: inout [UnansweredNoticeLineVisibility.CardPosition],
        nextValue: () -> [UnansweredNoticeLineVisibility.CardPosition]
    ) {
        value.append(contentsOf: nextValue())
    }
}

private struct GoalSetupScrollKey: Equatable {
    let requests: Int
    /// 広げていなければ nil
    let page: GoalSetupPageKey?
}
