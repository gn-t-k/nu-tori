import { z } from "@hono/zod-openapi";
import { isCalendarDay } from "../../domain/is-calendar-day";
import type { GoalSetupSituation } from "../../goal/domain/goal-setup-situation";

// 初期値の窓は 28 日。端末とサーバーで今日がずれても入るよう、少し広く受ける
const maximumDailyValues = 31;

export const calendarDaySchema = z
  .string()
  .refine(isCalendarDay)
  .openapi({ description: "YYYY-MM-DD", example: "2026-10-14" });

const bodyDataSchema = z
  .object({
    sex: z.enum(["male", "female"]),
    heightCentimeters: z.number(),
    ageYears: z.number().int().openapi({
      description: "生年月日か、手で入れた生まれた年から、端末が出した歳",
    }),
    activity: z
      .discriminatedUnion("type", [
        z
          .object({
            type: z.literal("steps"),
            dailySteps: z
              .array(
                z.object({ calendarDay: calendarDaySchema, steps: z.number().int().nonnegative() }),
              )
              .max(maximumDailyValues)
              .openapi({ description: "初期値の窓（今日を除く直前の 28 日）の、日ごとの歩数" }),
          })
          .openapi("GoalSetupStepsActivity"),
        z
          .object({
            type: z.literal("level"),
            level: z.enum(["sedentary", "standing", "active"]).openapi({
              description: "ほぼ座り仕事・立ち仕事が多い・よく動く。歩数が読めなかった人が選ぶ",
            }),
          })
          .openapi("GoalSetupLevelActivity"),
      ])
      .openapi("GoalSetupActivity"),
  })
  .openapi("GoalSetupBodyData");

// 目標の設定の要求がどれも載せる値。サーバーは、摂取エネルギーと身体データを計算に使ったら捨てる
export const goalSetupSituationSchema = z.object({
  timeZone: z.string().min(1).openapi({
    description: "端末の今のタイムゾーン（IANA 名）。開始の日を決める",
    example: "Asia/Tokyo",
  }),
  preUseEnergyIntakes: z
    .array(z.object({ calendarDay: calendarDaySchema, kcal: z.number().nonnegative() }))
    .max(maximumDailyValues)
    .optional()
    .openapi({
      description:
        "初めての目標のときに添える。ヘルスケアから読んだ、使い始める前の日ごとの摂取エネルギー（初期値の窓に入る日だけ）。保存しない",
    }),
  bodyData: bodyDataSchema.optional().openapi({
    description:
      "初めての目標で、下見が逆算できないと答えた人が、そのあとの要求に添える。保存しない",
  }),
});

export const toGoalSetupSituation = ({
  timeZone,
  preUseEnergyIntakes,
  bodyData,
}: z.infer<typeof goalSetupSituationSchema>): GoalSetupSituation => ({
  timeZone,
  preUseEnergyIntakes: preUseEnergyIntakes ?? [],
  bodyData,
});
