import { subscriptionD1Tables } from "../subscription/d1/subscription-d1-tables";
import { appleRefreshTokenTables } from "./apple-refresh-token-tables";
import { authenticationTables } from "./authentication-tables";

// D1 の表の全部。表を足したら、ここに足す（足し忘れは d1-tables.test.ts で落ちる）
export const d1Tables = {
  ...authenticationTables,
  ...appleRefreshTokenTables,
  ...subscriptionD1Tables,
};
