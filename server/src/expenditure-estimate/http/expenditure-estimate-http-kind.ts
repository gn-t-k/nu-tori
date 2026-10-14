import { z } from "@hono/zod-openapi";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import {
  type ExpenditureEstimate,
  initialExpenditureSources,
} from "../domain/expenditure-estimate";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
const expenditureEstimateRecordSchema = z
  .object({
    id: z.string(),
    effectiveOn: z.string().openapi({
      description: "当てる始まりの日（YYYY-MM-DD）",
      example: "2026-10-01",
    }),
    expenditureKcal: z.number().int().openapi({ description: "推定消費カロリー（1日の kcal）" }),
    estimatedAt: z.number().int().openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
    initialSource: z.enum(initialExpenditureSources).optional().openapi({
      description:
        "推定の始まり（初めて目標を立てたときの推定）だけに付く出どころ。逆算（back_calculated）か式（formula）",
    }),
  })
  .openapi({
    description: "kind が expenditure_estimate の変更の record。推定は消えない",
  });

export const expenditureEstimateHttpKind: HttpRecordKind<
  ExpenditureEstimate,
  never,
  typeof expenditureEstimateRecordSchema
> = {
  // サーバーだけが書く種類なので、端末からの書き込みは届かない
  writes: undefined,
  recordSchema: expenditureEstimateRecordSchema,
  toRecord: (value) => ({
    id: value.id,
    effectiveOn: value.effectiveOn,
    expenditureKcal: value.expenditureKcal,
    estimatedAt: value.estimatedAt.getTime(),
    initialSource: value.initialSource,
  }),
};
