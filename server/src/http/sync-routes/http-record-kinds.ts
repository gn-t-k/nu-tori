import { accountSettingsHttpKind } from "../../account-settings/http/account-settings-http-kind";
import { aiUtteranceHttpKind } from "../../ai-utterance/http/ai-utterance-http-kind";
import { dishHttpKind } from "../../dish/http/dish-http-kind";
import { dishEstimationStatusHttpKind } from "../../dish-estimation-status/http/dish-estimation-status-http-kind";
import type { RecordType } from "../../domain/record-type";
import { ingredientHttpKind } from "../../ingredient/http/ingredient-http-kind";
import { mealHttpKind } from "../../meal/http/meal-http-kind";
import { mealEstimationStatusHttpKind } from "../../meal-estimation-status/http/meal-estimation-status-http-kind";
import { noticeHttpKind } from "../../notice/http/notice-http-kind";
import { sentTextHttpKind } from "../../sent-text/http/sent-text-http-kind";
import { sentTextStatusHttpKind } from "../../sent-text-status/http/sent-text-status-http-kind";
import { usualWeighingTimeHttpKind } from "../../usual-weighing-time/http/usual-weighing-time-http-kind";
import { weightRecordHttpKind } from "../../weight-record/http/weight-record-http-kind";
import { weightTrendHttpKind } from "../../weight-trend/http/weight-trend-http-kind";
import type { HttpRecordKind } from "./http-record-kind";

// 受け口から見た種類の登録簿。RecordType をキーにするので、種類を足して行を足し忘れるとコンパイルが落ちる。
// 書き込みのスキーマの型を保つため、注釈でなく satisfies で確かめる
export const httpRecordKinds = {
  account_settings: accountSettingsHttpKind,
  ai_utterance: aiUtteranceHttpKind,
  dish: dishHttpKind,
  dish_estimation_status: dishEstimationStatusHttpKind,
  ingredient: ingredientHttpKind,
  meal: mealHttpKind,
  meal_estimation_status: mealEstimationStatusHttpKind,
  notice: noticeHttpKind,
  sent_text: sentTextHttpKind,
  sent_text_status: sentTextStatusHttpKind,
  usual_weighing_time: usualWeighingTimeHttpKind,
  weight_record: weightRecordHttpKind,
  weight_trend: weightTrendHttpKind,
} as const satisfies { [K in RecordType]: HttpRecordKind };
