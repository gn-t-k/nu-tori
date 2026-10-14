import { z } from "@hono/zod-openapi";

// 目標の下見の応答。どちらの答えも付くかは場合で決まるが、送る JSON に場合を見分ける値が無いので、省略できる欄のまま書く
export const goalSetupPreviewSchema = z
  .object({
    canBackCalculate: z.boolean().optional().openapi({
      description:
        "初めての目標のときだけ付く。推定消費カロリーを記録から逆算できるか。false なら、身体データを添えてもう一度下見を求める",
    }),
    canOfferLoseProposals: z.boolean().optional().openapi({
      description:
        "減量で、推定消費カロリーと体重の傾向を出せたときだけ付く。減量の目標案を1つでも出せるか。受け付けるいちばん短い期限（開始の日から 28 日）で確かめるので、true ならどの期限でも出せる",
    }),
  })
  .openapi("GoalSetupPreview");
