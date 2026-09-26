// 場所のヒントが効くのは、その Durable Object を最初に得るときだけ
export const getAccountDurableObject = (env: Pick<Env, "ACCOUNT">, accountId: string) =>
  env.ACCOUNT.get(env.ACCOUNT.idFromName(accountId), { locationHint: "apac-ne" });
