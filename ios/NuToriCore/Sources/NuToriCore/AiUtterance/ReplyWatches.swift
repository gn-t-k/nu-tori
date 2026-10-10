public import Foundation
public import NuToriAPI

/// 応答を待つ送った文章ごとに、見守る要求をつなぐ。受け取っている途中の返事を知らせ、閉じたら知らせる。
/// 届け方の正本は同期なので、閉じたら（理由によらず）呼び出し側が取りに行き、届いた返事が同じ ID の途中の返事を置き換える
public actor ReplyWatches {
    /// - Parameters:
    ///   - watch: 見守る要求につなぐ（`NuToriAPIClient.watchReply(sentTextId:)`）
    ///   - onStreams: 送った文章の ID ごとの途中の返事が変わったら、全部を知らせる。タイムラインの `Timeline.Conversation.streams` に渡す
    ///   - onClosed: 見守る要求が閉じた（つながらなかったときも）。取りに行き、終えたら `follow(awaiting:)` を呼び直す
    public init(
        watch: @escaping @Sendable (UUID) async throws -> NuToriAPIClient.WatchReplyResult,
        onStreams: @escaping @Sendable ([UUID: ReplyStream]) async -> Void,
        onClosed: @escaping @Sendable () async -> Void
    ) {
        self.watch = watch
        self.onStreams = onStreams
        self.onClosed = onClosed
    }

    /// 見守る要求がつながっている送った文章。この文章のためには、数秒おきに取りに行かない（`ReplyFollowUp`）
    public var connectedSentTextIds: Set<UUID> {
        Set(tasks.keys)
    }

    /// 応答を待つ送った文章（`SyncEngine.sentTextsAwaitingResponse()`）を渡す。同期を終えるたびと、前面に戻ったときに呼ぶ。
    /// まだつないでいない文章をつなぎ、応答を待たなくなった文章の途中の返事を捨てる。
    /// 結果を受け取って閉じた文章と、つながらなかった文章は、`stopAll()` までつなぎ直さない（取りに行くで受け取る）
    public func follow(awaiting sentTextIds: Set<UUID>) async {
        let settledStreams = streams.keys.filter {
            !sentTextIds.contains($0) && tasks[$0] == nil
        }
        if !settledStreams.isEmpty {
            for sentTextId in settledStreams {
                streams[sentTextId] = nil
            }
            await onStreams(streams)
        }
        for sentTextId in sentTextIds
        where tasks[sentTextId] == nil && !givenUp.contains(sentTextId) {
            tasks[sentTextId] = Task { await self.run(sentTextId) }
        }
    }

    /// 裏へ回ったとき・サインアウトしたときに、すべて切り、途中の返事を捨てる。前面に戻ったら `follow(awaiting:)` でつなぎ直す
    public func stopAll() async {
        for task in tasks.values {
            task.cancel()
        }
        tasks = [:]
        givenUp = []
        if !streams.isEmpty {
            streams = [:]
            await onStreams(streams)
        }
    }

    private let watch: @Sendable (UUID) async throws -> NuToriAPIClient.WatchReplyResult
    private let onStreams: @Sendable ([UUID: ReplyStream]) async -> Void
    private let onClosed: @Sendable () async -> Void
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var streams: [UUID: ReplyStream] = [:]
    /// 結果を受け取って閉じた・つながらなかった文章。つなぎ直さない
    private var givenUp: Set<UUID> = []

    private func run(_ sentTextId: UUID) async {
        let ending = await receive(sentTextId)
        guard !Task.isCancelled else { return }
        tasks[sentTextId] = nil
        switch ending {
        case .outcome, .failed:
            givenUp.insert(sentTextId)
        case .closedEarly:
            // 流れの途中で切れた（前段が長い無音で切った、など）。まだ応答を待っていれば、次の `follow` でつなぎ直す
            break
        }
        await onClosed()
    }

    private enum Ending {
        case outcome
        case closedEarly
        case failed
    }

    private func receive(_ sentTextId: UUID) async -> Ending {
        guard case .watching(let events) = try? await watch(sentTextId) else { return .failed }
        do {
            for try await event in events {
                guard !Task.isCancelled else { return .closedEarly }
                var stream = streams[sentTextId] ?? ReplyStream()
                stream.receive(event)
                if streams[sentTextId] != stream {
                    streams[sentTextId] = stream
                    await onStreams(streams)
                }
                if event.isOutcome { return .outcome }
            }
            return .closedEarly
        } catch {
            return .failed
        }
    }
}
