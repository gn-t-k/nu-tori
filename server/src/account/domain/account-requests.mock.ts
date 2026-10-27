import { R } from "@praha/byethrow";
import { vi } from "vitest";
import { computeMaintenancePlan } from "../../goal/domain/compute-maintenance-plan";
import { evaluateCustomTargetWeight } from "../../goal/domain/evaluate-custom-target-weight";
import type { GoalSetupRequestRejectedError } from "../../goal/domain/goal-setup-request-rejected-error";
import { accountRequests } from "./account-requests";

// 出来事を返しうる入口を、記録を読み書きせずに答える偽物に差し替える。
// 出来事の既定は、写真を受け取れなかった出来事を1つ返す。
// 目標の設定の入口は、体重の傾向 65kg・推定消費カロリー 2200kcal の計算の元から出した答えで成功する
export const mockAccountRequestsOk = (overrides?: Partial<Answers>) => {
  const answers = { ...defaultAnswers(), ...overrides };
  return spyOnAccountRequests(answers.usageEvents, {
    previewGoalSetup: R.succeed(answers.goalSetupPreview),
    proposeGoals: R.succeed(answers.goalProposals),
    assessCustomTargetWeight: R.succeed(answers.customTargetWeightAssessment),
    decideGoal: R.succeed(answers.goalDecision),
  });
};

// 目標の設定の入口を、受け取ったエラーで失敗させる。ほかの入口は mockAccountRequestsOk と同じに答える
export const mockAccountRequestsError = (
  error: GoalSetupRequestRejectedError,
  overrides?: Partial<Pick<Answers, "usageEvents">>,
) =>
  spyOnAccountRequests(overrides?.usageEvents ?? defaultAnswers().usageEvents, {
    previewGoalSetup: R.fail(error),
    proposeGoals: R.fail(error),
    assessCustomTargetWeight: R.fail(error),
    decideGoal: R.fail(error),
  });

// どの入口の答えの型にも入る出来事。写真を受け取る入口の答えがいちばん狭い
type AnswerableUsageEvents = Awaited<
  ReturnType<typeof accountRequests.receiveMealPhoto>
>["usageEvents"];

type GoalSetupResults = {
  [
    Name in "previewGoalSetup" | "proposeGoals" | "assessCustomTargetWeight" | "decideGoal"
  ]: ReturnType<(typeof accountRequests)[Name]>["result"];
};

type Answers = {
  usageEvents: AnswerableUsageEvents;
  goalSetupPreview: R.InferSuccess<GoalSetupResults["previewGoalSetup"]>;
  goalProposals: R.InferSuccess<GoalSetupResults["proposeGoals"]>;
  customTargetWeightAssessment: R.InferSuccess<GoalSetupResults["assessCustomTargetWeight"]>;
  goalDecision: R.InferSuccess<GoalSetupResults["decideGoal"]>;
};

const defaultAnswers = (): Answers => {
  const startedOn = "2026-10-21";
  const startingWeightTrend = { trendKg: 65, lastWeightRecordedOn: "2026-10-20" };
  const expenditure = { source: "back_calculated", kcal: 2200 } as const;
  const goalProposals = {
    startedOn,
    startingWeightTrend,
    expenditure,
    plan: {
      direction: "maintain",
      maintenance: computeMaintenancePlan({
        expenditureKcal: expenditure.kcal,
        startingWeightTrendKg: startingWeightTrend.trendKg,
      }),
    },
  } as const;
  return {
    usageEvents: [{ name: "meal_photo_receipt_failed", stage: "put_file" }],
    goalSetupPreview: { canBackCalculate: true, canOfferLoseProposals: true },
    goalProposals,
    customTargetWeightAssessment: {
      startedOn,
      evaluation: evaluateCustomTargetWeight({
        direction: "lose",
        expenditureKcal: expenditure.kcal,
        startingWeightTrendKg: startingWeightTrend.trendKg,
        daysFromStartToDeadline: 72,
        targetWeightKg: 63,
      }),
    },
    // 決めた記録を作らずに済むよう、決めずに新しい案を返す答えにしている
    goalDecision: { status: "recalculated", proposals: goalProposals },
  };
};

const spyOnAccountRequests = (
  usageEvents: AnswerableUsageEvents,
  goalSetupResults: GoalSetupResults,
) => {
  const requestLog = { reviewedWeekCount: 0 };
  return {
    pushSyncWrites: vi
      .spyOn(accountRequests, "pushSyncWrites")
      .mockReturnValue({ result: [], usageEvents, requestLog }),
    pullSyncChanges: vi.spyOn(accountRequests, "pullSyncChanges").mockReturnValue({
      result: { changes: [], hasMore: false, nextAfterSequence: 0, startedOn: undefined },
      usageEvents,
      requestLog,
    }),
    receiveMealPhoto: vi
      .spyOn(accountRequests, "receiveMealPhoto")
      .mockResolvedValue({ result: R.succeed(undefined), usageEvents }),
    previewGoalSetup: vi.spyOn(accountRequests, "previewGoalSetup").mockReturnValue({
      result: goalSetupResults.previewGoalSetup,
      usageEvents,
      requestLog,
    }),
    proposeGoals: vi.spyOn(accountRequests, "proposeGoals").mockReturnValue({
      result: goalSetupResults.proposeGoals,
      usageEvents,
      requestLog,
    }),
    assessCustomTargetWeight: vi
      .spyOn(accountRequests, "assessCustomTargetWeight")
      .mockReturnValue({
        result: goalSetupResults.assessCustomTargetWeight,
        usageEvents,
        requestLog,
      }),
    decideGoal: vi.spyOn(accountRequests, "decideGoal").mockReturnValue({
      result: goalSetupResults.decideGoal,
      usageEvents,
      requestLog,
    }),
    reportSubscriptionTransaction: vi
      .spyOn(accountRequests, "reportSubscriptionTransaction")
      .mockReturnValue({ result: [], usageEvents }),
    receiveAppStoreServerNotification: vi
      .spyOn(accountRequests, "receiveAppStoreServerNotification")
      .mockReturnValue({ result: "duplicate", usageEvents }),
    runAlarm: vi.spyOn(accountRequests, "runAlarm").mockResolvedValue({
      result: {
        error: undefined,
        providerErrors: [],
        classifications: [],
        attempts: [],
        replyAttempts: [],
        nextAlarmAt: undefined,
      },
      usageEvents,
    }),
  };
};
