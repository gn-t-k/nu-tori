import { classificationCriteria } from "../../src/reply/durable-object/create-conversation-provider/classification-criteria";

// 評価で比べる Jev（Workers AI の typesafe/jev）に渡す入力。#423 で Haiku 5.5 に決め、サーバーは Jev を呼ばないので評価の側に置く。
// 食事かを noul（真である確からしさ）の問い1つで尋ね、
// 答えの answers.is_meal.noul をしきい値と比べる（読み方は jevClassificationResponseSchema）。
// 呼ぶときは必ず環境ごとの AI Gateway を名指す（名指さないと、ログがオンの default のゲートウェイができる）
export const createJevClassificationInput = (body: string) => ({
  state: body,
  questions: {
    is_meal: {
      type: "noul",
      instructions: "この文章は、食事の記録として残すべき、食べた・飲んだものを伝えているか",
      criteria: { true: classificationCriteria.meal, false: classificationCriteria.conversation },
    },
  },
});
