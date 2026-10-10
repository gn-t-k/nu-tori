import type { RecordId } from "../../domain/record-id";
import type { ReplyWatchers } from "../domain/create-reply-watchers";
import { readReplyWatchState } from "../domain/read-reply-watch-state";
import type { ReplyStreamEvent } from "../domain/reply-stream-event";

// 見守る要求の流れ。出来事ごとに `data: <JSON>` の SSE のかたまりにして流す（RPC で返せるのはバイトの流れだけなので、
// Durable Object の中で SSE にし、受け口の Worker はそのまま text/event-stream で返す。#69 で確かめた形）。
// 送った文章が無ければ undefined。端末が切れたら見守りを外す。返事はアラームが作り続けて記録に書く
export const createReplyStream = (
  watchers: ReplyWatchers,
  stores: Parameters<typeof readReplyWatchState>[0],
  sentTextId: RecordId,
): ReadableStream<Uint8Array> | undefined => {
  const state = readReplyWatchState(stores, sentTextId);
  if (state.type === "absent") {
    return undefined;
  }
  const encoder = new TextEncoder();
  // start の中で見守りを付けるまでは、外すものが無い
  let unwatch: (() => void) | undefined = undefined;
  return new ReadableStream<Uint8Array>({
    start: (controller) => {
      // 切れた端末への送りが投げても、アラームの返事の生成を止めない
      unwatch = watchers.watch(sentTextId, state, {
        send: (event: ReplyStreamEvent) => {
          try {
            controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
          } catch {
            unwatch?.();
          }
        },
        close: () => {
          try {
            controller.close();
          } catch {
            unwatch?.();
          }
        },
      });
    },
    cancel: () => {
      unwatch?.();
    },
  });
};
