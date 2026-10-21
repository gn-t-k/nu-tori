import { env, runInDurableObject } from "cloudflare:test";
import { match } from "ts-pattern";
import { computeCalendarDayInTimeZone } from "../../../domain/compute-calendar-day-in-time-zone";
import { generateRecordId } from "../../../domain/record-id";
import { createRecordChangeWriter } from "../../../durable-object/create-record-change-writer";
import { createRecordKindStores } from "../../../durable-object/create-record-kind-stores";
import { buildReplyContext } from "../../domain/build-reply-context";
import type { ReplyContext } from "../../domain/reply-context";
import type { buildReplyContextRecords } from "./build-reply-context-records";

// 新しいアカウントの置き場に記録を置き、応える文章の返事の文脈を、時刻 now に組み立てる。
// ドメイン層のテストは cloudflare:test を import できないので、Durable Object の置き場で組んだ形をここで作る
export const buildReplyContextInAccount = (
  records: ReturnType<typeof buildReplyContextRecords.records>,
  now: Date,
): Promise<ReplyContext> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), (_instance, state) => {
    const stores = createRecordKindStores(state.storage);
    const writeRecordChanges = createRecordChangeWriter(state.storage);

    const sentTexts = [
      ...records.sentTexts,
      {
        sentText: records.sentText,
        classification: { type: "conversation" as const, replyBody: undefined },
      },
    ];
    for (const { sentText, classification } of sentTexts) {
      stores.sentText.insert(sentText);
      stores.sentText.insertClassification({
        sentTextId: sentText.id,
        classifiedAt: sentText.sentAt,
        result: classification.type,
      });
      if (classification.type === "conversation") {
        writeRecordChanges(({ reply }) => {
          const requestId = generateRecordId();
          reply.request({
            id: requestId,
            sentTextId: sentText.id,
            countedOn: computeCalendarDayInTimeZone(sentText.sentAt, sentText.timeZone),
            trigger: { type: "classification" },
          });
          if (classification.replyBody === undefined) {
            return;
          }
          const generationId = generateRecordId();
          reply.beginGeneration({ id: generationId, requestId, startedAt: sentText.sentAt });
          reply.reply({ generationId, body: classification.replyBody, mealIds: [] });
        });
      }
    }

    for (const { meal, estimation, dishes } of records.meals) {
      if (estimation !== "settled" && dishes.length > 0) {
        throw new Error("料理は推定の済んだ食事にだけ置く");
      }
      stores.meal.insert(meal);
      const target = { type: "meal" as const, mealId: meal.id };
      const scheduleId = `schedule-${meal.id}`;
      const estimationId = `estimation-${meal.id}`;
      // 推定を待つ食事は予定だけ、推定できなかった食事は断念まで、推定の済んだ食事は完了まで書く
      writeRecordChanges(({ estimationAt }) => {
        const writes = estimationAt(now);
        writes.scheduleMeal({
          id: scheduleId,
          mealId: meal.id,
          dueAt: meal.sentAt,
          countedOn: computeCalendarDayInTimeZone(meal.sentAt, meal.sentTimeZone),
        });
        match(estimation)
          .with("awaiting", () => undefined)
          .with("failed", () => {
            writes.beginEstimation({
              id: estimationId,
              scheduleId,
              startedAt: meal.sentAt,
              target,
            });
            writes.abandon({ estimationId, abandonedAt: meal.sentAt, target });
          })
          .with("settled", () => {
            writes.beginEstimation({
              id: estimationId,
              scheduleId,
              startedAt: meal.sentAt,
              target,
            });
            writes.complete({
              estimationId,
              completedAt: meal.sentAt,
              target,
              dishCount: dishes.length,
              ingredients: dishes.flatMap(({ ingredients }) => ingredients),
            });
          })
          .exhaustive();
      });
      for (const [positionInMeal, dish] of dishes.entries()) {
        stores.dish.insert({ id: dish.id, mealId: meal.id, name: dish.name, positionInMeal });
        stores.dish.insertEstimationApplication({
          dishId: dish.id,
          estimationId,
          estimatedQuantity: dish.estimatedQuantity,
        });
        for (const [positionInDish, ingredient] of dish.ingredients.entries()) {
          stores.ingredient.insert({
            ...ingredient,
            dishId: dish.id,
            estimationId,
            positionInDish,
          });
        }
      }
    }

    for (const record of records.weightRecords) {
      stores.weightRecord.insert(record);
    }

    for (const estimate of records.expenditureEstimates) {
      stores.expenditureEstimate.insert(estimate);
    }
    for (const { achievement, deadlineConfirmation, closure: _, ...goal } of records.goals) {
      stores.goal.insert(goal);
      if (achievement !== undefined) {
        stores.goal.insertAchievement({ ...achievement, goalId: goal.id });
      }
      if (deadlineConfirmation !== undefined) {
        stores.goal.insertDeadlineConfirmation({ ...deadlineConfirmation, goalId: goal.id });
      }
    }
    // 次の目標の行のあとに閉じる。終わった日は次の目標の開始の日なので書かない
    for (const { id, closure } of records.goals) {
      if (closure === undefined) {
        continue;
      }
      if (closure.endReason === "moved_to_maintenance") {
        stores.goal.insertPostDeadlineMaintenance(closure.nextGoalId);
      }
      stores.goal.insertClosure({ goalId: id, nextGoalId: closure.nextGoalId });
    }
    for (const dailyGuide of records.dailyGuides) {
      stores.dailyGuide.insert(dailyGuide);
    }
    for (const { outcome, ...review } of records.weeklyReviews) {
      stores.weeklyReview.insert(review);
      match(outcome)
        .with({ type: "deferred" }, ({ reason, goalId }) => {
          stores.weeklyReview.insertDeferral({ weeklyReviewId: review.id, reason, goalId });
        })
        .with({ type: "reviewed" }, ({ expenditureEstimateId, dailyGuideId, mainReason }) => {
          stores.weeklyReview.insertReviewedExpenditureEstimate({
            expenditureEstimateId,
            weeklyReviewId: review.id,
            deviationDirection: "zero",
          });
          stores.weeklyReview.insertReviewedDailyGuide({ dailyGuideId, mainReason });
        })
        .exhaustive();
    }

    return buildReplyContext(stores, records.sentText, now);
  });
