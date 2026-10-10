// モデルがテキストを流して答えるときの応答（text/event-stream）。chunks を1つずつ text_delta で流し、ending で終える。
// - stop: stop_reason と使ったトークンを送って閉じる
// - error: 流している途中でエラーの出来事を送る
// - cut: 終わりの出来事を送らずに閉じる
// - hang: 閉じずに待ち、要求の signal が切れたら本文の読み出しを失敗させる（本物の fetch と同じ）
export const replyWithTextStream = (
  chunks: readonly string[],
  ending: TextStreamEnding,
  signal: AbortSignal | undefined,
): Response => {
  const encoder = new TextEncoder();
  const events = [
    sse("message_start", {
      type: "message_start",
      message: {
        id: "msg_test",
        type: "message",
        role: "assistant",
        model: "claude-sonnet-5-5",
        content: [],
        stop_reason: null,
        stop_sequence: null,
        usage: {
          input_tokens: ending.type === "stop" ? ending.usage.input_tokens : 2400,
          output_tokens: 1,
        },
      },
    }),
    sse("content_block_start", {
      type: "content_block_start",
      index: 0,
      content_block: { type: "text", text: "" },
    }),
    ...chunks.map((text) =>
      sse("content_block_delta", {
        type: "content_block_delta",
        index: 0,
        delta: { type: "text_delta", text },
      }),
    ),
    ...toEndingEvents(ending),
  ];
  const body = new ReadableStream<Uint8Array>({
    start: (controller) => {
      for (const event of events) {
        controller.enqueue(encoder.encode(event));
      }
      if (ending.type === "hang") {
        signal?.addEventListener("abort", () =>
          controller.error(new DOMException("aborted", "AbortError")),
        );
        return;
      }
      controller.close();
    },
  });
  return new Response(body, { headers: { "content-type": "text/event-stream" } });
};

export type TextStreamEnding =
  | {
      type: "stop";
      stopReason: "end_turn" | "max_tokens" | "refusal";
      usage: { input_tokens: number; output_tokens: number };
    }
  | { type: "error"; errorType: string }
  | { type: "cut" }
  | { type: "hang" };

const toEndingEvents = (ending: TextStreamEnding): string[] => {
  if (ending.type === "stop") {
    return [
      sse("content_block_stop", { type: "content_block_stop", index: 0 }),
      sse("message_delta", {
        type: "message_delta",
        delta: { stop_reason: ending.stopReason, stop_sequence: null },
        usage: { output_tokens: ending.usage.output_tokens },
      }),
      sse("message_stop", { type: "message_stop" }),
    ];
  }
  if (ending.type === "error") {
    return [
      sse("error", { type: "error", error: { type: ending.errorType, message: "stream failed" } }),
    ];
  }
  return [];
};

const sse = (event: string, data: unknown): string =>
  `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
