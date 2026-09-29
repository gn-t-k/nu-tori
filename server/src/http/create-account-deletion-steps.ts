import { createAppleRefreshTokenStore } from "../auth/create-apple-refresh-token-store";
import type { createAuthentication } from "../auth/create-authentication";
import { revokeAppleRefreshToken } from "../auth/revoke-apple-refresh-token";
import { getAccountDurableObject } from "../durable-object/get-account-durable-object";
import { deletePostHogPerson } from "../observability/delete-posthog-person";

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
    deleteAnalyticsEvents: async (accountId: string) => {
      // PostHog には本番だけが送るので、開発用には消すものが無い
      if (env.POSTHOG_PROJECT_ID === undefined || env.POSTHOG_PERSONAL_API_KEY === undefined) {
        return;
      }
      await deletePostHogPerson(
        { projectId: env.POSTHOG_PROJECT_ID, personalApiKey: env.POSTHOG_PERSONAL_API_KEY },
        accountId,
      );
    },
    deleteAuthentication: async (accountId: string) => {
      const { internalAdapter } = await authentication.$context;
      await internalAdapter.deleteUser(accountId);
    },
  };
};
