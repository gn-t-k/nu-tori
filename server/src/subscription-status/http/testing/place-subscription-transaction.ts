import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { durableObjectTables } from "../../../durable-object/durable-object-tables";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";
import { durableObjectFactory } from "../../../durable-object/testing/durable-object-factory";

// 取り消されていない月額の取引を1つ置き、サブスクリプションの終わりを expiresAt にする。状態の記録の変更は足さない
export const placeSubscriptionTransaction = (
  accountId: string,
  { expiresAt }: { expiresAt: Date },
): Promise<void> =>
  runInDurableObject(getAccountDurableObject(env, accountId), async (_, state) => {
    const factory = durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables }));
    const transaction = await factory.subscriptionTransactions.create({ expiresAt });
    await factory.appStoreSubscriptionTransactions.create({
      subscriptionTransactionId: transaction.id,
    });
  });
