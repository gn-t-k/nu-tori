import { checkE2eAccess } from "./check-e2e-access";
import { e2eRequestHeaders } from "./e2e-request-headers";

// 要求を受けた時刻。確かめのジョブは、新しいアカウントに前の週を作るため、目標の設定の要求を過去の時刻に送ったことにする。
// 無料体験の終わったアカウントを作るため、サインインも過去の時刻に送ったことにする。
// 差し替えは、確かめのジョブのための口が開いていて（check-e2e-access.ts）、時刻が読めるときだけ受け付ける。
// ほか（本番、秘密の値が違う、時刻が読めない）は、差し替えのヘッダーが無いのと同じに今の時刻にし、口があることを漏らさない
export const resolveRequestedAt = async (
  env: Pick<Env, "SENTRY_ENVIRONMENT" | "E2E_SIGN_IN_SECRET">,
  readHeader: (name: string) => string | undefined,
): Promise<Date> => {
  const now = new Date();
  const requestedAt = readHeader(e2eRequestHeaders.requestedAt);
  if (requestedAt === undefined) {
    return now;
  }
  const requestedTime = Date.parse(requestedAt);
  if (
    Number.isNaN(requestedTime) ||
    (await checkE2eAccess(env, readHeader(e2eRequestHeaders.signInSecret))) !== "allowed"
  ) {
    return now;
  }
  return new Date(requestedTime);
};
