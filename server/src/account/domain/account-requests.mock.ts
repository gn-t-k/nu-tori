import { R } from "@praha/byethrow";
import { vi } from "vitest";
import type { UsageEvent } from "../../domain/usage-event";
import { GoalSetupRequestRejectedError } from "../../goal/domain/goal-setup-request-rejected-error";
import { accountRequests } from "./account-requests";

// 出来事を返しうる入口を、記録を読み書きせずに、写真を受け取れなかった出来事を1つ返す答えに差し替える。
// どの入口の答えの型にも入る出来事にしている
export const mockAccountRequestsOk = () => {
  const usageEvents = [
    { name: "meal_photo_receipt_failed", stage: "put_file" } satisfies UsageEvent,
  ];
  const requestLog = { reviewedWeekCount: 0 };
  return {
    pushSyncWrites: vi
      .spyOn(accountRequests, "pushSyncWrites")
      .mockReturnValue({ result: [], nextAlarmAt: undefined, usageEvents, requestLog }),
    pullSyncChanges: vi.spyOn(accountRequests, "pullSyncChanges").mockReturnValue({
      result: { changes: [], hasMore: false, nextAfterSequence: 0, startedOn: undefined },
      nextAlarmAt: undefined,
      usageEvents,
      requestLog,
    }),
    receiveMealPhoto: vi
      .spyOn(accountRequests, "receiveMealPhoto")
      .mockResolvedValue({ result: R.succeed(undefined), nextAlarmAt: undefined, usageEvents }),
    previewGoalSetup: vi.spyOn(accountRequests, "previewGoalSetup").mockReturnValue({
      result: goalSetupRejected(),
      nextAlarmAt: undefined,
      usageEvents,
      requestLog,
    }),
    proposeGoals: vi.spyOn(accountRequests, "proposeGoals").mockReturnValue({
      result: goalSetupRejected(),
      nextAlarmAt: undefined,
      usageEvents,
      requestLog,
    }),
    assessCustomTargetWeight: vi
      .spyOn(accountRequests, "assessCustomTargetWeight")
      .mockReturnValue({
        result: goalSetupRejected(),
        nextAlarmAt: undefined,
        usageEvents,
        requestLog,
      }),
    decideGoal: vi.spyOn(accountRequests, "decideGoal").mockReturnValue({
      result: goalSetupRejected(),
      nextAlarmAt: undefined,
      usageEvents,
      requestLog,
    }),
    runAlarm: vi.spyOn(accountRequests, "runAlarm").mockResolvedValue({
      result: {
        error: undefined,
        providerErrors: [],
        classifications: [],
        attempts: [],
        replyAttempts: [],
      },
      nextAlarmAt: undefined,
      usageEvents,
    }),
  };
};

const goalSetupRejected = () =>
  R.fail(new GoalSetupRequestRejectedError({ reason: "invalid_time_zone" }));
