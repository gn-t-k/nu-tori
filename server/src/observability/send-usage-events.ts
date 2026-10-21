import { match } from "ts-pattern";
import type { CachedTokenUsage, TokenUsage } from "../domain/token-usage";
import type { UsageEvent } from "../domain/usage-event";

// Durable Object では応答のあとに続ける仕組みが効かないので、数秒の上限を付けて待つ。throw すると、書き込みを当てたあとの応答が失敗する
export const sendUsageEvents = async (
  env: { POSTHOG_PROJECT_TOKEN?: string },
  accountId: string,
  events: readonly UsageEvent[],
): Promise<void> => {
  if (env.POSTHOG_PROJECT_TOKEN === undefined || events.length === 0) {
    return;
  }
  try {
    await fetch("https://eu.i.posthog.com/batch/", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        api_key: env.POSTHOG_PROJECT_TOKEN,
        batch: events.map((event) => toCapturedEvent(accountId, event)),
      }),
      signal: AbortSignal.timeout(3000),
    });
  } catch {
    return;
  }
};

const toCapturedEvent = (accountId: string, event: UsageEvent) => {
  const { name, properties } = match(event)
    .with({ name: "sync_write_rejected" }, (rejected) => ({
      name: rejected.name,
      properties: {
        write_kind: rejected.writeKind,
        record_type: rejected.recordType,
        reason: rejected.reason,
      },
    }))
    .with({ name: "meal_received" }, (received) => ({
      name: received.name,
      properties: {
        entry_method: received.entryMethod,
        minutes_from_eaten_to_sent: received.minutesFromEatenToSent,
        meal_count_of_day: received.mealCountOfDay,
      },
    }))
    .with({ name: "meal_photo_receipt_failed" }, (failed) => ({
      name: failed.name,
      properties: { stage: failed.stage },
    }))
    .with({ name: "estimation_attempt_ended" }, (ended) => ({
      name: ended.name,
      properties: {
        result: ended.result,
        identify_dishes_input_tokens: ended.identifyDishesUsage?.inputTokens,
        identify_dishes_output_tokens: ended.identifyDishesUsage?.outputTokens,
        match_ingredients_input_tokens: ended.matchIngredientsUsage?.inputTokens,
        match_ingredients_output_tokens: ended.matchIngredientsUsage?.outputTokens,
      },
    }))
    .with({ name: "estimation_ended" }, (ended) => ({
      name: ended.name,
      properties: {
        trigger: ended.trigger,
        final_status: ended.finalStatus,
        retry_count: ended.retryCount,
        dish_count: ended.dishCount,
        ingredient_count: ended.ingredientCount,
        nutrition_label_ingredient_count: ended.nutritionLabelIngredientCount,
        food_composition_ingredient_count: ended.foodCompositionIngredientCount,
        estimated_ingredient_count: ended.estimatedIngredientCount,
        seconds_from_received_to_ended: ended.secondsFromReceivedToEnded,
        provider_error_types: ended.providerErrorTypes,
      },
    }))
    .with({ name: "sent_text_classified" }, (classified) => ({
      name: classified.name,
      properties: {
        result: classified.result,
        provider_result: classified.providerResult,
        input_tokens: classified.usage?.inputTokens,
        output_tokens: classified.usage?.outputTokens,
        seconds_from_received_to_classified: classified.secondsFromReceivedToClassified,
        provider_error_type: classified.providerErrorType,
      },
    }))
    .with({ name: "reply_attempt_ended" }, (ended) => ({
      name: ended.name,
      properties: {
        result: ended.result,
        input_tokens: ended.usage?.inputTokens,
        output_tokens: ended.usage?.outputTokens,
        ...toCacheTokenProperties(ended.usage),
        provider_error_type: ended.providerErrorType,
      },
    }))
    .with({ name: "reply_generation_ended" }, (ended) => ({
      name: ended.name,
      properties: {
        final_status: ended.finalStatus,
        failure_reason: ended.failureReason,
        retry_count: ended.retryCount,
        referenced_meal_count: ended.referencedMealCount,
        seconds_from_requested_to_ended: ended.secondsFromRequestedToEnded,
        provider_error_types: ended.providerErrorTypes,
      },
    }))
    .with({ name: "reply_request_halted" }, (halted) => ({
      name: halted.name,
      properties: { reason: halted.reason },
    }))
    .with({ name: "estimation_deferred" }, (deferred) => ({
      name: deferred.name,
      properties: { reason: deferred.reason },
    }))
    .with({ name: "subscription_started" }, (started) => ({
      name: started.name,
      properties: {
        purchased_during_free_trial: started.purchasedDuringFreeTrial,
        rebuilt_account: started.rebuiltAccount,
      },
    }))
    .with({ name: "subscription_renewed" }, (renewed) => ({
      name: renewed.name,
      properties: {},
    }))
    .with({ name: "subscription_expired" }, (expired) => ({
      name: expired.name,
      properties: {
        has_purchased: expired.hasPurchased,
        by_revocation: expired.byRevocation,
        rebuilt_account: expired.rebuiltAccount,
      },
    }))
    .with({ name: "goal_decision_recorded" }, (recorded) => ({
      name: recorded.name,
      properties: {
        direction: recorded.direction,
        is_first_goal: recorded.isFirstGoal,
        chosen_plan: recorded.chosenPlan,
        had_slowed_proposal: recorded.hadSlowedProposal,
        rejected_custom_target_weight_count: recorded.rejectedCustomTargetWeightCount,
        expenditure_source: recorded.expenditureSource,
        limit_hits: recorded.limitHits,
      },
    }))
    .with({ name: "weekly_review", outcome: "deferred" }, (deferred) => ({
      name: deferred.name,
      properties: {
        deferred: true,
        deferral_reason: deferred.deferralReason,
        limit_hits: [],
        main_reason: undefined,
        expenditure_change_kcal: undefined,
        initial_expenditure_source: deferred.initialExpenditureSource,
        expenditure_change_from_initial_kcal: deferred.expenditureChangeFromInitialKcal,
        reviewed_week_count: deferred.reviewedWeekCount,
      },
    }))
    .with({ name: "weekly_review", outcome: "reviewed" }, (reviewed) => ({
      name: reviewed.name,
      properties: {
        deferred: false,
        deferral_reason: undefined,
        limit_hits: reviewed.limitHits,
        main_reason: reviewed.mainReason,
        expenditure_change_kcal: reviewed.expenditureChangeKcal,
        initial_expenditure_source: reviewed.initialExpenditureSource,
        expenditure_change_from_initial_kcal: reviewed.expenditureChangeFromInitialKcal,
        reviewed_week_count: reviewed.reviewedWeekCount,
      },
    }))
    .with({ name: "goal_achieved" }, (achieved) => ({
      name: achieved.name,
      properties: {
        days_from_start: achieved.daysFromStart,
        days_until_deadline: achieved.daysUntilDeadline,
      },
    }))
    .with({ name: "goal_deadline_confirmed" }, (confirmed) => ({
      name: confirmed.name,
      properties: {
        difference_from_target_kg: confirmed.differenceFromTargetKg,
        achieved: confirmed.achieved,
      },
    }))
    .with({ name: "goal_moved_to_maintenance" }, (moved) => ({
      name: moved.name,
      properties: { days_after_deadline: moved.daysAfterDeadline },
    }))
    .with({ name: "sync_pending_writes_reported" }, (reported) => ({
      name: reported.name,
      properties: {
        pending_write_count: reported.pendingWriteCount,
        oldest_pending_write_age_seconds: reported.oldestPendingWriteAgeSeconds,
      },
    }))
    .with({ name: "reestimated_dish_edited" }, (edited) => ({
      name: edited.name,
      properties: {
        action: edited.action,
        seconds_from_reestimation_ended: edited.secondsFromReestimationEnded,
      },
    }))
    .with({ name: "estimated_quantity_corrected", target: "dish" }, (corrected) => ({
      name: corrected.name,
      properties: {
        target: corrected.target,
        meal_input: corrected.mealInput,
        ratio: corrected.ratio,
      },
    }))
    .with({ name: "estimated_quantity_corrected", target: "ingredient" }, (corrected) => ({
      name: corrected.name,
      properties: {
        target: corrected.target,
        meal_input: corrected.mealInput,
        ingredient_nutrient_source: corrected.ingredientNutrientSource,
        ratio: corrected.ratio,
      },
    }))
    .exhaustive();
  return {
    event: name,
    distinct_id: accountId,
    properties: { ...properties, $geoip_disable: true },
  };
};

// キャッシュのトークン数は、キャッシュの印を付ける呼び出しの使ったトークンにだけある
const toCacheTokenProperties = (usage: TokenUsage | CachedTokenUsage | undefined) =>
  usage !== undefined && "cacheCreationInputTokens" in usage
    ? {
        cache_creation_input_tokens: usage.cacheCreationInputTokens,
        cache_read_input_tokens: usage.cacheReadInputTokens,
      }
    : {};
