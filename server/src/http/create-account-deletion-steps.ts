import { createAppleRefreshTokenStore } from "../auth/create-apple-refresh-token-store";
import type { createAuthentication } from "../auth/create-authentication";
import { revokeAppleRefreshToken } from "../auth/revoke-apple-refresh-token";
import { getAccountDurableObject } from "../durable-object/get-account-durable-object";

export const createAccountDeletionSteps = (
  env: Env,
  authentication: ReturnType<typeof createAuthentication>,
) => {
  const appleRefreshTokens = createAppleRefreshTokenStore(env.DB, env.APPLE_REFRESH_TOKEN_KEYS);
  return {
    revokeAppleAuthorization: async (accountId: string) => {
      const refreshToken = await appleRefreshTokens.find(accountId);
      if (refreshToken !== undefined) {
        await revokeAppleRefreshToken(env, refreshToken);
      }
      await appleRefreshTokens.delete(accountId);
    },
    deleteRecords: async (accountId: string) => {
      await getAccountDurableObject(env, accountId).deleteRecords();
    },
    deleteAuthentication: async (accountId: string) => {
      const { internalAdapter } = await authentication.$context;
      await internalAdapter.deleteUser(accountId);
    },
  };
};
