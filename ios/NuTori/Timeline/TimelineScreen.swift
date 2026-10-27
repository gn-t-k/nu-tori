import Foundation
import NuToriCore
import PhotosUI
import SwiftUI
import UIKit

struct TimelineScreen: View {
    /// 記録と今日と今から組んだ、描く値の全部。潜った画面と日のまとめにも、ここから渡す
    let snapshot: TimelineSnapshot
    /// 記録した時刻と、操作にかかった時間を測るための今
    let now: () -> Date
    /// 記録した体重を、どのタイムゾーンの記録にするか
    let timeZone: () -> TimeZone
    let capture: (ClientUsageEvent) async -> Void
    /// 記録忘れの通知を押して開いたときの着き先。着いたら `noteReminderLanded` を呼ぶ
    let reminderLanding: ReminderLanding?
    let noteReminderLanded: () -> Void
    /// 体重を記録したあと。この端末でまだ通知の許可を求めていなければ求める
    let requestNotificationPermission: () async -> Void
    let prepareWeightEntry: () async -> Void
    /// 記録を作る・直す・消す編集を渡す。文章は、送れるかを書く欄が決め、送れるときだけ渡す
    let performEdit: (UserEdit) async -> Void
    let accountActions: AccountActions
    /// 課金画面を開く（`paywallSheet`）ときに渡す
    let paywallActions: PaywallActions
    let mealActions: MealActions
    /// タイムライン（目標を立てる知らせのカードと、立て直すあいだの一番下のカード）に描く、目標の設定の流れの形
    let goalSetupFlow: GoalSetupNoticeCard.Flow
    /// 目標の画面の、今の目標のカードの場所に描く、目標の設定の流れの形
    let goalScreenGoalSetupFlow: GoalSetupNoticeCard.Flow
    /// 目標の設定のカードを、開いた場所で広げる。途中まで進めていれば同じページから
    let openGoalSetupFlow: (GoalSetupObservation.Entry, GoalSetupSession.Place) async -> Void

    var body: some View {
        let loaded = snapshot.timeline
        let shownDay =
            loaded.flatMap { viewport.shownDay(newestDay: $0.newestDay) } ?? snapshot.today
        NavigationStack(path: path) {
            VStack(spacing: 0) {
                DayRingStrip(
                    weeks: snapshot.ringWeeks,
                    selectedDay: shownDay,
                    today: snapshot.today,
                    openableDays: loaded?.dayRange
                ) { day in
                    send(.dayRingTapped(day))
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
            // 行き先の中身を body に書き並べると、式の型を決めきれずにビルドが止まるので、関数に分ける
            .navigationDestination(for: TimelineNavigation.Route.self) { route in
                destination(route)
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
                send(.timelineLeft)
            }
            .navigationTitle(TimelineDayText.label(for: shownDay))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左上の目標の入口。目標がないあいだは置かない
                if let goalLink = snapshot.goalLink {
                    ToolbarItem(placement: .topBarLeading) {
                        GoalLinkCapsuleButton(capsule: goalLink) {
                            send(.goalScreenRequested(.goalLink))
                        }
                    }
                    // 灰色のカプセルそのものを入口の見た目にするので、ツールバーのガラスの地を重ねない
                    .sharedBackgroundVisibility(.hidden)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        send(.accountTapped)
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("アカウント")
                    .accessibilityIdentifier("account")
                }
            }
            .sheet(isPresented: isPresenting(.account)) {
                NavigationStack {
                    AccountScreenContainer(
                        now: now, timeZone: timeZone, actions: accountActions,
                        paywallActions: paywallActions
                    ) {
                        send(.dismissed(.account))
                    }
                }
                .accessibilityIdentifier("account-screen")
            }
            .paywallSheet(paywallRequest, actions: paywallActions)
            .sheet(isPresented: summaryPresented) {
                if case .daySummary(let summaryDay) = navigation.presentation, let loaded {
                    daySummarySheet(on: summaryDay, loaded: loaded)
                }
            }
        }
        .sheet(
            isPresented: isPresenting(.weightEntry(.showing)),
            onDismiss: {
                send(.weightEntryDisappeared)
            }
        ) {
            WeightEntrySheet(
                records: snapshot.weightRecords,
                today: snapshot.today,
                now: now,
                timeZone: timeZone,
                capture: capture,
                onRecord: { write in
                    send(.weightRecordedInEntry)
                    Task { await performEdit(.saveWeight(write)) }
                }
            )
        }
        .fullScreenCover(isPresented: isPresenting(.camera(.showing))) {
            MealCamera(
                onUse: { original, exif in
                    let sentAt = now()
                    capturedCount += 1
                    send(.photoTaken)
                    Task {
                        await performEdit(
                            .recordCapturedMeal(
                                MealPhotoOriginal(data: original, exif: exif), sentAt: sentAt))
                    }
                },
                onCancel: {
                    send(.cameraCancelled)
                }
            )
            .ignoresSafeArea()
        }
        // 「写真を使用」で、カメラを閉じながら触覚で知らせる
        .sensoryFeedback(.success, trigger: capturedCount)
        .sensoryFeedback(.success, trigger: noticeRecordedCount)
        .photosPicker(
            isPresented: isPresenting(.photoPicker),
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
            showPickedPhotosLoadingWhileRecording(count: items.count) {
                let originals = await PickedMealPhotos.originals(of: items)
                await performEdit(.recordPickedMeals(originals, pickedAt: pickedAt))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline")
    }

    /// 開いているシートと潜った画面の並び。移り方の規則は NuToriCore の TimelineNavigation が持つ
    @State private var navigation = TimelineNavigation()
    /// 「写真を使用」を押した回数。触覚を鳴らす合図
    @State private var capturedCount = 0
    /// 体重の知らせの中で記録した回数。触覚を鳴らす合図
    @State private var noticeRecordedCount = 0
    /// 答えていない知らせの1行を帯の下に出すかを、カードの最後に届いた位置で覚える
    @State private var unansweredNoticeLineVisibility = UnansweredNoticeLineVisibility()
    @State private var pickedPhotos: [PhotosPickerItem] = []
    /// 選んだ写真を読んで記録し終えるまで、タイムラインの一番下に出す仮のカード。読み終える前に選び直したら、選んだ回ごとに並べる
    @State private var loadingPickedPhotos: [PickedPhotosLoading] = []
    /// 見える範囲の規則は NuToriCore の TimelineViewport が持つ。規則は前の出来事を覚えて決めるので、描き直しをまたいで持つために @State に置く。
    /// 次に描いたあとで実行する指示（`waitingInstructions`）も持ち、変わったら動かす口（ScrollViewProxy）のある ScrollViewReader の中で実行する
    @State private var viewport = TimelineViewport()
    /// 返事の最初の文字を出したときの出来事を、送った文章ごとに1回だけ送る
    @State private var replyFirstText = ReplyFirstTextWatch()
    /// 目標を立てる知らせのカードまで送って広げるよう頼まれた回数。開いているページが同じでも送り直す合図
    @State private var goalSetupScrollRequests = 0

    /// 移り方に出来事を渡し、頼まれたことをする
    private func send(_ event: TimelineNavigation.Event) {
        for effect in navigation.receive(event, on: snapshot) {
            switch effect {
            case .prepareWeightEntry:
                Task {
                    await prepareWeightEntry()
                    send(.weightEntryPrepared)
                }
            case .prepareCamera:
                // 初めてのときは、カメラを開く前に iOS の許可の画面で求める
                Task {
                    switch await mealActions.prepareCamera() {
                    case .ready: send(.cameraReady)
                    case .notPermitted: send(.cameraNotPermitted)
                    case .noCamera: send(.cameraUnavailable)
                    }
                }
            case .openGoalSetup(let entry):
                Task {
                    await openGoalSetupFlow(entry, .timeline)
                    goalSetupScrollRequests += 1
                }
            case .requestNotificationPermission:
                Task { await requestNotificationPermission() }
            case .capture(let event):
                Task { await capture(event) }
            }
        }
    }

    private var path: Binding<[TimelineNavigation.Route]> {
        Binding(
            get: { navigation.path },
            set: { send(.pathChanged($0)) }
        )
    }

    /// 閉じたら（下へ送った、選ぶ画面で選び終えた）、移り方に知らせる
    private func isPresenting(_ presentation: TimelineNavigation.Presentation) -> Binding<Bool> {
        Binding(
            get: { navigation.presentation == presentation },
            set: { isPresented in
                if !isPresented {
                    send(.dismissed(presentation))
                }
            }
        )
    }

    private var summaryPresented: Binding<Bool> {
        Binding(
            get: {
                if case .daySummary = navigation.presentation { true } else { false }
            },
            set: { presented in
                if !presented, case .daySummary(let day) = navigation.presentation {
                    send(.dismissed(.daySummary(day)))
                }
            }
        )
    }

    private var paywallRequest: Binding<PaywallRequest?> {
        Binding(
            get: {
                if case .paywall(let request) = navigation.presentation { request } else { nil }
            },
            set: { request in
                if request == nil, case .paywall(let opened) = navigation.presentation {
                    send(.dismissed(.paywall(opened)))
                }
            }
        )
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
                            ForEach(listedDays, id: \.day) { day in
                                daySection(day, in: timeline)
                                    .id(day.day)
                            }
                            ForEach(loadingPickedPhotos) { loading in
                                PickedPhotosLoadingCard(photoCount: loading.photoCount)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.top, 8)
                                    .accessibilityIdentifier("picked-photos-loading")
                            }
                            restartGoalSetupCard
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
                .onScrollGeometryChange(for: TimelineViewport.StartPosition.self) { geometry in
                    TimelineViewport.StartPosition(
                        contentOffsetY: geometry.contentOffset.y,
                        topInset: geometry.contentInsets.top)
                } action: { _, position in
                    viewport.startPositionChanged(to: position)
                }
                .onScrollPhaseChange { oldPhase, phase in
                    if phase != .idle {
                        send(.timelineScrolled)
                    }
                    perform(
                        viewport.scrollPhaseChanged(
                            from: TimelineViewport.ScrollPhase(oldPhase),
                            to: TimelineViewport.ScrollPhase(phase), in: timeline.days),
                        with: proxy)
                }
                // 開いたときにも渡して、並べる日を決める
                .onChange(of: timeline.days, initial: true) { old, new in
                    perform(viewport.daysChanged(from: old, to: new, now: now()), with: proxy)
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
                .onChange(of: viewport.waitingInstructions) { _, instructions in
                    guard !instructions.isEmpty else { return }
                    perform(viewport.takeWaitingInstructions(), with: proxy)
                }
                // 目標の設定を広げた・ページを送ったら、カードの下端（塗ったボタン）が入力欄の上に見えるところまで、タイムラインごと送る
                .onChange(of: goalSetupScrollKey) { _, key in
                    guard key.page != nil else { return }
                    // 立て直すときは、タイムラインの一番下のカードを広げているので、下端まで送る
                    if snapshot.currentGoal != nil {
                        withAnimation {
                            proxy.scrollTo(Self.contentId, anchor: .bottom)
                        }
                        return
                    }
                    guard let notice = timeline.goalSetupNotice else { return }
                    perform(
                        viewport.revealItem(
                            Timeline.Item.goalSetupNotice(notice).id, in: timeline.days),
                        with: proxy)
                }
                // 通知を押して開いたら、その日の知らせの位置に、無ければいちばん下に着く。
                // 着き先は RootModel がヘルスケアを読んでから決めて渡すので、受け取ったことを返して消してもらい、次に同じ着き先で開いたときにも変わったと届くようにする。
                .onChange(of: reminderLanding, initial: true) { _, landing in
                    guard let landing else { return }
                    perform(viewport.reminderOpened(landing, in: timeline), with: proxy)
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
            NavigationLink(value: TimelineNavigation.Route.weightScreen(record.day)) {
                WeightRecordRow(record: record)
            }
            .buttonStyle(.plain)
            .undeliveredRecord(timeline.isUndelivered(item))
            .accessibilityIdentifier("weight-row")
            .ownRecordTime(record.clockText)
        case .rejectedWeightLine(let line):
            RejectedLineText(text: line.text, subject: .weightRecord)
        case .meal(let card):
            // どの状態のカードも、押すと食事の画面へ潜る
            NavigationLink(value: TimelineNavigation.Route.meal(card.meal.id)) {
                MealCardView(card: card, showsEatenTime: false) { photoId in
                    await mealActions.loadPhoto(card.meal.id, photoId)
                }
                .modifier(OwnRecordCard())
            }
            .buttonStyle(.plain)
            .undeliveredRecord(timeline.isUndelivered(item))
            .accessibilityIdentifier("meal-card")
            .ownRecordTime(card.eatenTimeText)
        case .rejectedMealLine(let line):
            RejectedLineText(text: line.text, subject: .meal)
        case .sentText(let bubble):
            SentTextBubbleView(
                bubble: bubble, isUndelivered: timeline.isUndelivered(item),
                regeneration: replyRegeneration(of: bubble),
                isMealUndelivered: { timeline.isUndelivered(.meal($0)) },
                openMeal: { send(.mealRequested($0.meal.id)) },
                loadPhoto: mealActions.loadPhoto
            )
        case .rejectedSentTextLine(let line):
            RejectedLineText(text: line.text, subject: .sentText)
        case .reply(let reply):
            ReplyView(
                reply: reply,
                openMeal: { card in
                    send(.mealRequested(card.meal.id))
                    Task { await capture(.replyMealOpened) }
                },
                loadPhoto: mealActions.loadPhoto
            )
            .id(item.id)
        case .notice(let card):
            WeightNoticeCard(
                card: card,
                records: snapshot.weightRecords,
                today: snapshot.today,
                now: now,
                timeZone: timeZone,
                capture: capture,
                onRecord: { write in
                    noticeRecordedCount += 1
                    Task {
                        await performEdit(.saveWeight(write))
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
        case .subscriptionNotice(let notice):
            SubscriptionNoticeCard(notice: notice) {
                send(.paywallRequested(.noticeCard))
            }
            .id(item.id)
        case .goalSetupNotice(let notice):
            GoalSetupNoticeCard(
                notice: notice,
                currentGoal: snapshot.currentGoal,
                flow: goalSetupFlow,
                timeZone: timeZone,
                open: { entry in send(.goalSetupRequested(entry)) }
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
        case .weeklyReviewCard(let card):
            WeeklyReviewCardView(card: card) {
                send(.weeklyReviewRequested(weekOf: card.days.lowerBound, .weeklyReviewCard))
            }
            .id(item.id)
        case .dailyGuideChangeNotice(let notice):
            DailyGuideChangeNoticeCard(notice: notice) {
                send(.goalScreenRequested(.dailyGuideChangeNotice))
            }
            .id(item.id)
        case .goalNotice(let notice):
            GoalNoticeCard(notice: notice) { entry in
                send(.goalSetupRequested(entry))
            }
            .id(item.id)
        }
    }

    /// 帯の下の1行。カードが画面の上へ流れて見えない、答えていない知らせだけを、出した時刻の古い順に出す
    private func unansweredNoticeLines(in timeline: Timeline) -> some View {
        let listedDays = viewport.listedDays(of: timeline.days)
        return VStack(spacing: 0) {
            ForEach(
                timeline.unansweredNoticeLines.filter {
                    unansweredNoticeLineVisibility.shows($0, listedDays: listedDays)
                },
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
            send(.goalSetupRequested(.unansweredNoticeLine))
        } label: {
            UnansweredNoticeLineLabel(text: "目標を立てる") {
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.plain)
        .padding([.horizontal, .top])
        .accessibilityLabel("目標を立てる")
        .accessibilityIdentifier("unanswered-goal-setup-line")
    }

    /// 帯の下の1行。押すと、その知らせまで戻る
    private func unansweredNoticeLine(_ card: NoticeCard, in days: [Timeline.Day]) -> some View {
        Button {
            viewport.landingRequested(.item(Timeline.Item.notice(card).id), in: days)
            Task { await capture(.unansweredNoticeLineTapped) }
        } label: {
            UnansweredNoticeLineLabel(text: "今日の体重がまだです") {
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.plain)
        .padding([.horizontal, .top])
        .accessibilityLabel("今日の体重がまだです")
        .accessibilityIdentifier("unanswered-notice-line")
    }

    private func composer() -> some View {
        TimelineComposer(
            weightRecordedToday: snapshot.weightRecordedToday,
            requiresSubscription: snapshot.requiresSubscription,
            expandsGoalSetup: goalSetupFlow.expandedPage != nil,
            preparingWeightEntry: navigation.presentation == .weightEntry(.preparing),
            showsCameraNotice: navigation.showsCameraNotice,
            initialDraft: TextDraft.empty,
            onCapture: { send(.cameraTapped) },
            onPickPhotos: {
                switch mealActions.photoSelection {
                case .picker:
                    send(.photoPickerTapped)
                #if DEBUG
                    case .fixed(let photoCount, let record):
                        send(.composerTapped)
                        let pickedAt = now()
                        showPickedPhotosLoadingWhileRecording(count: photoCount) {
                            await record(pickedAt)
                        }
                #endif
                }
            },
            onWeight: { send(.weightEntryTapped) },
            onPresetTapped: { preset in
                send(.composerTapped)
                Task { await capture(.presetTapped(preset)) }
            },
            onSendText: { draft in
                send(.composerTapped)
                Task { await performEdit(.sendText(draft)) }
            },
            onOpenPaywall: { send(.paywallRequested(.composerChip)) }
        )
    }

    /// サブスクリプション切れのあいだは、返事を作り直す操作を出さない
    private func replyRegeneration(of bubble: SentTextBubble) -> SentTextBubbleView.Regeneration {
        if snapshot.requiresSubscription {
            return .unavailable
        }
        return .available(
            resend: { reason in
                viewport.textResent()
                Task {
                    await performEdit(.resendReply(sentTextId: bubble.sentText.id, reason: reason))
                }
            },
            resendAsConversation: {
                viewport.textResent()
                Task {
                    await performEdit(
                        .resendAsConversation(
                            sentTextId: bubble.sentText.id,
                            deletedMealCount: bubble.meals.count))
                }
            })
    }

    private func perform(
        _ instructions: [TimelineViewport.Instruction], with proxy: ScrollViewProxy
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
            case .closeDaySummary:
                send(.daySummaryClosed)
            }
        }
    }

    private func scroll(to target: TimelineViewport.ScrollTarget, with proxy: ScrollViewProxy) {
        switch target {
        case .end: proxy.scrollTo(Self.contentId, anchor: .bottom)
        case .day(let day): proxy.scrollTo(day, anchor: .top)
        case .item(let itemId): proxy.scrollTo(itemId, anchor: .top)
        case .goalSetupNoticeBottom(let itemId):
            // カードの日が並ぶのを待つあいだに、目標の設定を閉じた・カードが変わったら送らない
            guard goalSetupFlow.expandedPage != nil,
                let notice = snapshot.timeline?.goalSetupNotice,
                Timeline.Item.goalSetupNotice(notice).id == itemId
            else { return }
            proxy.scrollTo(itemId, anchor: .bottom)
        }
    }

    /// 書く欄と知らせの中の欄のどちらにカーソルがあっても下げる
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// 目標の設定を広げているあいだのページ。変わったら、カードの下端まで送る
    private var goalSetupScrollKey: GoalSetupScrollKey {
        GoalSetupScrollKey(
            requests: goalSetupScrollRequests,
            page: goalSetupFlow.expandedPage)
    }

    /// 選ぶ画面が閉じたらすぐ仮のカードを出し、遡っていても一番下へ連れていく。記録し終えたら（食事のカードがキャッシュに入ったら）外す
    private func showPickedPhotosLoadingWhileRecording(
        count: Int, record: @escaping () async -> Void
    ) {
        let loading = PickedPhotosLoading(photoCount: count)
        loadingPickedPhotos.append(loading)
        viewport.pickedPhotosLoadingStarted()
        Task {
            await record()
            loadingPickedPhotos.removeAll { $0.id == loading.id }
        }
    }

    /// 立て直す流れを知らせのボタン（と日のまとめ）から広げているあいだ、タイムラインの一番下に出す目標の設定のカード。
    /// 目標がないあいだは、目標を立てる知らせのカードがその場で広がるので出さない。目標の画面から広げたときは目標の画面にだけ描く
    @ViewBuilder private var restartGoalSetupCard: some View {
        if snapshot.currentGoal != nil, case .expanded(let content, let actions) = goalSetupFlow {
            GoalSetupFlowCard(content: content, actions: actions, timeZone: timeZone)
                .padding(.top, 24)
                .transition(.opacity)
        }
    }

    /// 日のまとめのシート。帯の日を押すと出す
    private func daySummarySheet(on day: CalendarDay, loaded: Timeline) -> some View {
        let startGoalSetup: (() -> Void)? =
            snapshot.offersGoalSetup ? { send(.goalSetupRequested(.daySummary)) } : nil
        return DaySummarySheet(
            timeline: loaded, day: day, weightRecords: snapshot.weightRecords,
            weightTrend: snapshot.weightTrend, goalRecords: snapshot.goalRecords,
            today: snapshot.today,
            startGoalSetup: startGoalSetup,
            weekRecapTitle: { snapshot.weekRecap(monday: $0.startOfWeek)?.title },
            openWeightScreen: { send(.weightScreenRequested($0)) },
            openGoalScreen: { send(.goalScreenRequested(.daySummary)) },
            openWeeklyReview: { send(.weeklyReviewRequested(weekOf: $0, .daySummary)) },
            openNextGoal: { nextGoal in
                switch nextGoal {
                case .choose: send(.goalSetupRequested(.chooseNextGoal))
                case .set: send(.goalSetupRequested(.setNextGoal))
                }
            },
            onSeeOnTimeline: { chosen in
                send(.daySummaryClosed)
                viewport.dayChosen(chosen, in: loaded.days)
            })
    }

    @ViewBuilder private func destination(_ route: TimelineNavigation.Route) -> some View {
        switch route {
        case .weightScreen(let day):
            weightScreen(on: day)
        case .weightHistory:
            WeightHistoryScreen(rows: snapshot.weightHistory)
        case .meal(let mealId):
            mealScreen(mealId: mealId)
        case .dish(let mealId, let dishId):
            dishScreen(mealId: mealId, dishId: dishId)
        case .goalScreen(let entry):
            GoalScreen(
                overview: snapshot.goalOverview, entry: entry,
                goalSetupFlow: goalScreenGoalSetupFlow,
                timeZone: timeZone, recapTitle: { snapshot.weekRecap(monday: $0)?.title },
                capture: capture,
                openGoalSetup: { entry in
                    Task { await openGoalSetupFlow(entry, .goalScreen) }
                },
                openWeeklyReview: { monday in
                    send(.weeklyReviewRequested(weekOf: monday, .goalScreen))
                })
        case .weeklyReview(let monday, let entry):
            WeeklyReviewScreen(
                monday: monday, entry: entry, recap: snapshot.weekRecap(monday:),
                capture: capture
            ) { day in
                send(.returnedToTimeline)
                if let timeline = snapshot.timeline {
                    viewport.dayChosen(day, in: timeline.days)
                }
            }
        }
    }

    /// 食事の画面。タイムラインの食事のカードと、返事が指す食事から潜る
    private func mealScreen(mealId: UUID) -> some View {
        MealDestination(card: snapshot.mealCard(id: mealId)) { card in
            MealScreen(
                card: card,
                now: now,
                capture: capture,
                actions: mealActions,
                performEdit: performEdit,
                returnToTimeline: {
                    send(.returnedToTimeline)
                },
                openPaywall: { send(.paywallRequested(.awaitingMeal)) },
                rejectedLines: snapshot.rejectedLines,
                confirmsDeletion: false,
                confirmsLastDishDeletion: false,
                addingDish: false,
                sentText: snapshot.sentText(of: card)
            )
        }
    }

    /// 料理の画面。食事の画面の料理の行から潜る
    private func dishScreen(mealId: UUID, dishId: UUID) -> some View {
        let card = snapshot.mealCard(id: mealId)
        return DishDestination(
            offer: card.flatMap {
                MealEditOffer(card: $0).dishScreen(
                    dishId: dishId, rejectedLines: snapshot.rejectedLines)
            }
        ) { offer in
            DishScreen(
                offer: offer,
                performEdit: performEdit,
                deleteMeal: {
                    if let card {
                        deleteMealAndReturn(card)
                    }
                },
                confirmsMealDeletion: false)
        }
    }

    /// 消すとタイムラインに戻る。戻る途中でカードと1日の丸からその分が減る
    private func deleteMealAndReturn(_ card: MealCard) {
        let deletedAt = now()
        send(.returnedToTimeline)
        Task { await performEdit(.deleteMeal(card, deletedAt: deletedAt)) }
    }

    /// 体重の画面。タイムラインの体重のカードと、日のまとめの体重の行から潜る
    private func weightScreen(on day: CalendarDay) -> some View {
        let startGoalSetup: (() -> Void)? =
            snapshot.offersGoalSetup ? { send(.goalSetupRequested(.weightScreen)) } : nil
        return WeightScreen(
            day: day,
            records: snapshot.weightRecords,
            firstDay: snapshot.firstDay,
            trendChart: snapshot.weightTrendChart,
            rejectedLines: snapshot.rejectedLines,
            capture: capture,
            performEdit: performEdit,
            startGoalSetup: startGoalSetup,
            goalPath: snapshot.weightGoalPath,
            // 体重の画面の上に積むので、戻るは「‹ 体重」
            openGoalScreen: { send(.goalScreenRequested(.weightScreen)) }
        )
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

/// 帯の下の1行のカプセル。左に知らせの文、右に押すと何が起きるかの印
private struct UnansweredNoticeLineLabel<Action: View>: View {
    let text: String
    @ViewBuilder let action: Action

    var body: some View {
        HStack(spacing: 12) {
            Text(text)
                .foregroundStyle(.primary)
            Spacer()
            action
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
}

private struct GoalSetupScrollKey: Equatable {
    let requests: Int
    /// 広げていなければ nil
    let page: GoalSetupPage?
}

/// 1回の選ぶ画面で選んだ写真を、読んで記録し終えるまで
private struct PickedPhotosLoading: Identifiable {
    let id = UUID()
    let photoCount: Int
}
