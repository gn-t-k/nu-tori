import type { RecordId } from "../../domain/record-id";
import { readReplyWatchState, type ReplyWatchState } from "./read-reply-watch-state";
import type { ReplyStreamEvent } from "./reply-stream-event";

// 見守る要求の先。send と close は投げない（切れた端末に送っても、返事を作り続けるため）
export type ReplyWatchChannel = {
  send: (event: ReplyStreamEvent) => void;
  close: () => void;
};

export type ReplyWatchers = ReturnType<typeof createReplyWatchers>;

// つないでいる見守る要求と、試みが流している途中の文をメモリに持つ。Durable Object の実体ごとに1つ作り、
// 受け口の要求とアラームが同じものを使う。途中の文は記録に残さない（#419 の「返事を作る」の保存するもの）
export const createReplyWatchers = () => {
  const watchers = new Set<Watcher>();
  const partialTexts = new Map<RecordId, string>();

  // 結果なら送って閉じ、待っているなら、まだ送っていない返事の ID を送る
  const apply = (watcher: Watcher, state: Exclude<ReplyWatchState, { type: "absent" }>) => {
    if (state.type === "ended") {
      watchers.delete(watcher);
      watcher.channel.send(state.ending);
      watcher.channel.close();
      return;
    }
    if (state.replyId === undefined || watcher.announcedReplyId !== undefined) {
      return;
    }
    watcher.announcedReplyId = state.replyId;
    watcher.channel.send({ type: "reply_started", replyId: state.replyId });
    const partialText = partialTexts.get(watcher.sentTextId);
    if (partialText !== undefined) {
      watcher.channel.send({ type: "text_delta", text: partialText });
    }
  };

  const watchersOf = (sentTextId: RecordId) =>
    [...watchers].filter((watcher) => watcher.sentTextId === sentTextId);

  return {
    // 今の状態を読んだ直後に呼ぶ（あいだに await を挟まない）。試みの途中なら、ここまでにできた分をまとめて送る。
    // 返すのは、端末が切れたときに呼ぶ見守りの外し方
    watch: (
      sentTextId: RecordId,
      state: Exclude<ReplyWatchState, { type: "absent" }>,
      channel: ReplyWatchChannel,
    ): (() => void) => {
      const watcher: Watcher = { sentTextId, announcedReplyId: undefined, channel };
      watchers.add(watcher);
      apply(watcher, state);
      return () => {
        watchers.delete(watcher);
      };
    },
    // 読み分け・生成の開始・試みの結果を書いたあとに呼び、つないでいる文章の今を読み直して送る
    refresh: (stores: Parameters<typeof readReplyWatchState>[0]) => {
      for (const watcher of watchers) {
        const state = readReplyWatchState(stores, watcher.sentTextId);
        if (state.type === "absent") {
          // 記録を消したアカウント
          watchers.delete(watcher);
          watcher.channel.close();
          continue;
        }
        apply(watcher, state);
      }
    },
    // 提供元ができた分を返すたびに呼ぶ
    appendText: (sentTextId: RecordId, text: string) => {
      partialTexts.set(sentTextId, (partialTexts.get(sentTextId) ?? "") + text);
      for (const watcher of watchersOf(sentTextId)) {
        watcher.channel.send({ type: "text_delta", text });
      }
    },
    // 試みが終わったら、結果を書く前に呼ぶ。通らなかった試みが流していれば、流した分を捨てる知らせを送る
    endAttempt: (sentTextId: RecordId, succeeded: boolean) => {
      const streamed = partialTexts.delete(sentTextId);
      if (succeeded || !streamed) {
        return;
      }
      for (const watcher of watchersOf(sentTextId)) {
        watcher.channel.send({ type: "text_discarded" });
      }
    },
  };
};

type Watcher = {
  sentTextId: RecordId;
  // 送った返事の ID。送るのは1度だけ
  announcedReplyId: RecordId | undefined;
  channel: ReplyWatchChannel;
};
