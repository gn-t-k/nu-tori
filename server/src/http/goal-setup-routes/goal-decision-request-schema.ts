import { z } from "@hono/zod-openapi";
import { recordIdSchema } from "../../domain/record-id";
import type { GoalDecisionRequest } from "../../goal/domain/decide-goal";
import { dailyGuidePlanSchema } from "./daily-guide-plan-schema";
import {
  calendarDaySchema,
  goalSetupSituationSchema,
  toGoalSetupSituation,
} from "./goal-setup-situation-schema";

const weightChangeDirectionSchema = z.enum(["lose", "gain"]);

const deadlineOnSchema = calendarDaySchema.openapi({
  description: "期限。開始の日から数えて（両端を含む）28〜182 日の日",
});

// 目標を決める要求。摂取エネルギーと身体データは、初めての目標のときに、目標案の要求と同じものを添える
export const goalDecisionRequestSchema = goalSetupSituationSchema.extend({
  requestId: recordIdSchema.openapi({
    description:
      "端末が振った要求の ID（UUID v4）。冪等の鍵。同じ ID の再送は、書かずに初めての応答と同じ形で返す",
  }),
  startedOn: calendarDaySchema.openapi({
    description: "目標案の応答で受け取った開始の日。サーバーが出し直した開始の日と違えば、決めない",
  }),
  choice: z
    .discriminatedUnion("type", [
      z.object({ type: z.literal("maintain") }).openapi("GoalMaintainChoice"),
      z
        .object({
          type: z.literal("proposal"),
          direction: weightChangeDirectionSchema,
          deadlineOn: deadlineOnSchema,
          pace: z.enum(["gentle", "standard", "hard"]),
        })
        .openapi("GoalProposalChoice"),
      z
        .object({
          type: z.literal("custom"),
          direction: weightChangeDirectionSchema,
          deadlineOn: deadlineOnSchema,
          targetWeightKg: z.number().positive().openapi({
            description: "自分で決めた目標体重。0.1 kg 単位に丸めて確かめる",
          }),
        })
        .openapi("GoalCustomChoice"),
    ])
    .openapi("GoalChoice", {
      description:
        "選んだもの。維持（maintain）、ゆるめ・標準・ハードの案（proposal）、自分で決めた目標体重（custom）",
    }),
  shown: z
    .object({
      targetWeightKg: z.number().openapi({
        description: "見せていた目標体重。自分で決めた目標体重のときは、その目標体重",
      }),
      dailyGuide: dailyGuidePlanSchema,
    })
    .openapi("GoalShownValues", {
      description:
        "端末が見せていた値。サーバーがそのときの体重の傾向で計算し直した値と違えば、決めない",
    }),
  rejectedCustomTargetWeightCount: z.number().int().nonnegative().openapi({
    description: "この目標の設定のあいだに、端末が端の値に直した自分の目標体重の数。観測に使う",
  }),
});

export const toGoalDecisionRequest = ({
  requestId,
  startedOn,
  choice,
  shown,
  rejectedCustomTargetWeightCount,
  ...situation
}: z.infer<typeof goalDecisionRequestSchema>): GoalDecisionRequest => ({
  ...toGoalSetupSituation(situation),
  requestId,
  startedOn,
  choice,
  shown,
  rejectedCustomTargetWeightCount,
});
