import { match } from "ts-pattern";
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
    .with({ name: "estimation_deferred" }, (deferred) => ({
      name: deferred.name,
      properties: {},
    }))
    .with({ name: "sync_pending_writes_reported" }, (reported) => ({
      name: reported.name,
      properties: {
        pending_write_count: reported.pendingWriteCount,
        oldest_pending_write_age_seconds: reported.oldestPendingWriteAgeSeconds,
      },
    }))
    .with({ name: "estimated_quantity_corrected" }, (corrected) => ({
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
