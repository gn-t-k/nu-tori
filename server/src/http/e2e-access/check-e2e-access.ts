// 開発用の環境で主な流れを確かめるジョブ（.github/workflows/deploy.yml）のための口を開くか。
// 開いてはいけない環境（本番）で開くと誰でも入れてしまうので、次のすべてが揃ったときだけ allowed にする。
// 1. 環境の名前（SENTRY_ENVIRONMENT）が development。許可する名前を挙げ、本番や綴りの違う名前は閉じる
// 2. 秘密の値（E2E_SIGN_IN_SECRET）が置かれていて、推測されにくい長さがある。本番には置かない
// 3. 要求が同じ秘密の値を送っている
// 1 か 2 が欠けたら closed（口が無い）、3 が欠けたら unauthorized
export const checkE2eAccess = async (
  env: Pick<Env, "SENTRY_ENVIRONMENT" | "E2E_SIGN_IN_SECRET">,
  sentSecret: string | undefined,
): Promise<"allowed" | "closed" | "unauthorized"> => {
  const minimumSecretLength = 32;
  const secret = env.E2E_SIGN_IN_SECRET;
  if (
    env.SENTRY_ENVIRONMENT !== "development" ||
    secret === undefined ||
    secret.length < minimumSecretLength
  ) {
    return "closed";
  }
  return (await isSameSecret(secret, sentSecret ?? "")) ? "allowed" : "unauthorized";
};

// 長さを漏らさず、一致までの時間が内容によらないよう、ハッシュにしてから比べる
const isSameSecret = async (expected: string, sent: string): Promise<boolean> => {
  const [expectedDigest, sentDigest] = await Promise.all([sha256(expected), sha256(sent)]);
  return crypto.subtle.timingSafeEqual(expectedDigest, sentDigest);
};

const sha256 = (value: string): Promise<ArrayBuffer> =>
  crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
