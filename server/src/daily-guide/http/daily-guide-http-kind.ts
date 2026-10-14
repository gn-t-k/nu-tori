import { z } from "@hono/zod-openapi";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import { type DailyGuide, dailyGuideLimitTypes } from "../domain/daily-guide";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
const dailyGuideRecordSchema = z
  .object({
    id: z.string(),
    goalId: z.string().openapi({
      description: "目標の ID。目標の変更より先に届くことがある",
    }),
    expenditureEstimateId: z.string().openapi({
      description: "計算に使った推定消費カロリーの推定の ID。推定の変更より先に届くことがある",
    }),
    effectiveOn: z.string().openapi({
      description: "当てる始まりの日（YYYY-MM-DD）",
      example: "2026-10-01",
    }),
    energyKcal: z.number().int(),
    proteinG: z.number().int(),
    fatG: z.number().int(),
    carbohydrateG: z.number().int(),
    limitHits: z.array(z.enum(dailyGuideLimitTypes)).openapi({
      description:
        "当たった上限と下限。当たったものだけが並ぶ。1週の変化（weekly_change）、必要な速さの上限（required_pace）、下限のエネルギー（minimum_energy）",
    }),
  })
  .openapi({
    description: "kind が daily_guide の変更の record。1日の目安は消えない",
  });

export const dailyGuideHttpKind: HttpRecordKind<DailyGuide, never, typeof dailyGuideRecordSchema> =
  {
    // サーバーだけが書く種類なので、端末からの書き込みは届かない
    writes: undefined,
    recordSchema: dailyGuideRecordSchema,
    toRecord: (value) => ({
      id: value.id,
      goalId: value.goalId,
      expenditureEstimateId: value.expenditureEstimateId,
      effectiveOn: value.effectiveOn,
      energyKcal: value.energyKcal,
      proteinG: value.proteinG,
      fatG: value.fatG,
      carbohydrateG: value.carbohydrateG,
      limitHits: value.limitHits,
    }),
  };
