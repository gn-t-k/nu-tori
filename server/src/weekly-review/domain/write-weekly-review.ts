import type { ComputedReviewedDailyGuide } from "../../daily-guide/domain/computed-daily-guide";
import {
  type DailyGuide,
  dailyGuideLimitTypes,
  dailyGuideMainReasons,
} from "../../daily-guide/domain/daily-guide";
import { computeDayOfWeek } from "../../domain/compute-day-of-week";
import type { RecordChangeWrites } from "../../domain/record-change-writes";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import {
  type ExpenditureDeviationDirection,
  expenditureDeviationDirections,
} from "../../expenditure-estimate/domain/expenditure-estimate";
import {
  type WeeklyReview,
  type WeeklyReviewDeferral,
  weeklyReviewDeferralReasons,
} from "./weekly-review";
import { isListed } from "../../domain/is-listed";

// 書く週の見直し。見送った週は見送りを、見直せた週は新しい推定と、それを使った今の目標の1日の目安を持つ。
// 期限後の維持に移る週は、作る維持の目標も持ち、見送りと1日の目安はその維持の目標を指す
export type WeeklyReviewToWrite = Omit<WeeklyReview, "id" | "outcome"> & {
  postDeadlineMaintenance: PostDeadlineMaintenanceToWrite | undefined;
  outcome:
    | WeeklyReviewDeferral
    | {
        type: "reviewed";
        expenditure: {
          expenditureKcal: number;
          deviationDirection: ExpenditureDeviationDirection;
        };
        dailyGuide: ComputedReviewedDailyGuide & { goalId: RecordId };
      };
};

// 期限後の維持の目標。ID は呼ぶ側が振り、見送りと1日の目安の goalId に渡す。開始の日は見直しの月曜、決めた時刻は見直した時刻
export type PostDeadlineMaintenanceToWrite = {
  goalId: RecordId;
  targetWeightKg: number;
  startingWeightTrendKg: number;
};

// 週の見直しを書く口。週の見直しと、見送りか見直した推定と1日の目安の行を、外部キーが指す行を先にして書き、変えた記録を、依る記録を先にして足す（推定消費カロリー → 1日の目安 → 週の見直し）。
// 記録の変化を書く入口（RecordChangeWriter）の run の中で、1週に1回呼ぶ。
// 見直した推定の当てる始まりの日と推定した時刻は、週の見直しの月曜と見直した時刻にし、見直した1日の目安はその推定を指してその月曜から当てる。
// 期限後の維持に移る週は、同じ run の中で、今の目標をその月曜で閉じて期限の無い維持の目標を作り、変更は閉じた前の目標 → 維持の目標を 1日の目安の前に足す。見送った週は、前の目標の最後の1日の目安の値を写し、今の推定を指す1日の目安を維持の目標に書く（上限と下限と見直した1日の目安の行は書かない）。
// 表で守らない決まり（当てる日は最も遅い推定より後の月曜、見送りと1日の目安は今の目標か作る維持の目標を指す、維持に移るのは期限の日より後の月曜、区分の値）は、書く前にここで確かめて投げる。1週に1つは一意の索引が保つ
export const writeWeeklyReview = (
  stores: Pick<RecordKindStores, "weeklyReview" | "goal" | "expenditureEstimate" | "dailyGuide">,
  addChange: RecordChangeWrites["addChange"],
  review: WeeklyReviewToWrite,
): RecordId => {
  const { outcome, ...weeklyReview } = review;
  requireWritable(stores, review);

  const { postDeadlineMaintenance } = review;
  // 書く前に読む。維持の目標を作ると今の目標が変わり、見送った週に写す1日の目安も前の目標から引く
  const previousGoal = stores.goal.findCurrent();
  // 期限後の維持に移る週だけ、前の目標を閉じて維持の目標を作る。移る週に今の目標があることは requireWritable が確かめた
  const maintenanceMove =
    postDeadlineMaintenance === undefined || previousGoal === undefined
      ? { writeRows: () => {}, changes: [] }
      : {
          writeRows: () =>
            writePostDeadlineMaintenance(stores, review, postDeadlineMaintenance, previousGoal.id),
          // 閉じた前の目標 → 維持の目標
          changes: [
            { recordType: "goal" as const, recordId: previousGoal.id },
            { recordType: "goal" as const, recordId: postDeadlineMaintenance.goalId },
          ],
        };
  const copiedDailyGuide =
    postDeadlineMaintenance !== undefined && outcome.type === "deferred"
      ? findCopiedDailyGuide(stores, {
          effectiveOn: review.effectiveOn,
          goalId: postDeadlineMaintenance.goalId,
        })
      : undefined;

  const id = generateRecordId();
  stores.weeklyReview.insert({ ...weeklyReview, id });
  if (outcome.type === "deferred") {
    maintenanceMove.writeRows();
    if (copiedDailyGuide !== undefined) {
      stores.dailyGuide.insert(copiedDailyGuide);
    }
    stores.weeklyReview.insertDeferral({
      weeklyReviewId: id,
      reason: outcome.reason,
      goalId: outcome.goalId,
    });
    maintenanceMove.changes.forEach(addChange);
    if (copiedDailyGuide !== undefined) {
      addChange({ recordType: "daily_guide", recordId: copiedDailyGuide.id });
    }
    addChange({ recordType: "weekly_review", recordId: id });
    return id;
  }

  const expenditureEstimateId = generateRecordId();
  const dailyGuideId = generateRecordId();
  const { mainReason, ...dailyGuide } = outcome.dailyGuide;
  stores.expenditureEstimate.insert({
    id: expenditureEstimateId,
    effectiveOn: review.effectiveOn,
    expenditureKcal: outcome.expenditure.expenditureKcal,
    estimatedAt: review.reviewedAt,
    initialSource: undefined,
  });
  stores.weeklyReview.insertReviewedExpenditureEstimate({
    expenditureEstimateId,
    weeklyReviewId: id,
    deviationDirection: outcome.expenditure.deviationDirection,
  });
  maintenanceMove.writeRows();
  stores.dailyGuide.insert({
    ...dailyGuide,
    id: dailyGuideId,
    expenditureEstimateId,
    effectiveOn: review.effectiveOn,
  });
  stores.weeklyReview.insertReviewedDailyGuide({ dailyGuideId, mainReason });

  addChange({ recordType: "expenditure_estimate", recordId: expenditureEstimateId });
  maintenanceMove.changes.forEach(addChange);
  addChange({ recordType: "daily_guide", recordId: dailyGuideId });
  addChange({ recordType: "weekly_review", recordId: id });
  return id;
};

// 期限後の維持の組（目標、前の目標を閉じる、期限後の維持のサブセット）を、外部キーが指す行を先にして書く
const writePostDeadlineMaintenance = (
  stores: Pick<RecordKindStores, "goal">,
  { effectiveOn, reviewedAt, timeZone }: WeeklyReviewToWrite,
  { goalId, targetWeightKg, startingWeightTrendKg }: PostDeadlineMaintenanceToWrite,
  previousGoalId: RecordId,
): void => {
  stores.goal.insert({
    id: goalId,
    startedOn: effectiveOn,
    startingWeightTrendKg,
    targetWeightKg,
    decidedAt: reviewedAt,
    timeZone,
    weightChange: undefined,
  });
  stores.goal.insertClosure({ goalId: previousGoalId, nextGoalId: goalId });
  stores.goal.insertPostDeadlineMaintenance(goalId);
};

// 見送った週に期限後の維持へ移るとき、維持の目標に書く1日の目安。前の目標の最後の1日の目安の値（kcal と P・F・C）を写し、今の推定を指す。
// P も出し直さず、上限と下限は書かない
const findCopiedDailyGuide = (
  stores: Pick<RecordKindStores, "goal" | "dailyGuide" | "expenditureEstimate">,
  { effectiveOn, goalId }: { effectiveOn: string; goalId: RecordId },
): DailyGuide => {
  const previousGoal = stores.goal.findCurrent();
  // 見直す月曜はまだ見直していないので、前の目標の1日の目安はどれもその月曜より前から当たる
  const lastDailyGuide =
    previousGoal === undefined
      ? undefined
      : stores.dailyGuide.findLatestOfGoalBefore(previousGoal.id, effectiveOn);
  const currentEstimate = stores.expenditureEstimate.findCurrent();
  if (lastDailyGuide === undefined || currentEstimate === undefined) {
    throw new Error("期限後の維持に移る前の目標に、1日の目安か推定が無い");
  }
  return {
    ...lastDailyGuide,
    id: generateRecordId(),
    goalId,
    expenditureEstimateId: currentEstimate.id,
    effectiveOn,
    limitHits: [],
  };
};

const requireWritable = (
  stores: Pick<RecordKindStores, "goal" | "expenditureEstimate">,
  { effectiveOn, outcome, postDeadlineMaintenance }: WeeklyReviewToWrite,
): void => {
  if (computeDayOfWeek(effectiveOn) !== "monday") {
    throw new Error("見直しの当てる日が月曜でない");
  }
  const latestEstimate = stores.expenditureEstimate.findCurrent();
  if (latestEstimate !== undefined && effectiveOn <= latestEstimate.effectiveOn) {
    throw new Error("見直す月曜が、最も遅い推定の当てる始まりの日より後でない");
  }
  const goalId = outcome.type === "deferred" ? outcome.goalId : outcome.dailyGuide.goalId;
  const currentGoal = stores.goal.findCurrent();
  if (postDeadlineMaintenance === undefined) {
    if (goalId !== currentGoal?.id) {
      throw new Error("見直しの目標が、今の目標ではない");
    }
  } else {
    if (goalId !== postDeadlineMaintenance.goalId) {
      throw new Error("期限後の維持に移る週の見直しの目標が、作る維持の目標ではない");
    }
    if (
      currentGoal?.weightChange === undefined ||
      effectiveOn <= currentGoal.weightChange.deadlineOn
    ) {
      throw new Error("期限後の維持に移るのが、今の減量・増量の目標の期限の日より後の月曜ではない");
    }
  }
  // 区分の列に CHECK は無いので、型をすり抜けた値をここで止める
  if (outcome.type === "deferred") {
    if (!isListed(weeklyReviewDeferralReasons, outcome.reason)) {
      throw new Error("見送りの理由の値が一覧に無い");
    }
    return;
  }
  if (!isListed(expenditureDeviationDirections, outcome.expenditure.deviationDirection)) {
    throw new Error("ずれの向きの値が一覧に無い");
  }
  if (!isListed(dailyGuideMainReasons, outcome.dailyGuide.mainReason)) {
    throw new Error("主な理由の値が一覧に無い");
  }
  if (
    !outcome.dailyGuide.limitHits.every((limitType) => isListed(dailyGuideLimitTypes, limitType))
  ) {
    throw new Error("当たった上限と下限の値が一覧に無い");
  }
};
