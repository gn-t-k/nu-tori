import { computeDayOfWeek } from "../../domain/compute-day-of-week";
import type { RecordChangeWrites } from "../../domain/record-change-writes";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import {
  type WeeklyReview,
  type WeeklyReviewDeferral,
  weeklyReviewDeferralReasons,
} from "./weekly-review";

// 週の見直しを書く口。週の見直しと見送りの行を、外部キーが指す行を先にして書き、変えた記録を足す。
// 記録の変化を書く入口（RecordChangeWriter）の run の中で、1週に1回呼ぶ。
// 表で守らない決まり（当てる日は最も遅い推定より後の月曜、見送りは今の目標を指す、区分の値）は、書く前にここで確かめて投げる。
// 1週に1つは一意の索引が保つ
export const writeWeeklyReview = (
  stores: Pick<RecordKindStores, "weeklyReview" | "goal" | "expenditureEstimate">,
  addChange: RecordChangeWrites["addChange"],
  review: Omit<WeeklyReview, "id" | "outcome"> & {
    // 見直せた週の行は、見直しを書くときに足す
    deferral: Omit<WeeklyReviewDeferral, "type">;
  },
): RecordId => {
  const { deferral, ...weeklyReview } = review;
  requireWritable(stores, review);

  const id = generateRecordId();
  stores.weeklyReview.insert({ ...weeklyReview, id });
  stores.weeklyReview.insertDeferral({ ...deferral, weeklyReviewId: id });
  addChange({ recordType: "weekly_review", recordId: id });
  return id;
};

const requireWritable = (
  stores: Pick<RecordKindStores, "goal" | "expenditureEstimate">,
  { effectiveOn, deferral }: Parameters<typeof writeWeeklyReview>[2],
): void => {
  if (computeDayOfWeek(effectiveOn) !== "monday") {
    throw new Error("見直しの当てる日が月曜でない");
  }
  const latestEstimate = stores.expenditureEstimate.findCurrent();
  if (latestEstimate !== undefined && effectiveOn <= latestEstimate.effectiveOn) {
    throw new Error("見直す月曜が、最も遅い推定の当てる始まりの日より後でない");
  }
  if (deferral.goalId !== stores.goal.findCurrent()?.id) {
    throw new Error("見送りの目標が、今の目標ではない");
  }
  // 区分の列に CHECK は無いので、型をすり抜けた値をここで止める
  if (!isListed(weeklyReviewDeferralReasons, deferral.reason)) {
    throw new Error("見送りの理由の値が一覧に無い");
  }
};

const isListed = (values: readonly string[], value: string): boolean => values.includes(value);
