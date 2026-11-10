import { match } from "ts-pattern";
import { decideStandardLoseGoal } from "./decide-standard-lose-goal";
import type { DeviceClient, DeviceSession } from "./device-client";
import { expiredAccountAgeDays, requireFreeTrialEnded } from "./read-free-trial-last-day";
import { addDays } from "../src/domain/add-days";
import { computeCalendarDayInTimeZone } from "../src/domain/compute-calendar-day-in-time-zone";
import { millisecondsPerDay } from "../src/domain/milliseconds-per-day";
import { generateRecordId } from "../src/domain/record-id";

// 時の経過で起きる知らせを、待たずにアプリで見るための場面。
// 確かめの口でサインインし、体重と目標を過去の時刻で送る。
// 期限の日の確定と週の見直しは、場面を作ったあとの最初の取りに行く要求（アプリが開いて送る、今の時刻の要求）で起きるので、場面を作る道では取りに行かない
export const scenarioNames = [
  "goal-deadline-passed",
  "unreviewed-week",
  "free-trial-expired",
] as const;

export type ScenarioName = (typeof scenarioNames)[number];

export const createScenario = (
  client: DeviceClient,
  scenario: ScenarioName,
): Promise<DeviceSession> =>
  match(scenario)
    .with("goal-deadline-passed", () => createGoalDeadlinePassed(client))
    .with("unreviewed-week", () => createUnreviewedWeek(client))
    .with("free-trial-expired", () => createFreeTrialExpired(client))
    .exhaustive();

// 7週前に、30日後を期限とする減量の目標を決めた。期限の日（19日前）と、そのあとの最初の月曜（12〜18日前）は過ぎている。
// 体重は目標体重に届かない値で毎日量ったので、達成でなく期限の日の確定になり、同じ要求の見直しで期限後の維持に移る。
// 使い始めた日を目標より前にすると無料体験が終わり、見直しがサブスクリプション切れで見送られるので、サインインは今にする
const createGoalDeadlinePassed = async (client: DeviceClient): Promise<DeviceSession> => {
  const session = await client.signIn();
  const decidedAt = new Date(Date.now() - 49 * millisecondsPerDay);
  await decideGoalWithDailyWeights(session, {
    decidedAt,
    deadlineOn: addDays(computeCalendarDayInTimeZone(decidedAt, client.timeZone), 30),
  });
  return session;
};

// 7日前に使い始め、13週後を期限とする減量の目標を決めた。開始の日が前の週に入り、今週の月曜の週がまだ見直していない週になる
const createUnreviewedWeek = async (client: DeviceClient): Promise<DeviceSession> => {
  const decidedAt = new Date(Date.now() - 7 * millisecondsPerDay);
  const session = await client.signIn(new Date(decidedAt.getTime() - 2 * 60_000));
  await decideGoalWithDailyWeights(session, {
    decidedAt,
    deadlineOn: addDays(computeCalendarDayInTimeZone(decidedAt, client.timeZone), 90),
  });
  return session;
};

// 60日前に使い始めた。目標は決めない（決める前に、サブスクリプション切れの知らせと課金の画面が出る）。
// 無料体験が終わっていなければ、課金を入れた日を直すよう書いて投げる
const createFreeTrialExpired = async (client: DeviceClient): Promise<DeviceSession> => {
  const session = await client.signIn(
    new Date(Date.now() - expiredAccountAgeDays * millisecondsPerDay),
  );
  await requireFreeTrialEnded(session);
  return session;
};

// 目標を決める1分前に体重を量って decidedAt に目標を決め、そのあと今まで毎日同じ時刻に体重を量ったことにする。
// 決めたあとの体重は、目標の計算の元に入らないよう、決めてから送る。送る要求は送り切った印を付けないので、判定を起こさない
const decideGoalWithDailyWeights = async (
  session: DeviceSession,
  goal: { decidedAt: Date; deadlineOn: string },
): Promise<void> => {
  const firstMeasuredAt = goal.decidedAt.getTime() - 60_000;
  await session.pushAppliedWrites([createWeightWrite(firstMeasuredAt)]);
  await decideStandardLoseGoal(session, goal);
  const laterMeasuredAts = Array.from(
    { length: Math.floor((Date.now() - firstMeasuredAt) / millisecondsPerDay) },
    (_, index) => firstMeasuredAt + (index + 1) * millisecondsPerDay,
  );
  if (laterMeasuredAts.length > 0) {
    await session.pushAppliedWrites(laterMeasuredAts.map(createWeightWrite));
  }
};

// 体重は作り話にする（公開リポジトリ）。目標を決めたときと同じ値のままにし、減量の目標体重に届かせない
const createWeightWrite = (measuredAt: number) => ({
  id: generateRecordId(),
  type: "create_weight_record" as const,
  weightRecord: {
    id: generateRecordId(),
    weightKg: 60.5,
    measuredAt,
    timeZone: "Asia/Tokyo",
  },
});
