import { z } from "@hono/zod-openapi";

// 見守る要求の出来事ごとの data（JSON）。アプリは生成したクライアントで、出来事の data をこの型で読む
export const replyStreamEventSchema = z
  .discriminatedUnion("type", [
    z
      .object({ type: z.literal("reply_started"), replyId: z.string() })
      .openapi("ReplyStartedEvent", {
        description:
          "返事の ID。返事の生成を始めたら最初に1度だけ送る。返事の記録（ai_utterance）の ID と同じで、試みをまたいで変わらない",
      }),
    z.object({ type: z.literal("text_delta"), text: z.string() }).openapi("TextDeltaEvent", {
      description:
        "返事の本文のできた分。届いた順につなぐ。試みの途中からつないだときは、返事の ID のすぐあとに、ここまでにできた分をまとめて1つで送る",
    }),
    z.object({ type: z.literal("text_discarded") }).openapi("TextDiscardedEvent", {
      description:
        "流している途中で試みが失敗した。それまでにつないだ分を捨てる。次の試みで初めから流し直す",
    }),
    z
      .object({ type: z.literal("replied"), replyId: z.string() })
      .openapi("RepliedEvent", { description: "返事を記録に書いた。送ったあと閉じる" }),
    z
      .object({ type: z.literal("classified_as_meal") })
      .openapi("ClassifiedAsMealEvent", { description: "食事と読み分けた。送ったあと閉じる" }),
    z.object({ type: z.literal("reply_halted") }).openapi("ReplyHaltedEvent", {
      description: "その日の返事の回数を使い切っていて、回数切れにした。送ったあと閉じる",
    }),
    z
      .object({
        type: z.literal("reply_failed"),
        failureReason: z.enum(["retries_exhausted", "bad_request"]),
      })
      .openapi("ReplyFailedEvent", {
        description: "返事を作れなかった（やり直しを使い切った・提供元の 400）。送ったあと閉じる",
      }),
  ])
  .openapi("ReplyStreamEvent", {
    description:
      "見守る要求の出来事。閉じたら、どの出来事で閉じたかによらず、同期の取りに行くで記録を受け取る",
  });
