import { exportJWK, generateKeyPair } from "jose";

// テストのあいだ同じ鍵を使う。Apple の公開鍵を覚える jose の JWKS がモジュールごとに1つなので
export const appleSigningKey = generateKeyPair("RS256", { extractable: true }).then(
  async ({ privateKey, publicKey }) => ({
    privateKey,
    publicJwk: { ...(await exportJWK(publicKey)), kid: "test-apple-key", alg: "RS256", use: "sig" },
  }),
);
