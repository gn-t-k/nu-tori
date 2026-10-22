// 置き場を直に組むテストで渡す、テストユーザーでないアカウントの、Durable Object の外の事実。課金を入れた日は vitest.config.ts と同じ
export const regularSubscriptionAccount = { isTestUser: false, billingStartedOn: "2026-01-01" };
