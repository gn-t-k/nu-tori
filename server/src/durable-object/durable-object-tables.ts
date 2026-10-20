import { accountSettingsTables } from "../account-settings/durable-object/account-settings-tables";
import { aiUtteranceTables } from "../ai-utterance/durable-object/ai-utterance-tables";
import { dailyGuideTables } from "../daily-guide/durable-object/daily-guide-tables";
import { dishTables } from "../dish/durable-object/dish-tables";
import { estimationTables } from "../estimation/durable-object/estimation-tables";
import { expenditureEstimateTables } from "../expenditure-estimate/durable-object/expenditure-estimate-tables";
import { goalTables } from "../goal/durable-object/goal-tables";
import { ingredientTables } from "../ingredient/durable-object/ingredient-tables";
import { mealPhotoTables } from "../meal/durable-object/meal-photo-tables";
import { mealTables } from "../meal/durable-object/meal-tables";
import { noticeTables } from "../notice/durable-object/notice-tables";
import { replyTables } from "../reply/durable-object/reply-tables";
import { sentTextTables } from "../sent-text/durable-object/sent-text-tables";
import { usualWeighingTimeTables } from "../usual-weighing-time/durable-object/usual-weighing-time-tables";
import { weeklyReviewTables } from "../weekly-review/durable-object/weekly-review-tables";
import { weightRecordTables } from "../weight-record/durable-object/weight-record-tables";
import { firstSignInTables } from "./first-sign-in-tables";
import { syncLedgerTables } from "./sync-ledger-tables";

// Durable Object の全部の表。置き場のテストの行の作成と、宣言と移行のずれのテストが読む
export const durableObjectTables = {
  ...firstSignInTables,
  ...syncLedgerTables,
  ...weightRecordTables,
  ...accountSettingsTables,
  ...mealTables,
  ...mealPhotoTables,
  ...estimationTables,
  ...dishTables,
  ...ingredientTables,
  ...noticeTables,
  ...usualWeighingTimeTables,
  ...sentTextTables,
  ...replyTables,
  ...aiUtteranceTables,
  ...goalTables,
  ...expenditureEstimateTables,
  ...dailyGuideTables,
  ...weeklyReviewTables,
};
