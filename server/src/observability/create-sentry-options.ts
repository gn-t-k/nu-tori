import type { CloudflareOptions } from "@sentry/cloudflare";

export const createSentryOptions = (env: Env) =>
  ({
    dsn: env.SENTRY_DSN,
    environment: env.SENTRY_ENVIRONMENT,
    // v11 は既定で、要求と応答の本文・ヘッダー・IP・ローカル変数などを集める。記録の中身を送らないよう、すべて切る
    dataCollection: {
      userInfo: false,
      cookies: false,
      httpHeaders: false,
      httpBodies: [],
      urlQueryParams: false,
      graphQL: { document: false, variables: false },
      genAI: { inputs: false, outputs: false },
      databaseQueryData: false,
      queues: false,
      stackFrameVariables: false,
    },
  }) satisfies CloudflareOptions;
