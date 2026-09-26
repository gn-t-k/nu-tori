import { env } from "cloudflare:workers";
import { decodeProtectedHeader, exportJWK, importJWK, importPKCS8, jwtVerify } from "jose";
import { beforeEach, describe, expect, test } from "vitest";
import { z } from "zod";
import { mockAppleTokenEndpointError, mockAppleTokenEndpointOk } from "../testing";
import { exchangeAppleAuthorizationCode } from "./index";

describe("Apple の認可コードの交換", () => {
  describe("Apple が交換したとき", () => {
    let authorizationCode: string;
    let fetchSpy: ReturnType<typeof mockAppleTokenEndpointOk>;
    beforeEach(() => {
      authorizationCode = "authorization-code";
      fetchSpy = mockAppleTokenEndpointOk({ refresh_token: "apple-refresh-token" });
    });

    test("refresh token を返すこと", async () => {
      await expect(exchangeAppleAuthorizationCode(env, authorizationCode)).resolves.toEqual({
        kind: "exchanged",
        refreshToken: "apple-refresh-token",
      });
    });

    test("認可コードと、Sign in with Apple の鍵で署名した client secret を送ること", async () => {
      await exchangeAppleAuthorizationCode(env, authorizationCode);
      const body = await new Response(fetchSpy.mock.calls[0]?.[1]?.body).formData();
      const clientSecret = z.string().parse(body.get("client_secret"));
      const { payload } = await jwtVerify(clientSecret, await importApplePublicKey(), {
        issuer: env.APPLE_TEAM_ID,
        subject: env.APPLE_BUNDLE_ID,
        audience: "https://appleid.apple.com",
      });
      expect({
        code: body.get("code"),
        clientId: body.get("client_id"),
        keyId: decodeProtectedHeader(clientSecret).kid,
        expiresIn: (payload.exp ?? 0) - (payload.iat ?? 0),
      }).toEqual({
        code: authorizationCode,
        clientId: env.APPLE_BUNDLE_ID,
        keyId: env.APPLE_KEY_ID,
        expiresIn: 300,
      });
    });
  });

  describe("Apple が認可コードを受け付けなかったとき", () => {
    let authorizationCode: string;
    beforeEach(() => {
      authorizationCode = "authorization-code";
      mockAppleTokenEndpointError("invalid_grant");
    });

    test("受け付けなかったことを返すこと", async () => {
      await expect(exchangeAppleAuthorizationCode(env, authorizationCode)).resolves.toEqual({
        kind: "rejected",
      });
    });
  });

  describe("Apple が client secret を受け付けなかったとき", () => {
    let authorizationCode: string;
    beforeEach(() => {
      authorizationCode = "authorization-code";
      mockAppleTokenEndpointError("invalid_client");
    });

    test("失敗を投げること", async () => {
      await expect(exchangeAppleAuthorizationCode(env, authorizationCode)).rejects.toThrow(
        "Apple の認可コードの交換に失敗した: 400",
      );
    });
  });
});

const importApplePublicKey = async () => {
  const privateKey = await importPKCS8(env.APPLE_PRIVATE_KEY, "ES256", { extractable: true });
  const { d: _, ...publicJwk } = await exportJWK(privateKey);
  return importJWK(publicJwk, "ES256");
};
